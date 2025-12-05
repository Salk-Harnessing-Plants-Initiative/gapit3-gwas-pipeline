# RunAI Quick Reference for GAPIT3

Quick command reference for running GAPIT3 GWAS analysis with RunAI CLI.

## Project Info

- **Project name**: `talmo-lab`
- **Kubernetes namespace**: `runai-talmo-lab`
- **Image**: `ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test`
- **Data path**: `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data`
- **Output path**: `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs`

## Quick Commands

### Submit Single Trait Job

```bash
runai workspace submit gapit3-trait-<INDEX> \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu-core-request 12 \
  --cpu-memory-request 32G \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index <INDEX> \
    --config /config/config.yaml \
    --output-dir /outputs \
    --models BLINK,FarmCPU \
    --threads 12
```

Replace `<INDEX>` with the trait column number (2-187).

### List All Workloads

```bash
runai workspace list
```

Filter to GAPIT3 jobs only:
```bash
runai workspace list | grep gapit3
```

### Check Specific Workspace

```bash
runai workspace describe <WORKSPACE_NAME> -p talmo-lab
```

Example:
```bash
runai workspace describe gapit3-trait-2 -p talmo-lab
```

### View Logs

```bash
runai workspace logs <WORKSPACE_NAME> -p talmo-lab --follow
```

Example:
```bash
runai workspace logs gapit3-trait-2 -p talmo-lab --follow
```

### Delete Workspace

```bash
runai workspace delete <WORKSPACE_NAME> -p talmo-lab
```

Example:
```bash
runai workspace delete gapit3-trait-2 -p talmo-lab
```

## Common Workflows

### Test Single Trait

```bash
# Submit test job
runai workspace submit gapit3-trait-2-test \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu-core-request 12 \
  --cpu-memory-request 32G \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index 2 \
    --config /config/config.yaml \
    --output-dir /outputs \
    --models BLINK,FarmCPU \
    --threads 12

# Monitor
runai workspace list | grep gapit3-trait-2-test

# View logs
runai workspace logs gapit3-trait-2-test -p talmo-lab --follow

# Check results
ls -lh /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/

# Clean up
runai workspace delete gapit3-trait-2-test -p talmo-lab
```

### Submit Multiple Traits

```bash
# Submit traits 2, 3, 4 for testing
for trait in 2 3 4; do
  runai workspace submit gapit3-trait-$trait \
    --project talmo-lab \
    --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
    --cpu-core-request 12 \
    --cpu-memory-request 32G \
    --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
    --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
    --environment OPENBLAS_NUM_THREADS=12 \
    --environment OMP_NUM_THREADS=12 \
    --command -- /scripts/entrypoint.sh run-single-trait \
      --trait-index $trait \
      --config /config/config.yaml \
      --output-dir /outputs \
      --models BLINK,FarmCPU \
      --threads 12
  sleep 2
done
```

### Monitor Progress

```bash
# Watch all GAPIT3 jobs
watch -n 10 'runai workspace list | grep gapit3'

# Count statuses
runai workspace list | grep gapit3 | awk '{print $4}' | sort | uniq -c
```

### Aggregate Results After Parallel Execution

#### Option 1: Automated Aggregation Script (Recommended for monitoring)

```bash
# Wait for all jobs to complete, then aggregate
./scripts/aggregate-runai-results.sh

# Custom output path and batch ID
./scripts/aggregate-runai-results.sh \
  --output-dir /custom/path \
  --batch-id "my-batch-id"

# Specific trait range
./scripts/aggregate-runai-results.sh --start-trait 2 --end-trait 50

# Check status only (no waiting)
./scripts/aggregate-runai-results.sh --check-only

# Force immediate aggregation (skip waiting)
./scripts/aggregate-runai-results.sh --force
```

**What it does**:
- Monitors `gapit3-trait-*` workspace completion
- Shows progress: "120/186 complete (65%)"
- Auto-runs `collect_results.R` when all jobs finish
- Creates `aggregated_results/` with summary files

#### Option 2: Interactive Aggregation Workspace (For manual aggregation or testing)

Use this when you want to run aggregation manually, test the updated script, or don't have persistent volumes.

