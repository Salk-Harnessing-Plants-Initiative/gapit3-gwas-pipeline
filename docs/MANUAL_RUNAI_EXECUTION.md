# Manual GAPIT3 Execution Using RunAI

This guide shows how to run GAPIT3 GWAS analysis manually using RunAI commands, bypassing the Argo Workflows orchestration until RBAC permissions are resolved.

## Prerequisites

- RunAI CLI authenticated: `runai login`
- Access to `talmo-lab` project (Kubernetes namespace: `runai-talmo-lab`)
- Data files at: `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data`

## Quick Start - Single Trait Test

Run GWAS analysis on a single trait (trait index 2):

```bash
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
```

**Monitor the workspace**:
```bash
# Check status
runai workspace list | grep gapit3

# View detailed status
runai workspace describe gapit3-trait-2-test -p talmo-lab

# Follow logs (once running)
runai workload logs workspace gapit3-trait-2-test -p talmo-lab --follow
```

## Step-by-Step Execution

### Step 1: Validate Data Files

Before running GWAS, validate your data:

```bash
runai workspace submit gapit3-validate \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu-core-request 1 \
  --cpu-memory-request 2G \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
  --command -- /scripts/entrypoint.sh validate
```

**Monitor the workspace**:
```bash
runai workspace describe gapit3-validate -p talmo-lab
runai workload logs workspace gapit3-validate -p talmo-lab
```

**Expected output**: Validation checks pass for genotype and phenotype files.

**Clean up**:
```bash
runai workload delete workspace gapit3-validate -p talmo-lab
```

### Step 2: Run Single Trait (Test)

Test with one trait before running all traits:

```bash
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
```

**Monitor**:
```bash
# Watch job status
runai workspace describe gapit3-trait-2-test -p talmo-lab

# Follow logs in real-time
runai workspace logs gapit3-trait-2-test -p talmo-lab --follow

# Check if job completed
runai workspace list -p talmo-lab | grep gapit3-trait-2-test
```

**Check outputs** (after completion):
```bash
ls -lh /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/trait_2_*/
```

Expected files:
- `GAPIT.Association.GWAS_Results.csv` - Main GWAS results
- `GAPIT.Manhattan.Plot.pdf` - Manhattan plot
- `GAPIT.QQ.Plot.pdf` - Q-Q plot
- `metadata.json` - Run metadata

### Step 3: Run Multiple Traits

Once the single trait test succeeds, you can run multiple traits. You have two options:

#### Option A: Submit Multiple Jobs Manually

Run 3 test traits in parallel:

```bash
# Trait 2
runai workspace submit gapit3-trait-2 \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu-core-request 12 --cpu-memory-request 32G \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index 2 --config /config/config.yaml --output-dir /outputs \
    --models BLINK,FarmCPU --threads 12

# Trait 3
runai workspace submit gapit3-trait-3 \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu-core-request 12 --cpu-memory-request 32G \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index 3 --config /config/config.yaml --output-dir /outputs \
    --models BLINK,FarmCPU --threads 12

# Trait 4
runai workspace submit gapit3-trait-4 \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu-core-request 12 --cpu-memory-request 32G \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index 4 --config /config/config.yaml --output-dir /outputs \
    --models BLINK,FarmCPU --threads 12
```

**Monitor all jobs**:
```bash
runai workspace list -p talmo-lab | grep gapit3-trait
```

#### Option B: Use a Bash Script to Submit All Traits

Create a script to submit all 186 traits:

```bash
#!/bin/bash
# File: scripts/submit-all-traits.sh

PROJECT="talmo-lab"
IMAGE="ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test"
DATA_PATH="/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data"
OUTPUT_PATH="/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs"
START_TRAIT=2
END_TRAIT=187
MAX_CONCURRENT=50  # Limit to avoid overwhelming cluster

echo "Submitting GWAS jobs for traits $START_TRAIT to $END_TRAIT"
echo "Maximum concurrent jobs: $MAX_CONCURRENT"

for trait_idx in $(seq $START_TRAIT $END_TRAIT); do
  # Check number of running jobs
  RUNNING=$(runai workspace list -p $PROJECT | grep -c "Running")

  # Wait if at max concurrency
  while [ $RUNNING -ge $MAX_CONCURRENT ]; do
    echo "Waiting... ($RUNNING jobs running)"
    sleep 30
    RUNNING=$(runai workspace list -p $PROJECT | grep -c "Running")
  done

  # Submit job
  echo "Submitting trait $trait_idx..."
  runai workspace submit gapit3-trait-$trait_idx \
    --project $PROJECT \
    --image $IMAGE \
    --cpu-core-request 12 \
    --cpu-memory-request 32G \
    --host-path path=$DATA_PATH,mount=/data,mount-propagation=HostToContainer \
    --host-path path=$OUTPUT_PATH,mount=/outputs,mount-propagation=HostToContainer,readwrite \
    --environment OPENBLAS_NUM_THREADS=12 \
    --environment OMP_NUM_THREADS=12 \
    --command -- /scripts/entrypoint.sh run-single-trait \
      --trait-index $trait_idx \
      --config /config/config.yaml \
      --output-dir /outputs \
      --models BLINK,FarmCPU \
      --threads 12

  # Small delay to avoid API rate limits
  sleep 2
done

echo "All jobs submitted!"
```

