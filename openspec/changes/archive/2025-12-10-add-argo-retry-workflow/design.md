## Context

The GAPIT3 GWAS pipeline runs 186 traits in parallel via Argo Workflows. When the workflow completes, some traits may have failed due to:

1. **OOM (exit code 137)**: MLM model memory usage exceeded limits during model fitting
2. **Timeout**: Workflow `activeDeadlineSeconds` reached before trait completed (slow MLM convergence)
3. **Transient failures**: Node issues, mount problems (handled by built-in 5x retry)

Current state from `gapit3-gwas-parallel-8nj24`:
- 181 traits succeeded
- 1 trait (5) failed with OOMKilled during MLM (BLINK/FarmCPU completed)
- 4 traits (28, 29, 30, 31) timed out during MLM (no output)

### Existing Infrastructure

**RunAI scripts** (not applicable for Argo):
- `scripts/bulk-resubmit-traits.sh` - Uses `runai workspace` commands
- `scripts/retry-failed-traits.sh` - Detects mount failures via RunAI logs

**Argo built-in retry** (already in use):
```yaml
retryStrategy:
  limit: 5
  retryPolicy: "OnFailure"
  backoff:
    duration: "2m"
    factor: 2
    maxDuration: "30m"
```
This handles transient failures but doesn't help with OOM or timeout (same failure repeats).

**Aggregation** (existing):
- `scripts/aggregate-runai-results.sh` - Works with `--force` flag for Argo outputs
- `scripts/collect_results.R` - Core aggregation logic

## Goals / Non-Goals

**Goals:**
- Simple CLI to retry failed traits from an Argo workflow
- Support memory override for OOM failures
- Auto-detect failed traits from workflow status
- Generate a new workflow YAML or submit directly
- Integrate with existing aggregation pipeline
- Consistent UX with existing `bulk-resubmit-traits.sh`

