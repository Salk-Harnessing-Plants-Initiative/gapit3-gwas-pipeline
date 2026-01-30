# Quick Demo Guide - RunAI Scripts & Argo Workflows

Quick reference for demonstrating the GAPIT3 GWAS pipeline functionality.

## Pre-Demo Setup

### 1. Configure for Test Run (3 traits only)

Update [.env](../.env):
```bash
# Use test data location
DATA_PATH_HOST=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data
OUTPUT_PATH_HOST=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs

# Test with 3 traits (2, 3, 4)
START_TRAIT=2
END_TRAIT=4
MAX_CONCURRENT=3

# Use proven image from successful run
IMAGE=ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-834d729-test
```

Argo workflow already configured: [gapit3-test-pipeline.yaml](../cluster/argo/workflows/gapit3-test-pipeline.yaml)

### 2. Verify Connectivity
```bash
# RunAI
runai workspace list

# Argo (if available)
argo list -n runai-talmo-lab
```

---

## Part 1: RunAI Bash Scripts (10-15 min)

### Show Configuration
```bash
# View configuration
cat .env

# Key settings for demo:
# - Test data paths
# - 3 traits only (2-4)
# - Proven Docker image
```

### Dry-Run Submission
```bash
cd scripts/
./submit-all-traits-runai.sh --dry-run
```

**Shows**:
- Configuration summary
- 3 jobs that would be submitted
- Resource requirements
- GAPIT parameters

### Actual Submission
```bash
./submit-all-traits-runai.sh
# Confirm when prompted
```

### Monitor Progress
```bash
./monitor-runai-jobs.sh --watch
```

**Shows**:
- Real-time job status
- Running/pending/succeeded counts
- Progress bar
- Output file statistics
- Auto-refreshes every 30 seconds

### Optional: Aggregation
```bash
./aggregate-runai-results.sh \
  --output-dir /mnt/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs \
  --batch-id demo-$(date +%Y%m%d)
```

---

## Part 2: Argo Workflows (10-15 min)

### Show Workflow Architecture

**WorkflowTemplate** - [gapit3-single-trait-template.yaml](../cluster/argo/workflow-templates/gapit3-single-trait-template.yaml):
- Resource requests/limits (64-72GB RAM, 12-16 CPU)
- Retry strategy (5 attempts with exponential backoff)
- Parameterized for reuse

**Test Workflow** - [gapit3-test-pipeline.yaml](../cluster/argo/workflows/gapit3-test-pipeline.yaml):
- DAG: validate → extract-traits → [3 parallel jobs]
- Uses same test data paths
- Uses same proven image

### Install Templates (one-time)
```bash
cd cluster/argo/scripts/
./submit_workflow.sh templates
```

### Submit Test Workflow
```bash
./submit_workflow.sh test
# Confirm when prompted
```

### Monitor Workflow
```bash
./monitor_workflow.sh watch <workflow-name>
```

**Shows**:
- Execution DAG progress
- Node status (validation → extraction → parallel runs)
- Live updates every 10 seconds

### View Logs
```bash
./monitor_workflow.sh logs <workflow-name> <node-name>
```

---

## Part 3: Key Differences

| Feature | RunAI Scripts | Argo Workflows |
|---------|---------------|----------------|
| **Orchestration** | Manual (bash) | Automatic (DAG) |
| **Dependencies** | None | Built-in |
| **Retries** | Manual | Auto (5x exponential backoff) |
| **Monitoring** | Custom script | Native + CLI |
| **Use Case** | Quick runs | Production pipelines |
| **RBAC** | Not required | Required (may be pending) |

**Both**:
- Use same CI-tested Docker images
- Use same `.env` configurations
- Produce identical outputs

---

## Scaling to Production

To run all 186 traits, update `.env`:
```bash
START_TRAIT=2
END_TRAIT=187
MAX_CONCURRENT=50  # Adjust based on cluster capacity
```

**RunAI**:
```bash
./submit-all-traits-runai.sh
```

**Argo**:
```bash
cd cluster/argo/scripts/
./submit_workflow.sh full
```

---

## Quick Reference

### RunAI Commands
```bash
# Dry-run
./submit-all-traits-runai.sh --dry-run

# Submit
./submit-all-traits-runai.sh

# Monitor
./monitor-runai-jobs.sh --watch

# Aggregate
./aggregate-runai-results.sh --output-dir <path>

# Cleanup
./cleanup-runai.sh --dry-run
```

### Argo Commands
```bash
# Install templates
./submit_workflow.sh templates

# Submit test (3 traits)
./submit_workflow.sh test

# Submit full (186 traits)
./submit_workflow.sh full

# Monitor
./monitor_workflow.sh watch <workflow-name>

# View logs
./monitor_workflow.sh logs <workflow-name> <node-name>
```

### Cluster Commands
```bash
# List RunAI jobs
runai workspace list

# Describe specific job
runai workspace describe <job-name>

# List Argo workflows
argo list -n runai-talmo-lab

# Get workflow details
argo get <workflow-name> -n runai-talmo-lab
```

---

## Troubleshooting

**RunAI Jobs Pending**: Check cluster resources
```bash
runai workspace describe <job-name>
```

**Argo RBAC Errors**: Currently waiting on cluster admin approval
- Workaround: Use RunAI scripts

**OOM Failures (Exit 137)**: Use high-memory template
```bash
./retry-argo-traits.sh --workflow <name> --highmem --submit
```

---

## Demo Flow Summary

1. **Show Config** → `.env` file (3 traits, test data, proven image)
2. **RunAI Dry-Run** → Validate without submitting
3. **RunAI Submit** → Run 3 test traits
4. **Monitor** → Real-time progress tracking
5. **Argo Architecture** → Show templates and DAG
6. **Argo Submit** → Submit test workflow (if RBAC available)
7. **Compare** → RunAI vs Argo benefits
8. **Scale** → Mention production settings (186 traits)

**Total Time**: 20-30 minutes
