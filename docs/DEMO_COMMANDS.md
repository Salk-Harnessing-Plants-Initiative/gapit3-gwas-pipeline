# Demo Commands - Quick Reference

Copy-paste commands for live demo of RunAI scripts and Argo workflows.

---

## Pre-Demo Setup

### Terminal Setup
Open 2 WSL terminals:
- **Terminal 1**: RunAI scripts
- **Terminal 2**: Argo workflows (if available)

### Verify Cluster Connectivity
```bash
# Check RunAI
runai list jobs

# Check Argo (optional)
argo list -n runai-talmo-lab
```

---

## Part 1: RunAI Bash Scripts

### Navigate to Scripts
```bash
cd /mnt/c/repos/gapit3-gwas-pipeline/scripts
```

### Show Configuration
```bash
# View .env file
cat ../.env | grep -E "IMAGE=|DATA_PATH_HOST=|OUTPUT_PATH_HOST=|START_TRAIT=|END_TRAIT=|MAX_CONCURRENT=|MODELS=|PCA_COMPONENTS="
```

**Expected Output**:
```
IMAGE=ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-834d729-test
DATA_PATH_HOST=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data
OUTPUT_PATH_HOST=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs
START_TRAIT=2
END_TRAIT=4
MAX_CONCURRENT=3
MODELS=BLINK,FarmCPU
PCA_COMPONENTS=3
```

### Dry-Run Submission (validate on cluster - FUTURE)
```bash
./submit-all-traits-runai.sh --dry-run
```

**What it shows**:
- Configuration summary
- Validation (will submit validation job to cluster - to be implemented)
- Submission plan for 3 traits
- Resource requirements

### Actual Submission
```bash
./submit-all-traits-runai.sh
```

**Press Enter to confirm**

**Expected Output**:
```
✓ Submitted trait 2 (eberrigan-gapit-gwas-trait-002)
✓ Submitted trait 3 (eberrigan-gapit-gwas-trait-003)
✓ Submitted trait 4 (eberrigan-gapit-gwas-trait-004)

Batch Submission Complete
  Submitted: 3 jobs
  Skipped:   0 jobs
  Failed:    0 jobs
```

### Monitor Jobs (Real-time)
```bash
./monitor-runai-jobs.sh --watch
```

**Shows**:
- Live job status (Running/Pending/Succeeded/Failed)
- Progress bar (0/3 → 3/3)
- Output file counts
- Auto-refreshes every 30 seconds

**Press Ctrl+C to stop watching**

### Check Job Status (One-time)
```bash
./monitor-runai-jobs.sh
```

### List Jobs Directly
```bash
runai list jobs | grep eberrigan-gapit-gwas
```

### Check Output Files
```bash
ls -lh /z/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/
```

**Expected** (after jobs complete):
```
trait_002_20251125_XXXXXX/
trait_003_20251125_XXXXXX/
trait_004_20251125_XXXXXX/
```

### Aggregate Results (After Completion)
```bash
./aggregate-runai-results.sh \
  --output-dir /mnt/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs \
  --batch-id demo-$(date +%Y%m%d)
```

**Or use --check-only to see status without waiting**:
```bash
./aggregate-runai-results.sh \
  --output-dir /mnt/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs \
  --check-only
```

### Cleanup (After Demo)
```bash
# Dry-run first
./cleanup-runai.sh --dry-run

# Then actually cleanup
./cleanup-runai.sh --workspaces-only
```

---

## Part 2: Argo Workflows

### Navigate to Argo Scripts
```bash
cd /mnt/c/repos/gapit3-gwas-pipeline/cluster/argo/scripts
```

### Install Templates (One-time)
```bash
./submit_workflow.sh templates
```

**Expected**:
```
✓ argo CLI found
✓ kubectl configured
✓ Cluster reachable

Installing templates in namespace: runai-talmo-lab
✓ gapit3-gwas-single-trait
✓ gapit3-gwas-single-trait-highmem
✓ trait-extractor
✓ results-collector
```

**NOTE**: May fail if RBAC permissions not yet granted. If so, mention this is the workaround reason for using RunAI direct scripts.

### Submit Test Workflow
```bash
./submit_workflow.sh test
```

**Press 'y' to confirm**

**Expected**:
```
✓ Workflow submitted: gapit3-test-xj9k2

Monitor with:
  ./monitor_workflow.sh watch gapit3-test-xj9k2
```

### Monitor Workflow (Real-time)
```bash
# Replace <workflow-name> with actual name from submission
./monitor_workflow.sh watch gapit3-test-xj9k2
```