**Non-Goals:**
- Dynamic resource allocation via podSpecPatch (complex, deferred)
- Automatic OOM detection and memory scaling (requires parsing exit codes)
- Resume from checkpoint within a trait (GAPIT doesn't support this)
- Multi-workflow batch retry (one workflow at a time)

## Decisions

### Decision 1: Shell Script + Generated YAML Approach

**Choice**: Create a shell script that generates and optionally submits a retry workflow YAML

**Alternatives considered**:
1. **Pure YAML template with parameters** - Can't easily pass array of failed traits
2. **Argo CLI retry command** - Only retries with same config, can't change memory
3. **Python script** - Overkill for this use case, adds dependency

**Rationale**:
- Shell script matches existing `bulk-resubmit-traits.sh` pattern
- Users can inspect generated YAML before submission
- No new dependencies required
- Can leverage `argo` CLI for submission

### Decision 2: Memory Override via New WorkflowTemplate

**Choice**: Create a higher-memory WorkflowTemplate variant for retries

**Alternatives considered**:
1. **podSpecPatch in workflow** - Complex, not all Argo versions support well
2. **Edit existing template** - Would affect all new runs, not just retries
3. **Inline container spec** - Duplicates template, hard to maintain

**Rationale**:
- WorkflowTemplates are the established pattern
- Can have `gapit3-gwas-single-trait-highmem` template (96Gi)
- Clean separation between normal and retry workflows
- Easy to revert by switching template reference

### Decision 3: Trait Detection - Output Directory Inspection

**Choice**: Inspect output directories to find incomplete traits, using workflow's model list

**Rationale**:
- Argo task "Failed" doesn't mean trait fully failed (partial completion possible)
- A trait may have BLINK/FarmCPU outputs but failed during MLM
- Built-in retries mean a task could fail 5 times but final retry succeeded
- Output directory is the source of truth for actual completion
- Models should come from original workflow parameters, not hardcoded

**Implementation**:
```bash
# 1. Get models from original workflow
MODELS=$(argo get $WORKFLOW -n $NAMESPACE -o json | \
    jq -r '.spec.arguments.parameters[] | select(.name == "models") | .value')
# e.g., "BLINK,FarmCPU,MLM"

# 2. Parse into array
IFS=',' read -ra MODEL_ARRAY <<< "$MODELS"

# 3. For each expected trait, check if all requested models have outputs
for trait in $(seq $START_TRAIT $END_TRAIT); do
    TRAIT_DIR=$(ls -d $OUTPUT_DIR/trait_$(printf "%03d" $trait)_* 2>/dev/null | head -1)
    if [[ -z "$TRAIT_DIR" ]]; then
        MISSING_TRAITS+=($trait)  # No output directory at all
    else
        for model in "${MODEL_ARRAY[@]}"; do
            if ! ls "$TRAIT_DIR"/GAPIT.Association.GWAS_Results.${model}.* &>/dev/null; then
                INCOMPLETE_TRAITS+=("$trait:$model")  # Missing specific model
                break
            fi
        done
    fi
done
```

**Output**: Script reports missing traits (no output) and incomplete traits (missing models)

### Decision 4: Workflow Naming Convention

**Choice**: `gapit3-gwas-retry-<original-workflow-suffix>`

**Example**: Original `gapit3-gwas-parallel-8nj24` → Retry `gapit3-gwas-retry-8nj24`

**Rationale**:
- Clear lineage to original workflow
- Avoids name collisions
- Easy to filter in `argo list`

## Architecture

### Script Flow

```
retry-argo-traits.sh
       │
       ├─ Parse args (workflow name, traits, memory, namespace)
       │
       ├─ If no traits specified:
       │     └─ Query argo get --json → extract failed trait indices
       │
       ├─ Generate retry workflow YAML
       │     ├─ Set generateName: gapit3-gwas-retry-
       │     ├─ Reference appropriate template (normal or highmem)
       │     ├─ Include only specified traits
       │     └─ Copy volume config from original
       │
       ├─ If --dry-run:
       │     └─ Print YAML and exit
       │
       ├─ Submit workflow: argo submit <yaml>
       │
       └─ If --aggregate:
             └─ Wait for completion, run aggregate-runai-results.sh --force
```

### Generated Workflow Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: gapit3-gwas-retry-
  namespace: runai-talmo-lab
spec:
  entrypoint: retry-traits
  activeDeadlineSeconds: 604800  # 7 days

  volumes:
  - name: nfs-data
    hostPath:
      path: "{{workflow.parameters.data-hostpath}}"
  - name: nfs-outputs
    hostPath:
      path: "{{workflow.parameters.output-hostpath}}"

  arguments:
    parameters:
    - name: image
      value: "ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-834d729-test"
    - name: data-hostpath
      value: "/hpi/hpi_dev/users/eberrigan/..."
    - name: output-hostpath
      value: "/hpi/hpi_dev/users/eberrigan/..."
    - name: models
      value: "BLINK,FarmCPU,MLM"

  templates:
  - name: retry-traits
    dag:
      tasks:
      - name: retry-trait-5
        templateRef:
          name: gapit3-gwas-single-trait-highmem  # or normal
          template: run-gwas
        arguments:
          parameters:
          - name: trait-index
            value: "5"
          - name: trait-name
            value: "retry-trait-5"
          - name: image
            value: "{{workflow.parameters.image}}"
          - name: models
            value: "{{workflow.parameters.models}}"
      # ... more traits
```

### High-Memory Template

New `gapit3-single-trait-template-highmem.yaml`:
- Memory request: 96Gi (vs 64Gi normal)
- Memory limit: 104Gi (vs 72Gi normal)
- CPU request: 16 cores (vs 12 normal)
- CPU limit: 20 cores (vs 16 normal)
- OPENBLAS_NUM_THREADS: 16 (vs 12 normal)
- OMP_NUM_THREADS: 16 (vs 12 normal)
- All other config identical

**Rationale for CPU increase:**
- MLM benefits from more threads for REML iteration and matrix operations
- Retry workflows have few traits (typically <10), so cluster impact is minimal
- More threads can help slow-converging traits finish faster
- Thread env vars must match CPU allocation for optimal BLAS performance

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| High-memory template wastes resources for non-OOM retries | Default to normal template, require explicit `--highmem` flag |
| Generated YAML could have errors | Always generate to file first, require explicit `--submit` |
| Trait outputs overwrite successful previous runs | Traits that completed (e.g., BLINK for trait 5) already have outputs |
| Aggregation runs before all retries complete | `--aggregate` flag waits for workflow completion |
| Memory increase still not enough | Document that 96Gi is max, some traits may need investigation |

## Migration Plan

1. Create `gapit3-single-trait-template-highmem.yaml`
2. Apply to cluster: `kubectl apply -f ... -n runai-talmo-lab`
3. Create `scripts/retry-argo-traits.sh`
4. Test with dry-run: `./scripts/retry-argo-traits.sh --workflow gapit3-gwas-parallel-8nj24 --dry-run`
5. Submit retry: `./scripts/retry-argo-traits.sh --workflow gapit3-gwas-parallel-8nj24 --highmem --submit`
6. Monitor: `argo watch gapit3-gwas-retry-... -n runai-talmo-lab`
7. Aggregate: `./scripts/aggregate-runai-results.sh --force --output-dir ...`

**Rollback**: Delete retry workflow, no changes to original outputs

## Open Questions

1. Should trait 5 (which completed BLINK/FarmCPU) retry all models or just MLM?
   - **Proposed answer**: Retry all models for simplicity. GAPIT will regenerate but outputs are small.

2. Should we auto-detect OOM vs timeout and apply different memory?
   - **Proposed answer**: No, too complex. User specifies `--highmem` if needed.

3. Should retry workflow include validation/extract-traits steps?
   - **Proposed answer**: No, assume data already validated. Start directly with trait tasks.
