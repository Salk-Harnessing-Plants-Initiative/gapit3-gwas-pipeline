## Context

The GAPIT3 GWAS pipeline uses Argo Workflows with a WorkflowTemplate pattern. Configuration flows through multiple layers:

1. **Workflow parameters** (`arguments.parameters`) - User-facing config at submission
2. **WorkflowTemplate parameters** - Passed via `templateRef.arguments`
3. **Environment variables** - Actual runtime config read by entrypoint
4. **CLI arguments** - Legacy pattern, ignored by entrypoint

### Current State (Problematic)

#### Unused Parameters in gapit3-parallel-pipeline.yaml
```yaml
arguments:
  parameters:
  - name: cpu-cores        # UNUSED - never referenced
    value: "12"
  - name: memory-gb        # UNUSED - never referenced
    value: "32"
  - name: max-parallelism  # UNUSED - spec.parallelism is used instead
    value: "50"
```

These appear in Argo UI logs but have no effect, causing confusion when operators change them expecting behavior changes.

#### Stale Defaults in WorkflowTemplate
```yaml
# WorkflowTemplate defaults (stale)
- name: models
  value: "BLINK,FarmCPU"  # Doesn't include MLM

# But workflows pass
- name: models
  value: "BLINK,FarmCPU,MLM"  # Includes MLM
```

#### Duplicate CLI Args (already in fix-duplicate-parameter-passing)
```yaml
args:
  - "run-single-trait"
  - "--trait-index"           # Duplicates TRAIT_INDEX env var
  - "{{inputs.parameters.trait-index}}"
  - "--models"                # Duplicates MODELS env var
  - "{{inputs.parameters.models}}"
```

#### Missing Env Vars in Test Pipeline
```yaml
# gapit3-test-pipeline.yaml validate template
# Missing GENOTYPE_FILE and PHENOTYPE_FILE env vars
# Works due to defaults, but inconsistent with parallel pipeline
```

#### Comment Inaccuracies
```yaml
# Says 184 traits but range 2-187 = 186 traits
# GAPIT3 GWAS - Full Parallel Pipeline (184 Traits)
```

## Goals / Non-Goals

**Goals:**
- Single source of truth for each configuration value
- Parameters that appear in UI should affect behavior
- Consistent patterns across all workflow files
- Accurate documentation/comments

**Non-Goals:**
- Adding dynamic resource configuration via podSpecPatch (too complex for now)
- Changing the env-var-based parameter passing pattern
- Supporting multiple dataset configurations in one template

## Decisions

### Decision 1: Remove Unused Parameters

**Choice**: Remove `cpu-cores`, `memory-gb`, `max-parallelism` from workflow parameters

**Rationale**:
1. They have no effect - resources are hardcoded in WorkflowTemplate
2. Displaying them misleads operators into thinking they work
3. If needed later, can use podSpecPatch pattern

**Migration**: Add comments explaining where actual values are set

### Decision 2: Update WorkflowTemplate Defaults

**Choice**: Update default `models` to `BLINK,FarmCPU,MLM` to match typical usage

**Rationale**:
1. Defaults should reflect common usage
2. Reduces surprise when running template standalone

### Decision 3: Remove CLI Args from WorkflowTemplate

**Choice**: Keep only command selector in args, remove parameter CLI args

**Rationale**:
1. Entrypoint ignores CLI args, reads env vars
2. Duplicate paths cause silent failures
3. Already addressed in `fix-duplicate-parameter-passing` change

### Decision 4: Standardize Env Vars Across Templates

**Choice**: All templates that call entrypoint should set the same env vars

**Rationale**:
1. Consistency aids debugging
2. Explicit is better than relying on defaults

## Parameter Flow After Changes

```
Workflow submission
       │
       ▼
┌─────────────────────────────────────────┐
│ Workflow Parameters (gapit3-parallel)   │
│  - image                    [USED]      │
│  - data-hostpath            [USED]      │
│  - output-hostpath          [USED]      │
│  - start-trait-index        [USED]      │
│  - end-trait-index          [USED]      │
│  - models                   [USED]      │
└─────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ WorkflowTemplate Parameters             │
│  - trait-index              [USED]      │
│  - trait-name               [USED]      │
│  - image                    [USED]      │
│  - models                   [USED]      │
└─────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ Container Environment Variables         │
│  - GENOTYPE_FILE            [USED]      │
│  - PHENOTYPE_FILE           [USED]      │
│  - ACCESSION_IDS_FILE       [USED]      │
│  - MODELS                   [USED]      │
│  - TRAIT_INDEX              [USED]      │
│  - OPENBLAS_NUM_THREADS     [USED]      │
│  - OMP_NUM_THREADS          [USED]      │
└─────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ entrypoint.sh reads env vars            │
│ (CLI args are IGNORED)                  │
└─────────────────────────────────────────┘
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Operators expect cpu/memory params | Add clear comments, update docs |
| Breaking change for scripts parsing params | Scripts use .env, not workflow params |
| Future need for dynamic resources | Can add podSpecPatch later |

## Migration Plan

1. Remove unused parameters from workflow files
2. Add comments explaining where resources are configured
3. Update WorkflowTemplate defaults
4. Remove CLI args from WorkflowTemplate (if not done in other change)
5. Add env vars to test pipeline validate template
6. Fix comment inaccuracies
7. Apply templates to cluster
8. Test with single trait before full pipeline

**Rollback**: Revert YAML changes, re-apply to cluster

## Open Questions

None - straightforward cleanup once design is agreed.