Make it executable and run:
```bash
chmod +x scripts/submit-all-traits.sh
./scripts/submit-all-traits.sh
```

## Monitoring Jobs

### List all jobs
```bash
runai workspace list -p talmo-lab
```

### Check specific job status
```bash
runai workspace describe gapit3-trait-2 -p talmo-lab
```

### View logs
```bash
# Real-time logs
runai workspace logs gapit3-trait-2 -p talmo-lab --follow

# Recent logs
runai workspace logs gapit3-trait-2 -p talmo-lab --tail 100
```

### Monitor resource usage
```bash
runai top job -p talmo-lab
```

## Aggregating Results

After all traits complete, aggregate results into summary reports.

### Automatic Aggregation (Recommended)

Wait for all jobs to complete and automatically aggregate:

```bash
./scripts/aggregate-runai-results.sh
```

**What this does**:
1. Monitors all `gapit3-trait-*` jobs in RunAI
2. Shows progress: "120/186 complete (65%)"
3. Waits until all jobs finish
4. Automatically runs `collect_results.R`
5. Creates aggregated results

**Output files created**:
- `aggregated_results/summary_table.csv` - Summary of all traits with metadata
- `aggregated_results/significant_snps.csv` - All SNPs with p < 5e-8
- `aggregated_results/summary_stats.json` - Overall statistics

### Advanced Aggregation Options

**Custom output path and batch ID**:
```bash
./scripts/aggregate-runai-results.sh \
  --output-dir /custom/path/outputs \
  --batch-id "iron-traits-batch-2"
```

**Specific trait range** (if you only ran some traits):
```bash
./scripts/aggregate-runai-results.sh \
  --start-trait 2 \
  --end-trait 50
```

**Check status without waiting**:
```bash
./scripts/aggregate-runai-results.sh --check-only
```

**Force immediate aggregation** (if jobs already complete):
```bash
./scripts/aggregate-runai-results.sh --force
```

### Manual Aggregation

If you prefer to run aggregation manually:

```bash
Rscript scripts/collect_results.R \
  --output-dir /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs \
  --batch-id "manual-runai-$(date +%Y%m%d)" \
  --threshold 5e-8
```

## Cleaning Up Before New Runs

Before starting a fresh pipeline run or rerunning failed traits, clean up old resources using the cleanup helper script.

### Clean Everything (Fresh Start)

```bash
# Preview what will be deleted
./scripts/cleanup-runai.sh --all --dry-run

# Delete all RunAI workspaces and output files
./scripts/cleanup-runai.sh --all
```

This will:
- Delete all `gapit3-trait-*` workspaces in RunAI
- Delete all `trait_*/` directories in outputs
- Delete `aggregated_results/` directory
- Prompt for confirmation before deletion

### Clean Specific Traits

```bash
# Clean up test run (traits 2-4)
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4

# Clean up single failed trait
./scripts/cleanup-runai.sh --start-trait 42 --end-trait 42

# Clean specific range
./scripts/cleanup-runai.sh --start-trait 50 --end-trait 100
```

### Selective Cleanup

```bash
# Only delete RunAI workspaces (keep outputs for analysis)
./scripts/cleanup-runai.sh --all --workspaces-only

# Only delete output files (keep workspaces running)
./scripts/cleanup-runai.sh --all --outputs-only
```

### Automation-Friendly

```bash
# Skip confirmation prompts (for scripts)
./scripts/cleanup-runai.sh --all --force
```

**Common cleanup workflows:**

1. **Before production run after testing:**
   ```bash
   # Clean test run
   ./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4

   # Submit full run
   ./scripts/submit-all-traits-runai.sh
   ```

2. **Rerun failed traits:**
   ```bash
   # Clean only the failed traits
   ./scripts/cleanup-runai.sh --start-trait 42 --end-trait 42
   ./scripts/cleanup-runai.sh --start-trait 137 --end-trait 137

   # Resubmit them
   START_TRAIT=42 END_TRAIT=42 ./scripts/submit-all-traits-runai.sh
   START_TRAIT=137 END_TRAIT=137 ./scripts/submit-all-traits-runai.sh
   ```

3. **Complete fresh start:**
   ```bash
   # Clean everything
   ./scripts/cleanup-runai.sh --all

   # Submit new run
   ./scripts/submit-all-traits-runai.sh
   ```

