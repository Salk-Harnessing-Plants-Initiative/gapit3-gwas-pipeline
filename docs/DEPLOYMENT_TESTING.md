# GAPIT3 Pipeline - Argo Workflows & RunAI Deployment Testing

This guide walks you through testing the GAPIT3 GWAS pipeline using Argo Workflows with RunAI integration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment-Specific Setup](#environment-specific-setup)
3. [Configuration](#configuration)
4. [Deploy Workflow Templates](#deploy-workflow-templates)
5. [Run Test Pipeline](#run-test-pipeline)
6. [Monitor Execution](#monitor-execution)
7. [Validate Results](#validate-results)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

> **Note for WSL Users**: If you're using Windows Subsystem for Linux, see the [Environment-Specific Setup](#environment-specific-setup) section below for important WSL-specific configuration before proceeding.

### Required Tools

```bash
# Verify Kubernetes access
kubectl cluster-info
kubectl get nodes

# Verify Argo Workflows CLI
argo version

# Verify RunAI CLI (if using)
runai version

# Verify Docker image is built and pushed
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest
```

### Cluster Setup

Ensure your Kubernetes cluster has:
- **Argo Workflows** installed and running
- **RunAI** installed (optional but recommended for resource scheduling)
- **Storage**: NFS or hostPath volumes configured
- **Resources**: Nodes with sufficient CPU (12+ cores) and RAM (32+ GB)

Check Argo Workflows:
```bash
kubectl get pods -n argo
kubectl get workflowtemplates -n default
```

---

## Environment-Specific Setup

### WSL (Windows Subsystem for Linux) Users

If you're running on WSL with Docker Desktop, you may encounter specific issues. Follow these steps before proceeding:

#### 1. Verify Your Environment

```bash
# Check if running in WSL
uname -a | grep -i microsoft
# Should show: Linux <hostname> ... Microsoft

# Check Docker Desktop integration
docker --version
```

#### 2. Fix kubectl Installation Issues

**Common Problem**: Docker Desktop creates symbolic links to kubectl that can break if Docker Desktop is not running or gets updated.

**Symptom**:
```bash
kubectl version
# Error: /usr/local/bin/kubectl: No such file or directory

# Or check for broken symlink:
ls -la /usr/local/bin/kubectl
# broken symbolic link to /mnt/wsl/docker-desktop/cli-tools/usr/local/bin/kubectl
```

**Solution - Option A: Use Docker Desktop's kubectl**

If you want to use Docker Desktop's bundled kubectl:

```bash
# Ensure Docker Desktop is running in Windows
docker ps  # Should work without errors

# If kubectl still doesn't work, restart Docker Desktop:
# 1. Open Docker Desktop in Windows
# 2. Right-click system tray icon → Quit Docker Desktop
# 3. Restart Docker Desktop
# 4. Wait for it to fully start (green status)
# 5. In WSL, verify: kubectl version --client
```

**Solution - Option B: Install standalone kubectl** (Recommended)

For a more reliable kubectl that works independently of Docker Desktop:

```bash
# Remove broken symlink
sudo rm -f /usr/local/bin/kubectl

# Download kubectl binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install it
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
file /usr/local/bin/kubectl  # Should show: "ELF 64-bit LSB executable"
```

#### 3. RunAI Authentication on WSL

**Problem**: RunAI's default login tries to open a browser, which doesn't work well in WSL (no GUI).

**Solution**: Use the remote-browser option:

```bash
# ❌ This won't work on WSL:
# runai login
# Error: failed to open browser: exec: "xdg-open,x-www-browser,www-browser": executable file not found

# ✅ Use this instead:
runai login remote-browser

# This will:
# 1. Display a URL in the terminal (e.g., https://app.run.ai/auth/...)
# 2. Copy the URL to your Windows browser
# 3. Complete authentication in the browser
# 4. Copy the code displayed in browser
# 5. Paste it back in the WSL terminal
# 6. Press Enter

# Example:
# Open the following URL in a browser and follow the instructions:
# https://app.run.ai/auth/realms/salkinstitute/protocol/openid-connect/auth?...
# Copy the code from the browser and paste it here: [paste code here]
# Authentication was successful
```

#### 4. File Path Considerations

WSL can access Windows files via `/mnt/c/`, but this can cause **severe performance issues** for large data files:

```bash
# ❌ SLOW: Using Windows filesystem paths
DATA_PATH="/mnt/c/Users/yourname/Documents/data"  # Very slow I/O

# ✅ FAST: Using WSL filesystem paths
DATA_PATH="/home/yourname/gapit3-gwas/data"  # Native Linux I/O
# or
DATA_PATH="~/gapit3-gwas/data"  # Also fast
```

**Best Practice**:
1. Store your GWAS data (genotype/phenotype files) in your WSL home directory
2. Only use `/mnt/c/` paths for small config files if needed

**Move data from Windows to WSL**:
```bash
# Copy data from Windows to WSL filesystem
mkdir -p ~/gapit3-gwas/data
cp -r /mnt/c/Users/yourname/Documents/gapit-data/* ~/gapit3-gwas/data/

# Verify
ls -lh ~/gapit3-gwas/data/genotype/
ls -lh ~/gapit3-gwas/data/phenotype/
```

#### 5. Docker Desktop Configuration

Ensure Docker Desktop settings are optimal for WSL:

1. **Open Docker Desktop** (in Windows)
2. Go to **Settings** → **Resources** → **WSL Integration**
3. **Enable integration** with your WSL distribution (e.g., Ubuntu)
4. **Allocate sufficient resources**:
   - **CPU**: 8+ cores (for local testing)
   - **Memory**: 16+ GB (minimum for GWAS analysis)
   - **Disk**: 50+ GB
5. **Apply & Restart** Docker Desktop

#### 6. Common WSL Issues & Quick Fixes

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Broken kubectl** | `kubectl: command not found` | Remove symlink, install standalone kubectl (see Option B above) |
| **RunAI login fails** | Browser doesn't open | Use `runai login remote-browser` |
| **Slow file I/O** | Data loading takes forever | Move data from `/mnt/c/` to `~/` (WSL filesystem) |
| **Docker errors** | Cannot connect to Docker daemon | Restart Docker Desktop in Windows |
| **Network issues** | Cannot pull images | Check Windows firewall, disable VPN temporarily |
| **Permission denied** | Cannot write to `/data` or `/outputs` | Check volume mount permissions in workflow YAML |

---

## Configuration

### 1. Update Data Paths

Edit the workflow files to match your cluster's storage paths:

**File: [cluster/argo/workflows/gapit3-test-pipeline.yaml](../cluster/argo/workflows/gapit3-test-pipeline.yaml)**

```yaml
# Line 26-28: Update these paths
- name: data-hostpath
  value: "/hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data"  # TODO: Update
- name: output-hostpath
  value: "/hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/outputs"  # TODO: Update
```

Replace `YOUR_USERNAME` with your actual path. Example:
```yaml
- name: data-hostpath
  value: "/hpi/hpi_dev/users/jsmith/gapit3-gwas/data"
- name: output-hostpath
  value: "/hpi/hpi_dev/users/jsmith/gapit3-gwas/outputs"
```

**Do the same for:**
- [cluster/argo/workflows/gapit3-parallel-pipeline.yaml](../cluster/argo/workflows/gapit3-parallel-pipeline.yaml) (lines 26-28)
- [cluster/argo/workflow-templates/gapit3-single-trait-template.yaml](../cluster/argo/workflow-templates/gapit3-single-trait-template.yaml) (lines 27-29)

### 2. Update Namespace

If not using `default` namespace:

```yaml
# Change in all workflow files (line 5)
metadata:
  namespace: your-namespace  # e.g., gapit3-prod
```

### 3. Prepare Data on Cluster

Ensure your data files exist on the cluster nodes:

```bash
# SSH to a cluster node or use kubectl exec
ls /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data/genotype/
ls /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data/phenotype/
ls /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data/metadata/
```

Expected structure:
```
data/
├── genotype/
│   └── acc_snps_filtered_maf_perl_edited_diploid.hmp.txt
├── phenotype/
│   └── iron_traits_edited.txt
└── metadata/
    └── ids_gwas.txt
```

Create output directory:
```bash
mkdir -p /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/outputs
```

---

## Deploy Workflow Templates

### 1. Apply Workflow Templates

Deploy the reusable templates first:

```bash
cd cluster/argo/workflow-templates

# Deploy single-trait template
kubectl apply -f gapit3-single-trait-template.yaml

# Deploy trait extractor template
kubectl apply -f trait-extractor-template.yaml

# Deploy results collector template
kubectl apply -f results-collector-template.yaml

# Verify templates are created
kubectl get workflowtemplates
```

Expected output:
```
NAME                          AGE
gapit3-gwas-single-trait      5s
gapit3-trait-extractor        5s
gapit3-results-collector      5s
```

### 2. Verify Templates

```bash
# View single-trait template details
argo template get gapit3-gwas-single-trait

# Check for errors
kubectl describe workflowtemplate gapit3-gwas-single-trait
```

---

## Run Test Pipeline

### Option 1: Using Argo CLI (Recommended)

Submit the test workflow (3 traits):

```bash
cd cluster/argo/workflows

# Submit test workflow
argo submit gapit3-test-pipeline.yaml --watch

# Or with custom parameters
argo submit gapit3-test-pipeline.yaml \
  --parameter image=ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:v1.0.0 \
  --parameter cpu-cores=16 \
  --parameter memory-gb=48 \
  --watch
```

### Option 2: Using kubectl

```bash
# Create workflow from template
kubectl create -f cluster/argo/workflows/gapit3-test-pipeline.yaml

# Get workflow name (starts with gapit3-test-)
kubectl get workflows

# Watch logs
argo logs <workflow-name> --follow
```

### Option 3: Using Argo UI

1. Open Argo UI: `kubectl port-forward -n argo svc/argo-server 2746:2746`
2. Navigate to: http://localhost:2746
3. Click **Submit New Workflow**
4. Upload `gapit3-test-pipeline.yaml`
5. Click **Submit**

---

## Monitor Execution

### Watch Workflow Progress

```bash
# List all workflows
argo list

# Get specific workflow status
argo get <workflow-name>

# Watch workflow logs in real-time
argo logs <workflow-name> --follow

# View logs for specific step
argo logs <workflow-name> validate-inputs
argo logs <workflow-name> run-trait-2
```

### Check Pod Status

```bash
# List all pods for the workflow
kubectl get pods -l pipeline=gapit3-gwas

# Describe a specific pod
kubectl describe pod <pod-name>

# View pod logs directly
kubectl logs <pod-name> --follow
```

### Monitor Resource Usage

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -l pipeline=gapit3-gwas

# RunAI dashboard (if using RunAI)
runai workspace list
runai workspace describe <job-name>
```

### View in Argo UI

```bash
# Port-forward to Argo UI
kubectl port-forward -n argo svc/argo-server 2746:2746
```

Navigate to http://localhost:2746 to see:
- DAG visualization
- Real-time logs
- Resource usage
- Task dependencies

---

## Validate Results

### 1. Check Workflow Completion

```bash
# Get workflow status
argo get <workflow-name>

# Should show: Status: Succeeded
```

### 2. Verify Output Files

```bash
# SSH to cluster or use kubectl exec to check outputs
ls -lh /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/outputs/

# Expected structure:
# outputs/
# ├── traits_manifest.yaml          # From extract-traits step
# ├── trait_2_<timestamp>/           # GWAS results for trait 2
# │   ├── GAPIT.*.csv                # GWAS output files
# │   ├── plots/                     # Manhattan plots, QQ plots
# │   └── metadata.json              # Execution metadata
# ├── trait_3_<timestamp>/           # GWAS results for trait 3
# └── trait_4_<timestamp>/           # GWAS results for trait 4
```

### 3. Check Result Quality

```bash
# Check if GAPIT generated results
find /path/to/outputs -name "GAPIT*.csv" -type f

# Check metadata
cat /path/to/outputs/trait_2_*/metadata.json | jq .

# Verify plots were generated
find /path/to/outputs -name "*.pdf" -o -name "*.png"
```

### 4. Review Logs

```bash
# Get final workflow status
argo get <workflow-name> -o yaml

# Check for errors in logs
argo logs <workflow-name> | grep -i error
argo logs <workflow-name> | grep -i warning
```

---

## Troubleshooting

### Common Issues

#### 1. **Workflow Stuck in Pending**

**Symptom**: Workflow shows `Pending` status indefinitely

**Diagnosis**:
```bash
# Check workflow events
kubectl describe workflow <workflow-name>

# Check pod status
kubectl get pods -l pipeline=gapit3-gwas
kubectl describe pod <pending-pod>
```

**Common causes**:
- Insufficient cluster resources (CPU/RAM)
- Storage path doesn't exist
- Image pull errors
- RunAI quota exceeded

**Fix**:
```bash
# Check node resources
kubectl top nodes

# Verify storage paths exist
# SSH to node and check:
ls /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data

# Check image availability
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest

# If using RunAI, check quota
runai list projects
```

#### 2. **Volume Mount Errors**

**Symptom**: Error like "path does not exist" or "failed to mount"

**Fix**:
```bash
# Create missing directories on cluster nodes
mkdir -p /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data
mkdir -p /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/outputs

# Verify permissions
chmod 755 /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data
chmod 777 /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/outputs
```

#### 3. **R Script Errors**

**Symptom**: Container exits with error code, R script failures in logs

**Diagnosis**:
```bash
# View detailed logs
argo logs <workflow-name> run-trait-2

# Check container logs
kubectl logs <pod-name>
```

**Common causes**:
- Missing input files
- Incorrect trait index (out of range)
- Memory issues (OOM killed)
- GAPIT package errors

**Fix**:
```bash
# Test manually with docker
docker run --rm \
  -v /path/to/data:/data:ro \
  -v /path/to/outputs:/outputs \
  ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest \
  /scripts/entrypoint.sh validate

# Check if trait index is valid
head -n 1 /path/to/data/phenotype/iron_traits_edited.txt
```

#### 4. **WorkflowTemplate Not Found**

**Symptom**: Error like "workflowtemplate.argoproj.io 'gapit3-gwas-single-trait' not found"

**Fix**:
```bash
# Ensure templates are deployed first
kubectl apply -f cluster/argo/workflow-templates/gapit3-single-trait-template.yaml

# Verify template exists
kubectl get workflowtemplates
```

#### 5. **Image Pull Errors**

**Symptom**: `ErrImagePull` or `ImagePullBackOff`

**Fix**:
```bash
# Verify image exists and is accessible
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest

# If private registry, create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PAT

# Add to workflow:
# spec:
#   imagePullSecrets:
#   - name: ghcr-secret
```

#### 6. **WSL-Specific Issues**

**Symptom**: kubectl commands fail with "command not found" or broken symlinks

**Diagnosis**:
```bash
# Check if you're in WSL
uname -a | grep -i Microsoft

# Check if kubectl is a broken symlink
ls -la /usr/local/bin/kubectl
# If it shows: "broken symbolic link to /mnt/wsl/docker-desktop/..."
```

**Fix**:
```bash
# Option 1: Restart Docker Desktop (if you want to use its kubectl)
# - Quit Docker Desktop in Windows
# - Restart it
# - Wait for full startup
# - Try: kubectl version --client

# Option 2: Install standalone kubectl (recommended)
sudo rm -f /usr/local/bin/kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# See Environment-Specific Setup section for complete WSL guide
```

**Symptom**: RunAI login fails with browser error

**Fix**:
```bash
# Don't use: runai login
# Use this instead:
runai login remote-browser

# Copy the URL to your Windows browser
# Complete authentication
# Paste the code back in terminal
```

**Symptom**: Extremely slow file operations or data loading

**Fix**:
```bash
# Move data from Windows filesystem to WSL
mkdir -p ~/gapit3-gwas/data
cp -r /mnt/c/Users/yourname/data/* ~/gapit3-gwas/data/

# Update your workflow YAML files to use WSL paths
# See Environment-Specific Setup → File Path Considerations
```

### Debugging Commands

```bash
# Get all workflow events
kubectl get events --sort-by='.lastTimestamp' | grep <workflow-name>

# Exec into a running pod
kubectl exec -it <pod-name> -- /bin/bash

# Check available resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# View workflow YAML
argo get <workflow-name> -o yaml

# Resubmit failed workflow
argo resubmit <workflow-name>

# Delete stuck workflow
argo delete <workflow-name>
```

---

## Next Steps

### Production Deployment

Once the test pipeline succeeds:

1. **Run Full Pipeline** (184 traits):
   ```bash
   argo submit cluster/argo/workflows/gapit3-parallel-pipeline.yaml --watch
   ```

2. **Monitor at Scale**:
   - Use Argo UI for DAG visualization
   - Set up alerts for failures
   - Monitor cluster resource usage

3. **Optimize Settings**:
   - Adjust `max-parallelism` based on cluster capacity
   - Tune CPU/memory requests per trait
   - Configure retry strategies

### RunAI-Specific Features

If using RunAI for advanced scheduling:

```bash
# Submit via RunAI (alternative to Argo)
runai workspace submit gapit3-test \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest \
  --cpu-core-request 12 --cpu-memory-request 32G \
  --gpu 0 \
  --host-path path=/hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data,mount=/data,mount-propagation=HostToContainer \
  --host-path path=/hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
  --command -- /scripts/entrypoint.sh run-single-trait --trait-index 2

# Use RunAI with Argo (annotations already configured)
# The workflow template includes: runai/preemptible: "true"
```

### Performance Tuning

- **Memory**: Increase if jobs are OOM killed
- **CPU**: More cores = faster GWAS (diminishing returns after 16)
- **Parallelism**: Max 50 concurrent traits (configurable in workflow)
- **Storage**: Use SSD-backed NFS for better I/O performance

---

---

## Latest Test Results (2025-11-07)

### Workflow Validation Fix
**Status**: ✅ RESOLVED

Fixed Argo Workflows validation error where parameterized `hostPath` volumes in WorkflowTemplates caused submission failures.

**Issue**: `quantities must match the regular expression` error occurred because Argo validates templates before parameter substitution.

**Solution**:
- Moved volume definitions from WorkflowTemplate to Workflow level
- Changed resources (CPU, memory) from parameterized to fixed values
- Templates now reference volumes by name only

**Result**: Workflows now submit successfully without validation errors.

See [openspec/changes/fix-argo-workflow-validation/](../openspec/changes/fix-argo-workflow-validation/) for complete technical details.

### RBAC Permissions Issue (Resolved)
**Status**: ✅ RESOLVED

RBAC permissions have been granted. Argo Workflows and RunAI CLI execution both work correctly.

See [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md) for historical context.

### Successful Manual RunAI Test (2025-11-07)
**Status**: ✅ SUCCESS

Successfully tested single trait execution using RunAI CLI.

**Test Configuration**:
- **Trait**: Index 2 (first phenotype trait)
- **Models**: BLINK + FarmCPU
- **Resources**: 12 CPU cores, 32GB RAM
- **Image**: `ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test`
- **Execution**: `runai workspace submit` (v2 CLI syntax)

**Results**:
- ✅ BLINK model completed in ~5.5 minutes
- ✅ FarmCPU model completed successfully
- ✅ Identified 3 significant QTNs
- ✅ Generated Manhattan plots, QQ plots, GWAS results CSV
- ✅ All output files created correctly in `/outputs/trait_002_*/`

**Key Findings**:
1. Pipeline works end-to-end when bypassing Argo orchestration
2. RunAI CLI syntax has changed (use `runai workspace submit` not `runai submit`)
3. Project name is `talmo-lab` (not `runai-talmo-lab`)
4. Both BLINK and FarmCPU models execute correctly and complement each other

**Batch Execution**:
- Created [scripts/submit-all-traits-runai.sh](../scripts/submit-all-traits-runai.sh) for automated submission
- Includes concurrency control (max 50 parallel jobs)
- Created [scripts/monitor-runai-jobs.sh](../scripts/monitor-runai-jobs.sh) for live monitoring

See [MANUAL_RUNAI_EXECUTION.md](MANUAL_RUNAI_EXECUTION.md) for complete manual execution guide.

---

## Reference

- **Workflows**: [cluster/argo/workflows/](../cluster/argo/workflows/)
- **Templates**: [cluster/argo/workflow-templates/](../cluster/argo/workflow-templates/)
- **Config**: [config/config.yaml](../config/config.yaml)
- **Scripts**: [scripts/](../scripts/)
- **Manual RunAI Guide**: [MANUAL_RUNAI_EXECUTION.md](MANUAL_RUNAI_EXECUTION.md)
- **RunAI Quick Reference**: [RUNAI_QUICK_REFERENCE.md](RUNAI_QUICK_REFERENCE.md)
- **RBAC Issue**: [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md)
- **Argo Docs**: https://argoproj.github.io/argo-workflows/
- **RunAI Docs**: https://docs.run.ai/