```bash
# Submit workspace with mounted directories (runs sleep infinity to keep it alive)
runai workspace submit gapit3-aggregation \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:feat-add-ci-testing-workflows-test \
  --project talmo-lab \
  --cpu-core-request 4 \
  --cpu-memory-request 16G \
  --host-path path=/hpi/hpi_dev/users/eberrigan,mount=/workspace,mount-propagation=HostToContainer,readwrite \
  --command -- sleep infinity

# Wait for it to be running, then exec into the workspace
runai workspace list | grep gapit3-aggregation
runai exec gapit3-aggregation -it -- bash

# Inside the workspace, run aggregation with latest code from mounted repo
cd /workspace/gapit3-gwas-pipeline
Rscript scripts/collect_results.R \
  --output-dir /workspace/20251110_Elohim_Bello_iron_deficiency_GAPIT_GWAS/outputs \
  --batch-id iron_deficiency_20251110 \
  --threshold 5e-8

# When done, delete the workspace
runai workspace delete gapit3-aggregation -p talmo-lab
```

**Why use this approach:**
- No persistent volume claims needed (uses host-path mounts)
- Can test updated aggregation script from local repo
- Full control over when aggregation runs
- Useful for debugging or re-running with different parameters

**Output:**
- Creates `/workspace/<output-path>/aggregated_results/`
- Files: `all_traits_significant_snps.csv`, `summary_table.csv`, `summary_stats.json`
- New: `model` column tracks which GAPIT model found each SNP

### Cleanup Commands

```bash
# Clean all traits (with confirmation)
./scripts/cleanup-runai.sh --all

# Clean specific range
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 50

# Preview without deleting (dry-run)
./scripts/cleanup-runai.sh --all --dry-run

# Only delete workspaces (keep outputs)
./scripts/cleanup-runai.sh --all --workspaces-only

# Only delete outputs (keep workspaces)
./scripts/cleanup-runai.sh --all --outputs-only

# Force (no confirmation, for scripts)
./scripts/cleanup-runai.sh --all --force
```

#### Manual Cleanup (if needed)

```bash
# List failed workspaces
runai workspace list | grep gapit3 | grep -E "Failed|Error"

# Delete specific workspace
runai workspace delete gapit3-trait-42 -p talmo-lab
```

## Troubleshooting

### Job stuck in "Initializing"

```bash
# Get detailed status
runai workspace describe <WORKSPACE_NAME> -p talmo-lab

# Check pod events via kubectl
export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml
kubectl get pods -n runai-talmo-lab | grep <WORKSPACE_NAME>
kubectl describe pod <POD_NAME> -n runai-talmo-lab
```

### Can't see logs

```bash
# Check if pod is running
runai workspace describe <WORKSPACE_NAME> -p talmo-lab

# Alternative: Use kubectl
kubectl logs -n runai-talmo-lab <POD_NAME> --follow
```

### Image pull errors

Check image exists and is accessible:
```bash
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test
```

## Helper Scripts

For batch operations, use the helper scripts:

```bash
# Submit all 186 traits with concurrency control
./scripts/submit-all-traits-runai.sh

# Monitor progress with live dashboard
./scripts/monitor-runai-jobs.sh --watch
```

## Key Differences from Old RunAI CLI

| Old Command | New Command |
|-------------|-------------|
| `runai submit` | `runai workspace submit` |
| `runai list jobs` | `runai workspace list` |
| `runai describe job` | `runai workspace describe` |
| `runai logs` | `runai workspace logs` |
| `runai delete job` | `runai workspace delete` |
| `--cpu 12` | `--cpu-core-request 12` |
| `--memory 32G` | `--cpu-memory-request 32G` |
| `--host-path /path:/mount:ro` | `--host-path path=/path,mount=/mount,mount-propagation=HostToContainer` |
| `--project runai-talmo-lab` | `--project talmo-lab` |

## Additional Resources

- Full guide: [MANUAL_RUNAI_EXECUTION.md](MANUAL_RUNAI_EXECUTION.md)
- RBAC issue: [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md)
- RunAI docs: https://docs.run.ai/