**Shows**:
- DAG execution progress
- Node status (validate-inputs → extract-traits → 3 parallel jobs)
- Live updates every 10 seconds

**Press Ctrl+C to stop watching**

### Check Workflow Status (One-time)
```bash
./monitor_workflow.sh status gapit3-test-xj9k2
```

### View Workflow Tree
```bash
./monitor_workflow.sh tree gapit3-test-xj9k2
```

### View Logs (Specific Node)
```bash
# Validation logs
./monitor_workflow.sh logs gapit3-test-xj9k2 validate-inputs

# Trait extraction logs
./monitor_workflow.sh logs gapit3-test-xj9k2 extract-traits

# Specific trait logs
./monitor_workflow.sh logs gapit3-test-xj9k2 run-trait-2
```

### List All Workflows
```bash
argo list -n runai-talmo-lab
```

### Delete Workflow (After Demo)
```bash
argo delete gapit3-test-xj9k2 -n runai-talmo-lab
```

---

## Part 3: Show Files in VSCode

### Open Key Files
```bash
code /mnt/c/repos/gapit3-gwas-pipeline/.env
code /mnt/c/repos/gapit3-gwas-pipeline/scripts/submit-all-traits-runai.sh
code /mnt/c/repos/gapit3-gwas-pipeline/cluster/argo/workflows/gapit3-test-pipeline.yaml
code /mnt/c/repos/gapit3-gwas-pipeline/cluster/argo/workflow-templates/gapit3-single-trait-template.yaml
```

Or use GUI to open:
- [.env](../.env)
- [submit-all-traits-runai.sh](../scripts/submit-all-traits-runai.sh)
- [gapit3-test-pipeline.yaml](../cluster/argo/workflows/gapit3-test-pipeline.yaml)
- [gapit3-single-trait-template.yaml](../cluster/argo/workflow-templates/gapit3-single-trait-template.yaml)

---

## Browser URLs

### GitHub Actions (CI/CD)
```
https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions
```

### Docker Images (Packages)
```
https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/pkgs/container/gapit3-gwas-pipeline
```

---

## Troubleshooting Commands

### Check RunAI Job Details
```bash
runai describe job eberrigan-gapit-gwas-trait-002
```

### Check RunAI Job Logs
```bash
runai logs eberrigan-gapit-gwas-trait-002
```

### Check Argo Workflow Details
```bash
argo get gapit3-test-xj9k2 -n runai-talmo-lab
```

### Check Kubernetes Pod Status
```bash
kubectl get pods -n runai-talmo-lab | grep gapit3-test
```

---

## Quick Demo Flow (20-30 min)

### 1. Show Config (2 min)
```bash
cd /mnt/c/repos/gapit3-gwas-pipeline/scripts
cat ../.env | grep -E "IMAGE=|DATA_PATH_HOST=|START_TRAIT=|END_TRAIT=|MODELS="
```

### 2. Submit RunAI Jobs (5 min)
```bash
./submit-all-traits-runai.sh          # Submit
./monitor-runai-jobs.sh --watch       # Monitor
```

### 3. Show Argo Architecture (5 min)
Open in VSCode:
- gapit3-test-pipeline.yaml (DAG structure)
- gapit3-single-trait-template.yaml (retry, resources)

### 4. Submit Argo Workflow (5 min)
```bash
cd ../cluster/argo/scripts
./submit_workflow.sh test             # Submit
./monitor_workflow.sh watch <name>    # Monitor
```

### 5. Compare Approaches (3 min)
Discuss:
- RunAI: Direct, simple, manual orchestration
- Argo: Automatic DAG, retries, dependencies
- Both use same Docker image, same configs

### 6. Show Results (5 min)
```bash
ls /z/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/
cat aggregated_results/summary_stats.json  # If aggregated
```

---

## Cleanup After Demo

```bash
# Clean RunAI jobs
cd /mnt/c/repos/gapit3-gwas-pipeline/scripts
./cleanup-runai.sh --workspaces-only

# Clean Argo workflows
cd ../cluster/argo/scripts
argo delete gapit3-test-xj9k2 -n runai-talmo-lab

# Optional: Clean output files
rm -rf /z/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/trait_*
```

---

## Notes

- **Image**: Using `sha-834d729-test` (proven from successful run)
- **Traits**: Testing with 3 traits (2, 3, 4) instead of full 186
- **Data**: Test dataset at `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/`
- **Duration**: Each trait takes ~15-20 minutes
- **RBAC**: Argo may fail if permissions not granted; RunAI scripts work as workaround
