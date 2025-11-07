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
runai submit gapit3-validate \
  --project runai-talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu 1 \
  --memory 2G \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data:/data:ro \
  --command -- /scripts/entrypoint.sh validate
```

**Monitor the job**:
```bash
runai describe job gapit3-validate -p runai-talmo-lab
runai logs gapit3-validate -p runai-talmo-lab
```

**Expected output**: Validation checks pass for genotype and phenotype files.

**Clean up**:
```bash
runai delete job gapit3-validate -p runai-talmo-lab
```

### Step 2: Run Single Trait (Test)

Test with one trait before running all traits:

```bash
runai submit gapit3-trait-2-test \
  --project runai-talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu 12 \
  --memory 32G \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data:/data:ro \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs:/outputs:rw \
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
runai describe job gapit3-trait-2-test -p runai-talmo-lab

# Follow logs in real-time
runai logs gapit3-trait-2-test -p runai-talmo-lab --follow

# Check if job completed
runai list jobs -p runai-talmo-lab | grep gapit3-trait-2-test
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
runai submit gapit3-trait-2 \
  --project runai-talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu 12 --memory 32G \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data:/data:ro \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs:/outputs:rw \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index 2 --config /config/config.yaml --output-dir /outputs \
    --models BLINK,FarmCPU --threads 12

# Trait 3
runai submit gapit3-trait-3 \
  --project runai-talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu 12 --memory 32G \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data:/data:ro \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs:/outputs:rw \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index 3 --config /config/config.yaml --output-dir /outputs \
    --models BLINK,FarmCPU --threads 12

# Trait 4
runai submit gapit3-trait-4 \
  --project runai-talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu 12 --memory 32G \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data:/data:ro \
  --host-path /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs:/outputs:rw \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index 4 --config /config/config.yaml --output-dir /outputs \
    --models BLINK,FarmCPU --threads 12
```

**Monitor all jobs**:
```bash
runai list jobs -p runai-talmo-lab | grep gapit3-trait
```

#### Option B: Use a Bash Script to Submit All Traits

Create a script to submit all 186 traits:

```bash
#!/bin/bash
# File: scripts/submit-all-traits.sh

PROJECT="runai-talmo-lab"
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
  RUNNING=$(runai list jobs -p $PROJECT | grep -c "Running")

  # Wait if at max concurrency
  while [ $RUNNING -ge $MAX_CONCURRENT ]; do
    echo "Waiting... ($RUNNING jobs running)"
    sleep 30
    RUNNING=$(runai list jobs -p $PROJECT | grep -c "Running")
  done

  # Submit job
  echo "Submitting trait $trait_idx..."
  runai submit gapit3-trait-$trait_idx \
    --project $PROJECT \
    --image $IMAGE \
    --cpu 12 \
    --memory 32G \
    --host-path $DATA_PATH:/data:ro \
    --host-path $OUTPUT_PATH:/outputs:rw \
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
runai list jobs -p runai-talmo-lab
```

### Check specific job status
```bash
runai describe job gapit3-trait-2 -p runai-talmo-lab
```

### View logs
```bash
# Real-time logs
runai logs gapit3-trait-2 -p runai-talmo-lab --follow

# Recent logs
runai logs gapit3-trait-2 -p runai-talmo-lab --tail 100
```

### Monitor resource usage
```bash
runai top job -p runai-talmo-lab
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

## Cleanup

### Delete specific job
```bash
runai delete job gapit3-trait-2 -p runai-talmo-lab
```

### Delete all GAPIT3 jobs
```bash
runai list jobs -p runai-talmo-lab | grep gapit3-trait | awk '{print $1}' | xargs -I {} runai delete job {} -p runai-talmo-lab
```

### Delete failed jobs only
```bash
runai list jobs -p runai-talmo-lab | grep "Failed" | grep gapit3 | awk '{print $1}' | xargs -I {} runai delete job {} -p runai-talmo-lab
```

## Troubleshooting

### Job fails immediately
Check logs for errors:
```bash
runai logs gapit3-trait-2 -p runai-talmo-lab
```

Common issues:
- **Image pull error**: Wrong image tag (use `sha-bc10fc8-test` not `latest`)
- **Path not found**: Check hostPath is correct
- **Permission denied**: Check file permissions on host paths

### Job stuck in "Pending"
Check cluster resources:
```bash
runai describe job gapit3-trait-2 -p runai-talmo-lab
```

Possible causes:
- Insufficient cluster resources (CPU/memory)
- Node affinity issues
- Too many concurrent jobs

### Out of memory errors
In logs: "Killed" or "OOM"

Solution: Increase memory request:
```bash
--memory 48G  # Instead of 32G
```

### Results missing
Check if job completed:
```bash
runai describe job gapit3-trait-2 -p runai-talmo-lab | grep Status
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
