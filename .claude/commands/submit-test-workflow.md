# Submit Argo Test Workflow

Submit a test workflow to Argo for validating the pipeline with 3 traits.

## Command

```bash
cd cluster/argo

# Submit test workflow (3 traits)
argo submit workflows/gapit3-test-pipeline.yaml \
  --parameter data-path="/hpi/hpi_dev/users/$USER/gapit3-gwas/data" \
  --parameter output-path="/hpi/hpi_dev/users/$USER/gapit3-gwas/outputs" \
  --watch
```

## Using Helper Script

```bash
cd cluster/argo
./scripts/submit_workflow.sh test \
  --data-path /hpi/hpi_dev/users/$USER/gapit3-gwas/data \
  --output-path /hpi/hpi_dev/users/$USER/gapit3-gwas/outputs
```

## Description

This command submits a test workflow that:
1. Validates input files
2. Extracts trait names from phenotype file
3. Runs GWAS on **3 traits** (indices 2, 3, 4) in parallel
4. Collects and aggregates results

**Runtime**: ~45 minutes total (15 min per trait in parallel)

## Prerequisites

1. **Install workflow templates** (one-time setup):
```bash
cd cluster/argo
./scripts/submit_workflow.sh templates
```

2. **Verify data files exist** on cluster:
```bash
ls /hpi/hpi_dev/users/$USER/gapit3-gwas/data/genotype/
ls /hpi/hpi_dev/users/$USER/gapit3-gwas/data/phenotype/
```

3. **Ensure kubectl/argo CLI configured**:
```bash
kubectl config current-context
argo list
```

## Parameters

Customize the submission:

```bash
argo submit workflows/gapit3-test-pipeline.yaml \
  --parameter data-path="/your/custom/path/data" \
  --parameter output-path="/your/custom/path/outputs" \
  --parameter max-parallelism="3" \
  --parameter cpu="12" \
  --parameter memory="32" \
  --watch
```

## Monitor Progress

```bash
# Watch workflow in real-time
argo watch <workflow-name>

# Get workflow status
argo get <workflow-name>

# View logs for specific step
argo logs <workflow-name> -c main
```

## Expected Output

```
Name:                gapit3-test-abc123
Namespace:           default
Status:              Running
Created:             Mon Jan 15 10:30:00 -0800 (3 minutes ago)

STEP                          TEMPLATE                    PODNAME                       DURATION  MESSAGE
 ● gapit3-test-abc123         gapit3-test-pipeline
 ├───✔ validate               validate-inputs             gapit3-test-abc123-validate   1m
 ├───✔ extract-traits         extract-traits              gapit3-test-abc123-extract    30s
 ├───◷ run-trait-2            single-trait-gwas           gapit3-test-abc123-trait-2    10m
 ├───◷ run-trait-3            single-trait-gwas           gapit3-test-abc123-trait-3    10m
 └───◷ run-trait-4            single-trait-gwas           gapit3-test-abc123-trait-4    10m
```

## Verify Results

After completion:

```bash
# Check output directory
ls /hpi/hpi_dev/users/$USER/gapit3-gwas/outputs/

# Expected structure:
# outputs/
# ├── trait_002_<name>/
# │   ├── GAPIT.<name>.Manhattan.Plot.png
# │   ├── GAPIT.<name>.QQ-Plot.png
# │   └── GAPIT.<name>.GWAS.Results.csv
# ├── trait_003_<name>/
# ├── trait_004_<name>/
# └── aggregated_results/
#     └── summary_table.csv
```

## Troubleshooting

### Workflow fails immediately
```bash
# Check workflow events
argo get <workflow-name>

# Common issues:
# - WorkflowTemplate not found → Run: ./scripts/submit_workflow.sh templates
# - Image pull errors → Check GHCR permissions
# - Invalid paths → Verify data-path exists on cluster
```

### OOMKilled errors
Increase memory allocation:
```bash
--parameter memory="48"
```

### Permission denied
Check namespace RBAC:
```bash
kubectl auth can-i create workflows
./scripts/check-argo-permissions.sh
```

## RunAI Alternative (Current Workaround)

If Argo permissions pending, use RunAI:
```bash
./scripts/submit-all-traits-runai.sh --traits "2 3 4" --data-path /your/path/data
```

See [docs/MANUAL_RUNAI_EXECUTION.md](../../docs/MANUAL_RUNAI_EXECUTION.md) for details.

## Related Commands

- `/monitor-jobs` - Monitor workflow progress
- `/validate-yaml` - Validate workflow before submission
- `/cleanup-jobs` - Clean up completed workflows