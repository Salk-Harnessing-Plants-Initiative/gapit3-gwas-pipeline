# GAPIT3 GWAS Pipeline - Argo Workflows Setup Guide

Complete guide for deploying and running the GAPIT3 GWAS pipeline on your cluster using Argo Workflows.

> **✅ IMPORTANT - Service Account Requirements (2025-11-18):**
>
> All workflows MUST use `serviceAccountName: default` for pod execution.
> The `argo-user` service account is for human CLI usage only and lacks required permissions.
>
> **See**: [Service Account Documentation](argo-service-accounts.md) for complete details on:
> - Distinction between `argo-user` (submission) and `default` (execution)
> - Why workflows need `default` SA for `workflowtaskresults` permission
> - Path mapping between network share and cluster mounts
> - Memory requirements and troubleshooting

> **⚠️ Historical Note:**
>
> Previous RBAC permission issues (documented in [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md))
> were caused by incorrect service account configuration and have been resolved.
> The `default` service account already has the required permissions.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [One-Time Setup](#one-time-setup)
3. [Workflow Validation Fix](#workflow-validation-fix)
4. [Running the Pipeline](#running-the-pipeline)
5. [Monitoring Workflows](#monitoring-workflows)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Usage](#advanced-usage)

---

## Prerequisites

### Required Software

- **Argo Workflows** installed on your Kubernetes cluster
- **kubectl** configured with cluster access
- **argo CLI** installed locally ([installation guide](https://github.com/argoproj/argo-workflows/releases))
- **Git** for cloning the repository

### Cluster Requirements

- **CPU**: 12-16 cores per job (recommended)
- **Memory**: 32GB per job (minimum)
- **Storage**: NFS or shared filesystem accessible from cluster nodes
- **Namespace**: Access to an Argo-enabled Kubernetes namespace

### Data Requirements

Your NFS/shared storage must contain:

```
<your-base-path>/
├── data/
│   ├── genotype/
│   │   └── acc_snps_filtered_maf_perl_edited_diploid.hmp.txt  (~2.3 GB)
│   ├── phenotype/
│   │   └── iron_traits_edited.txt
│   └── metadata/
│       └── ids_gwas.txt
└── outputs/  (will be created automatically)
```

---

## One-Time Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline.git
cd gapit3-gwas-pipeline
```

### Step 2: Update Configuration Paths

Edit the workflow YAML files to use your actual NFS paths:

```bash
# Update these files with your paths:
# - cluster/argo/workflow-templates/gapit3-single-trait-template.yaml
# - cluster/argo/workflows/gapit3-test-pipeline.yaml
# - cluster/argo/workflows/gapit3-parallel-pipeline.yaml

# Replace:
#   /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data
#   /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/outputs
# With your actual paths
```

**Quick find-and-replace:**

```bash
export MY_USERNAME="your_username_here"
export DATA_PATH="/hpi/hpi_dev/users/$MY_USERNAME/gapit3-gwas/data"
export OUTPUT_PATH="/hpi/hpi_dev/users/$MY_USERNAME/gapit3-gwas/outputs"

# Use sed to update all files (Linux/macOS)
find cluster/argo -type f -name "*.yaml" -exec sed -i \
  "s|/hpi/hpi_dev/users/YOUR_USERNAME|/hpi/hpi_dev/users/$MY_USERNAME|g" {} +

# Or manually edit each file
```

### Step 3: Update Namespace

If you're not using the `default` namespace, update it:

```bash
export ARGO_NAMESPACE="your-namespace"

find cluster/argo -type f -name "*.yaml" -exec sed -i \
  "s|namespace: default|namespace: $ARGO_NAMESPACE|g" {} +
```

### Step 4: Install WorkflowTemplates to Cluster

Install the reusable workflow templates (one-time operation):

```bash
cd cluster/argo

# Option A: Using the helper script
./scripts/submit_workflow.sh templates

# Option B: Manual installation
kubectl apply -f workflow-templates/gapit3-single-trait-template.yaml -n $ARGO_NAMESPACE
kubectl apply -f workflow-templates/trait-extractor-template.yaml -n $ARGO_NAMESPACE
kubectl apply -f workflow-templates/results-collector-template.yaml -n $ARGO_NAMESPACE

# Verify installation
kubectl get workflowtemplates -n $ARGO_NAMESPACE
```

Expected output:
```
NAME                          AGE
gapit3-gwas-single-trait      10s
gapit3-trait-extractor        10s
gapit3-results-collector      10s
```

### Step 5: Verify Container Image

Ensure the Docker image is built and pushed to GHCR:

```bash
# Check if image exists
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest

# Or trigger GitHub Actions build (if you pushed to main branch)
# The image should build automatically via .github/workflows/docker-build.yml
```

---

## Workflow Validation Fix

### Important: Volume Configuration Requirements

The workflow templates have been fixed to comply with Argo Workflows validation requirements. Previously, parameterized `hostPath` volumes in WorkflowTemplates caused validation errors because Argo validates template syntax **before** parameter substitution occurs.

**Key Changes Made:**
1. ✅ Volumes are now defined at the **workflow level** (in `workflows/*.yaml`), not in templates
2. ✅ Resources (CPU, memory) use **fixed values** in WorkflowTemplates
3. ✅ Templates reference volumes by name only

**Technical Details:**

The issue occurred because Argo validates WorkflowTemplate resources at submission time:

```yaml
# ❌ OLD (BROKEN) - In WorkflowTemplate
volumes:
- name: nfs-data
  hostPath:
    path: "{{inputs.parameters.data-hostpath}}"  # Validation fails BEFORE substitution
```

```yaml
# ✅ NEW (WORKING) - In Workflow
spec:
  volumes:
  - name: nfs-data
    hostPath:
      path: "{{workflow.parameters.data-hostpath}}"  # Substituted at submission
```

**Impact on Users:**
- No action required if using the provided workflows
- If creating custom workflows, always define `hostPath` volumes at the workflow level
- Resources (cpu, memory) in templates must be fixed values, not parameters

For complete technical documentation, see [openspec/changes/fix-argo-workflow-validation/](../openspec/changes/fix-argo-workflow-validation/).

---

## Running the Pipeline

### Test Run (3 Traits)

**Always start with a test run!** This validates your setup before running all 184 traits.

```bash
cd cluster/argo

# Using the submission script
./scripts/submit_workflow.sh test \
  --data-path /hpi/hpi_dev/users/$MY_USERNAME/gapit3-gwas/data \
  --output-path /hpi/hpi_dev/users/$MY_USERNAME/gapit3-gwas/outputs

# Or using argo CLI directly
argo submit workflows/gapit3-test-pipeline.yaml \
  --namespace $ARGO_NAMESPACE \
  --parameter data-hostpath=/path/to/your/data \
  --parameter output-hostpath=/path/to/your/outputs \
  --watch
```

The test workflow will:
1. ✅ Validate input files
2. ✅ Extract trait names
3. ✅ Run GWAS for traits 2, 3, and 4 in parallel
4. ✅ Display live progress

Expected duration: **~30-60 minutes** (depending on cluster speed)

### Full Production Run (184 Traits)

Once the test succeeds, run the full pipeline:

```bash
./scripts/submit_workflow.sh full \
  --data-path /hpi/hpi_dev/users/$MY_USERNAME/gapit3-gwas/data \
  --output-path /hpi/hpi_dev/users/$MY_USERNAME/gapit3-gwas/outputs \
  --max-parallel 50 \
  --cpu 12 \
  --memory 32
```

**Parameters explained:**
- `--max-parallel 50`: Limits concurrent jobs (adjust based on cluster capacity)
- `--cpu 12`: CPU cores per trait job
- `--memory 32`: Memory in GB per trait job

Expected duration: **~3-6 hours** (with 50 parallel jobs)

### Customizing Models

To run only BLINK (faster):

```bash
# Edit the workflow file
# workflows/gapit3-parallel-pipeline.yaml
# Change: models: value: "BLINK"

# Or create a custom submission
argo submit workflows/gapit3-parallel-pipeline.yaml \
  --namespace $ARGO_NAMESPACE \
  --parameter models="BLINK" \
  --parameter data-hostpath=/path/to/data \
  --parameter output-hostpath=/path/to/outputs
```

---

## Monitoring Workflows

### List Active Workflows

```bash
# Using helper script
./scripts/monitor_workflow.sh

# Or directly
argo list -n $ARGO_NAMESPACE
```

### Watch Specific Workflow

```bash
# Auto-refreshing monitor
./scripts/monitor_workflow.sh watch gapit3-gwas-parallel-abc123

# Show workflow tree
./scripts/monitor_workflow.sh tree gapit3-gwas-parallel-abc123

# Stream logs
./scripts/monitor_workflow.sh logs gapit3-gwas-parallel-abc123

# Or using argo CLI
argo watch gapit3-gwas-parallel-abc123 -n $ARGO_NAMESPACE
argo logs gapit3-gwas-parallel-abc123 -n $ARGO_NAMESPACE --follow
```

### Check Individual Trait Status

```bash
# Get detailed node status
argo get gapit3-gwas-parallel-abc123 -n $ARGO_NAMESPACE

# Filter specific trait
argo logs gapit3-gwas-parallel-abc123 -n $ARGO_NAMESPACE | grep "trait-50"
```

### Argo UI (if available)

Access the Argo UI in your browser:
```bash
# Port-forward Argo server (if not already exposed)
kubectl port-forward -n argo svc/argo-server 2746:2746

# Open browser
open https://localhost:2746
```

---

## Results

### Output Structure

```
outputs/
├── trait_002_20250222_143022/     # Individual trait results
│   ├── metadata.json               # Execution metadata
│   ├── GAPIT.Association.GWAS_Results.csv
│   ├── GAPIT.Manhattan.*.pdf
│   ├── GAPIT.QQ-Plot.*.pdf
│   └── ...
├── trait_003_20250222_143025/
├── ...
└── aggregated_results/             # Created by results collector
    ├── summary_table.csv           # All traits summary
    ├── significant_snps.csv        # All significant SNPs
    └── summary_stats.json          # Overall statistics
```

### Collect Results

After all traits complete:

```bash
# Results are automatically collected if using the parallel workflow
# Or manually trigger collection:

Rscript scripts/collect_results.R \
  --output-dir /path/to/outputs \
  --batch-id "my-batch-id"
```

### Download Results

```bash
# Copy from NFS to local machine
rsync -avz user@cluster:/path/to/outputs ./local_results/

# Or tar and download
ssh user@cluster "cd /path/to/outputs && tar czf results.tar.gz aggregated_results"
scp user@cluster:/path/to/outputs/results.tar.gz ./
```

---

## Troubleshooting

### Common Issues

#### 1. **WorkflowTemplate not found**

```
Error: workflowtemplate.argoproj.io "gapit3-gwas-single-trait" not found
```

**Solution:**
```bash
# Install templates
./scripts/submit_workflow.sh templates
```

#### 2. **Directory not found on host**

```
Error: hostPath type check failed: /hpi/.../data is not a directory
```

**Solution:**
- Ensure NFS paths exist on cluster nodes
- Verify paths are correct in YAML files
- Check NFS mount status

```bash
# SSH to a cluster node and verify
ssh node01
ls -la /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data
```

#### 3. **Pod crashes with OOMKilled**

```
Status: Failed (OOMKilled)
```

**Solution:**
- Increase memory allocation: `--memory 36` or `--memory 40`
- Reduce parallelism: `--max-parallel 20`
- Run traits sequentially (chunked approach)

#### 4. **Container image pull errors**

```
ErrImagePull or ImagePullBackOff
```

**Solution:**
```bash
# Ensure image is public or add imagePullSecrets
# Check GitHub Container Registry permissions
# Verify image exists:
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest
```

### Cancel Running Workflow

```bash
# Cancel specific workflow
argo terminate gapit3-gwas-parallel-abc123 -n $ARGO_NAMESPACE

# Delete workflow
argo delete gapit3-gwas-parallel-abc123 -n $ARGO_NAMESPACE
```

### Retry Failed Traits

```bash
# Argo can automatically retry failed nodes
argo retry gapit3-gwas-parallel-abc123 -n $ARGO_NAMESPACE

# Or resubmit with adjusted parameters
```

---

## Advanced Usage

### Running Specific Trait Range

Edit `workflows/gapit3-parallel-pipeline.yaml`:

```yaml
arguments:
  parameters:
  - name: start-trait-index
    value: "2"
  - name: end-trait-index
    value: "50"  # Run only traits 2-50
```

### Chunked Execution (for resource-limited clusters)

Instead of 184 parallel jobs, run in batches:

```bash
# Batch 1: Traits 2-50
argo submit workflows/gapit3-parallel-pipeline.yaml \
  --parameter start-trait-index=2 \
  --parameter end-trait-index=50 \
  --parameter max-parallelism=25

# Batch 2: Traits 51-100
argo submit workflows/gapit3-parallel-pipeline.yaml \
  --parameter start-trait-index=51 \
  --parameter end-trait-index=100 \
  --parameter max-parallelism=25

# And so on...
```

### Custom Resource Allocation per Trait

For memory-intensive traits, adjust resources:

```yaml
# In workflow YAML
parameters:
- name: cpu-cores
  value: "16"     # More CPUs
- name: memory-gb
  value: "48"     # More memory
```

### Using Run.AI Scheduler

If using Run.AI with Argo:

```yaml
# Add to pod metadata in workflow-templates
metadata:
  annotations:
    runai/preemptible: "true"
    runai/project: "your-project-name"
```

---

## Performance Optimization

### Reduce Run Time

1. **Use BLINK only** (FarmCPU is slower)
   ```yaml
   models: value: "BLINK"
   ```

2. **Increase parallelism** (if cluster allows)
   ```yaml
   max-parallelism: value: "100"
   ```

3. **Use faster BLAS library** (already configured in Dockerfile)

### Reduce Memory Usage

1. **LD pruning** (reduces SNP count)
2. **MAF filtering** (exclude rare variants)
3. **Run per-chromosome** (chunk by chromosome)

---

## Additional Resources

- **Current Workaround**: [Manual RunAI Execution Guide](MANUAL_RUNAI_EXECUTION.md)
- **RunAI Commands**: [RunAI Quick Reference](RUNAI_QUICK_REFERENCE.md)
- **RBAC Issue**: [RBAC Permissions Issue](RBAC_PERMISSIONS_ISSUE.md)
- **Argo Workflows Docs**: https://argo-workflows.readthedocs.io/
- **GAPIT3 Manual**: http://zzlab.net/GAPIT/
- **Pipeline GitHub**: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline
- **SLEAP-Roots Reference**: https://github.com/talmolab/sleap-roots-pipeline

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review Argo logs: `argo logs <workflow-name>`
3. Open a GitHub issue: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/issues

---

**Next Steps**: Proceed to [USAGE.md](USAGE.md) for detailed parameter descriptions and examples.