## Checking Results

### Check output directory
```bash
ls -lh /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/
```

Each trait will have a directory: `trait_<index>_<timestamp>/`

### Verify successful completion
```bash
# Count completed traits
ls -d /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/trait_*/ | wc -l

# Check for results files
find /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/ -name "GAPIT.Association.GWAS_Results.csv"
```

### View aggregated results
```bash
cd /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/aggregated_results/

# View summary table
head summary_table.csv

# View significant SNPs
head significant_snps.csv

# View overall statistics
cat summary_stats.json
```

### Understanding Aggregation Metrics

The aggregation output includes timing metrics that may need interpretation:

**Example output:**
```
================================================================================
AGGREGATION COMPLETE
================================================================================
Traits processed:      186
Successful traits:     186
Failed traits:         0
Total significant SNPs: 47
Average time/trait:    41.66 minutes
Total aggregated time: 129.15 hours
```

**How duration metrics are calculated:**

| Metric | Source | Calculation | Meaning |
|--------|--------|-------------|---------|
| **Duration per trait** | `metadata.json` | `execution.duration_minutes` | Time from trait analysis start to completion |
| **Average time/trait** | Summary table | `mean(all trait durations)` | Typical time for one trait to complete |
| **Total aggregated time** | Summary table | `sum(all trait durations) / 60` | Cumulative computational time across all traits |

**Important notes:**

1. **Total aggregated time is NOT wall-clock time** - Since traits run in parallel, the actual pipeline runtime is much shorter. For example:
   - 186 traits x 41.66 min/trait = 129.15 hours total compute
   - With 50 parallel jobs: ~4 hours wall-clock time

2. **Duration is recorded per trait** - Each trait's `metadata.json` contains:
   ```json
   {
     "execution": {
       "start_time": "2025-11-10T14:30:00Z",
       "end_time": "2025-11-10T15:12:00Z",
       "duration_minutes": 42.0
     }
   }
   ```

3. **Missing durations** - If a trait failed or `metadata.json` is missing, that trait's duration is excluded from averages (uses `na.rm = TRUE`).

## Cleanup

### Delete specific job
```bash
runai workspace delete gapit3-trait-2 -p talmo-lab
```

### Delete all GAPIT3 jobs
```bash
runai workspace list -p talmo-lab | grep gapit3-trait | awk '{print $1}' | xargs -I {} runai workspace delete {} -p talmo-lab
```

### Delete failed jobs only
```bash
runai workspace list -p talmo-lab | grep "Failed" | grep gapit3 | awk '{print $1}' | xargs -I {} runai workspace delete {} -p talmo-lab
```

## Troubleshooting

### Job fails immediately
Check logs for errors:
```bash
runai workspace logs gapit3-trait-2 -p talmo-lab
```

Common issues:
- **Image pull error**: Wrong image tag (use `sha-bc10fc8-test` not `latest`)
- **Path not found**: Check hostPath is correct
- **Permission denied**: Check file permissions on host paths

### Job stuck in "Pending"
Check cluster resources:
```bash
runai workspace describe gapit3-trait-2 -p talmo-lab
```

Possible causes:
- Insufficient cluster resources (CPU/memory)
- Node affinity issues
- Too many concurrent jobs

### Out of memory errors
In logs: "Killed" or "OOM"

Solution: Increase memory request:
```bash
--cpu-memory-request 48G  # Instead of 32G
```

### Results missing
Check if job completed:
```bash
runai workspace describe gapit3-trait-2 -p talmo-lab | grep Status
```

If completed but no results:
- Check output path permissions
- Check logs for R errors
- Verify input data is valid

## Comparison with Argo Workflows

| Feature | Argo Workflows (blocked) | RunAI Manual (working) |
|---------|-------------------------|------------------------|
| Orchestration | Automatic DAG | Manual job submission |
| Dependency management | Built-in | Manual coordination |
| Parallel execution | Configured (50 max) | Script-based throttling |
| Monitoring | Argo UI + kubectl | RunAI CLI + logs |
| Retry on failure | Automatic | Manual resubmission |
| Result collection | Automatic | Manual file checking |
| Ease of use | High (when working) | Medium (requires scripts) |

## Next Steps

Once RBAC permissions are granted:
1. Test Argo workflow with: `kubectl create -f cluster/argo/workflows/gapit3-test-pipeline.yaml -n runai-talmo-lab`
2. Verify end-to-end execution
3. Switch to full Argo orchestration for production runs

## Questions?

- RunAI documentation: `runai --help`
- Project issues: https://github.com/salk-harnessing-plants-initiative/gapit3-gwas-pipeline/issues
- Salk RunAI guide: https://researchit.salk.edu/runai/kubectl-and-argo-cli-usage/
