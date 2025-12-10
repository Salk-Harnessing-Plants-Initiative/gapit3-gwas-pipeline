# Argo Workflows Directory

This directory contains all Argo Workflows configuration files for running the GAPIT3 GWAS pipeline on Kubernetes.

---

## Directory Structure

```
cluster/argo/
├── README.md                      # This file
├── workflow-templates/            # Reusable workflow templates
│   ├── gapit3-single-trait-template.yaml
│   ├── trait-extractor-template.yaml
│   └── results-collector-template.yaml
├── workflows/                     # Executable workflows
│   ├── gapit3-test-pipeline.yaml
│   └── gapit3-parallel-pipeline.yaml
└── scripts/                       # Helper scripts
    ├── submit_workflow.sh
    └── monitor_workflow.sh
```

---

## Components

### 1. workflow-templates/ - Reusable Templates

WorkflowTemplates are **cluster-level resources** that define reusable components. They must be installed to the cluster before workflows can use them.

#### gapit3-single-trait-template.yaml
**Purpose**: Execute GWAS analysis for a single trait

**Install**:
```bash
kubectl apply -f workflow-templates/gapit3-single-trait-template.yaml -n runai-talmo-lab
```

**Key Features**:
- Fixed resource allocation (64GB RAM, 12 CPU) - see [Resource Requirements](#resource-requirements)
- Volume mounts by reference (defined at workflow level)
- Supports all GAPIT3 models (BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM)
- Outputs metadata JSON for traceability

**Parameters**:
- `trait-index` - Phenotype column number (2-187)
- `trait-name` - Descriptive name for the trait
- `image` - Docker image tag to use
- `models` - Comma-separated GAPIT models (e.g., "BLINK,FarmCPU,MLM")

#### trait-extractor-template.yaml
**Purpose**: Parse phenotype file and generate trait manifest

**Install**:
```bash
kubectl apply -f workflow-templates/trait-extractor-template.yaml -n runai-talmo-lab
```

**Output**: JSON array of trait indices and names from phenotype file

#### results-collector-template.yaml
**Purpose**: Aggregate results from all completed trait analyses

**Install**:
```bash
kubectl apply -f workflow-templates/results-collector-template.yaml -n runai-talmo-lab
```

**Outputs**:
- `summary_table.csv` - Summary of all traits
- `significant_snps.csv` - SNPs below p < 5e-8
- `summary_stats.json` - Overall statistics

**Install All Templates**:
```bash
# Using helper script
./scripts/submit_workflow.sh templates

# Or manually
kubectl apply -f workflow-templates/ -n runai-talmo-lab
```

### 2. workflows/ - Executable Workflows

Workflows are **specific executions** that reference WorkflowTemplates. Each submission creates a new workflow instance.

#### gapit3-test-pipeline.yaml
**Purpose**: Test workflow with 3 traits (2, 3, 4) to validate setup

**Submit**:
```bash
# Using helper script
./scripts/submit_workflow.sh test \
  --data-path /your/data/path \
  --output-path /your/output/path

# Or manually with argo CLI
argo submit workflows/gapit3-test-pipeline.yaml \
  --namespace runai-talmo-lab \
  --parameter data-hostpath=/your/data/path \
  --parameter output-hostpath=/your/output/path \
  --watch
```

**Expected Runtime**: ~30-45 minutes

**Use Case**: Pre-flight check before running all 186 traits

**DAG Structure**:
```
validate-inputs
    ↓
extract-traits
    ↓
[run-trait-2, run-trait-3, run-trait-4] (parallel)
```

#### gapit3-parallel-pipeline.yaml
**Purpose**: Production workflow for all 186 traits (2-187)

**Submit**:
```bash
# Using helper script (recommended)
./scripts/submit_workflow.sh full \
  --data-path /your/data/path \
  --output-path /your/output/path

# Or manually
argo submit workflows/gapit3-parallel-pipeline.yaml \
  --namespace runai-talmo-lab \
  --parameter data-hostpath=/your/data/path \
  --parameter output-hostpath=/your/output/path \
  --watch
```

**Expected Runtime**: ~3-4 hours (with 30 parallel jobs)

**DAG Structure**:
```
validate-inputs
    ↓
extract-traits
    ↓
[run-trait-2, run-trait-3, ..., run-trait-187] (parallel, max 30)
    ↓
collect-results
```

**Configurable Parameters**:
- `data-hostpath` - Path to input data directory
- `output-hostpath` - Path to output directory
- `image` - Docker image tag (default: `sha-bc10fc8-test`)
- `models` - GAPIT models to run (default: `BLINK,FarmCPU,MLM`)
- `snp-fdr` - FDR threshold for Benjamini-Hochberg correction (default: empty/disabled, e.g., `0.05` for 5% FDR)

> **Note**: Resource allocation (CPU, memory) and parallelism are configured directly in YAML files, not via CLI parameters. See [Resource Requirements](#resource-requirements) for details.

### 3. scripts/ - Helper Scripts

#### submit_workflow.sh
**Purpose**: Simplified workflow submission with validation

**Usage**:
```bash
# Install templates
./scripts/submit_workflow.sh templates

# Submit test workflow
./scripts/submit_workflow.sh test \
  --data-path /path/to/data \
  --output-path /path/to/outputs

# Submit full workflow
./scripts/submit_workflow.sh full \
  --data-path /path/to/data \
  --output-path /path/to/outputs
```

**Features**:
- Path validation before submission
- Automatic parameter handling
- Confirmation prompts
- Live progress display

> **Note**: CPU/memory resources are configured in the WorkflowTemplate YAML, not via CLI flags. Edit `workflow-templates/gapit3-single-trait-template.yaml` to change resource allocation.

#### monitor_workflow.sh
**Purpose**: Monitor running workflows with live updates

**Usage**:
```bash
# List all workflows
./scripts/monitor_workflow.sh

# Watch specific workflow (auto-refresh)
./scripts/monitor_workflow.sh watch gapit3-gwas-parallel-abc123

# Show workflow tree
./scripts/monitor_workflow.sh tree gapit3-gwas-parallel-abc123

# Stream logs
./scripts/monitor_workflow.sh logs gapit3-gwas-parallel-abc123
```

**Features**:
- Live progress tracking
- Job status summary (running/succeeded/failed/pending)
- Resource usage monitoring
- Log streaming

---

## Quick Start

### 1. Install Templates (One-Time)

```bash
cd cluster/argo
./scripts/submit_workflow.sh templates
```

Verify installation:
```bash
kubectl get workflowtemplates -n runai-talmo-lab
```

Expected output:
```
NAME                          AGE
gapit3-gwas-single-trait      10s
gapit3-trait-extractor        10s
gapit3-results-collector      10s
```

### 2. Run Test Workflow

```bash
./scripts/submit_workflow.sh test \
  --data-path /hpi/hpi_dev/users/YOUR_USERNAME/data \
  --output-path /hpi/hpi_dev/users/YOUR_USERNAME/outputs
```

### 3. Monitor Progress

```bash
# In another terminal
./scripts/monitor_workflow.sh watch gapit3-test-XXXXX
```

### 4. Run Full Production Workflow

After test succeeds:

```bash
./scripts/submit_workflow.sh full \
  --data-path /hpi/hpi_dev/users/YOUR_USERNAME/data \
  --output-path /hpi/hpi_dev/users/YOUR_USERNAME/outputs
```

---

## Running Commands from Windows via WSL

When running `argo` or `kubectl` commands from Windows (e.g., from VS Code terminal or Claude Code), you must explicitly set the `KUBECONFIG` environment variable. The login shell initialization doesn't work reliably when invoking WSL from Windows.

### Command Pattern

**DO use this pattern:**
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && <your-command>"
```

**DON'T use these patterns** (they hang or fail to authenticate):
```bash
# These don't work reliably from Windows:
wsl bash --login -c "<your-command>"           # Hangs on fstab
wsl -e bash -c "source ~/.bashrc && <command>" # runai not found
```

### Common Commands

**List workflows:**
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo list -n runai-talmo-lab"
```

**Get workflow details:**
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo get <workflow-name> -n runai-talmo-lab"
```

**Watch workflow progress:**
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo watch <workflow-name> -n runai-talmo-lab"
```

**View logs:**
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo logs <workflow-name> -n runai-talmo-lab --follow=false | tail -50"
```

**Submit workflow:**
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo submit cluster/argo/workflows/gapit3-parallel-pipeline.yaml -n runai-talmo-lab --watch"
```

**Stop workflow:**
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo stop <workflow-name> -n runai-talmo-lab"
```

> **Note**: The "wsl: Processing /etc/fstab with mount -a failed" warning is harmless and can be ignored.

---

## Current Status

### ⚠️ RBAC Permissions Issue

Argo Workflows currently require pending RBAC permissions from cluster administrators. Until those are granted:

**Workaround**: Use Manual RunAI CLI execution

```bash
# Use the batch submission script instead
cd ../../scripts
./submit-all-traits-runai.sh

# Monitor with RunAI monitoring script
./monitor-runai-jobs.sh --watch
```

See [docs/MANUAL_RUNAI_EXECUTION.md](../../docs/MANUAL_RUNAI_EXECUTION.md) for complete manual execution guide.

See [docs/RBAC_PERMISSIONS_ISSUE.md](../../docs/RBAC_PERMISSIONS_ISSUE.md) for administrator information.

---

## Configuration

### Required Customization

Before using these workflows, update the following in each YAML file:

1. **Namespace**: Change `default` to your Kubernetes namespace:
   ```yaml
   metadata:
     namespace: your-namespace  # Change this
   ```

2. **Data Paths**: Update default paths in workflow parameters:
   ```yaml
   parameters:
   - name: data-hostpath
     value: "/hpi/hpi_dev/users/YOUR_USERNAME/data"  # Change this
   - name: output-hostpath
     value: "/hpi/hpi_dev/users/YOUR_USERNAME/outputs"  # Change this
   ```

3. **Docker Image**: Verify image tag is correct:
   ```yaml
   - name: image
     value: "ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test"
   ```

### Quick Find-and-Replace

```bash
export NAMESPACE="your-namespace"
export USERNAME="your_username"

# Update all YAML files
find . -name "*.yaml" -exec sed -i \
  "s|namespace: default|namespace: $NAMESPACE|g" {} +

find . -name "*.yaml" -exec sed -i \
  "s|YOUR_USERNAME|$USERNAME|g" {} +
```

---

## Resource Requirements

### Memory Sizing

The WorkflowTemplate allocates **64GB RAM** per trait job. This is required for large genotype datasets due to GAPIT's memory usage during data loading:

| Stage | Memory Usage | Notes |
|-------|-------------|-------|
| Load HapMap file | ~8-10 GB | Raw text loaded into R data.frame |
| Numericalization | ~15-20 GB | Converting text to numeric matrix (peak usage) |
| Numeric matrix | ~6 GB | 1.4M SNPs × 550 accessions × 8 bytes |
| GAPIT analysis | ~5-10 GB | Kinship, PCA, model fitting |
| **Total peak** | ~40-50 GB | During numericalization step |

**Important**: The memory peak occurs during **numericalization** (before any GWAS model runs), not during model execution. All models (BLINK, FarmCPU, MLM, etc.) run sequentially and share the already-loaded data.

### Scaling Guidelines

| Genotype File Size | SNP Count | Recommended Memory |
|-------------------|-----------|-------------------|
| < 500 MB | < 500K SNPs | 32 GB |
| 500 MB - 1 GB | 500K - 1M SNPs | 48 GB |
| 1 - 2.5 GB | 1M - 1.5M SNPs | 64 GB |
| > 2.5 GB | > 1.5M SNPs | 96+ GB |

### Current Configuration

```yaml
# In gapit3-single-trait-template.yaml
resources:
  requests:
    memory: "64Gi"
    cpu: "12"
  limits:
    memory: "72Gi"  # Headroom for peak usage
    cpu: "16"
```

### Parallelism vs Resources

With `parallelism: 30` and 64GB per job:
- **Peak memory**: 30 × 64GB = 1.92 TB cluster-wide
- **Peak CPU**: 30 × 12 = 360 cores cluster-wide

Adjust `spec.parallelism` in the workflow if cluster resources are limited.

---

## Retrying Failed Traits

When traits fail due to OOM or timeout, use the retry script to rerun only the incomplete traits.

### Detect Incomplete Traits

The retry script inspects output directories to find traits with missing model outputs:

```bash
./scripts/retry-argo-traits.sh \
  --workflow gapit3-gwas-parallel-8nj24 \
  --output-dir "Z:/users/eberrigan/.../outputs" \
  --dry-run
```

This will show:
- **Missing traits**: No output directory at all
- **Incomplete traits**: Have some model outputs but missing others (e.g., BLINK/FarmCPU completed, MLM missing)

### Retry with High Memory

For OOM failures (exit code 137), use the high-memory template:

```bash
./scripts/retry-argo-traits.sh \
  --workflow gapit3-gwas-parallel-8nj24 \
  --output-dir "Z:/users/eberrigan/.../outputs" \
  --highmem \
  --submit
```

**High-memory template resources:**
| Resource | Normal | High-Memory |
|----------|--------|-------------|
| Memory request | 64Gi | 96Gi |
| Memory limit | 72Gi | 104Gi |
| CPU request | 12 | 16 |
| CPU limit | 16 | 20 |
| Thread env vars | 12 | 16 |

### Manual Trait Specification

If you know which traits failed:

```bash
./scripts/retry-argo-traits.sh \
  --workflow gapit3-gwas-parallel-8nj24 \
  --traits 5,28,29,30,31 \
  --highmem \
  --submit
```

### Retry with Aggregation

Run retries and automatically aggregate results when complete:

```bash
./scripts/retry-argo-traits.sh \
  --workflow gapit3-gwas-parallel-8nj24 \
  --output-dir "Z:/users/eberrigan/.../outputs" \
  --highmem \
  --aggregate \
  --watch
```

**`--aggregate` flag behavior:**
- Adds a `collect-results` task to the retry workflow DAG
- Aggregation runs **in-cluster** after all retry tasks complete
- References the `gapit3-results-collector` WorkflowTemplate
- No local R script or RunAI CLI required
- SNP FDR threshold is automatically propagated from the original workflow

### Duplicate Trait Directory Handling

When retries create multiple directories for the same trait (e.g., `trait_005_20231112_*` and `trait_005_20231123_*`), the aggregation script automatically selects the best directory:

1. **Priority: Model completeness** - Directory with most complete model outputs wins
2. **Tie-breaker: Newest** - If completeness is equal, most recent timestamp wins

Example output:
```
Note: Found multiple directories for 3 trait(s)
Selecting most complete directory for each:
  - Trait 5: 2 directories
    Selected: trait_005_Zn_ICP_20231123_120000 (3/3 models)
    Skipped: trait_005_Zn_ICP_20231112_200000 (2/3 models)
```

### Install High-Memory Template

Before using `--highmem`, install the template:

```bash
kubectl apply -f workflow-templates/gapit3-single-trait-template-highmem.yaml -n runai-talmo-lab
```

---

## Troubleshooting

### WorkflowTemplate not found

```
Error: workflowtemplate.argoproj.io "gapit3-gwas-single-trait" not found
```

**Solution**: Install templates first:
```bash
./scripts/submit_workflow.sh templates
```

### Volume validation errors

```
Error: quantities must match the regular expression
```

**This should not happen** - the workflow validation fix has been applied.

If you see this error, ensure:
1. Volumes are defined at workflow level (in `workflows/*.yaml`)
2. Resources are fixed values (not parameters) in WorkflowTemplates
3. Using latest templates from this directory

See [docs/WORKFLOW_ARCHITECTURE.md](../../docs/WORKFLOW_ARCHITECTURE.md#volume-configuration) for technical details.

### Image pull errors

```
ErrImagePull or ImagePullBackOff
```

**Solution**:
```bash
# Verify image exists
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test

# If using custom image, update workflow parameter:
argo submit workflows/gapit3-test-pipeline.yaml \
  --parameter image="your-custom-image:tag"
```

### RBAC permissions error

```
Error (exit code 64): workflowtaskresults.argoproj.io is forbidden
```

**This is expected** - see [Current Status](#current-status) above for workaround.

---

## Architecture

For detailed technical documentation about the workflow architecture, see:

- [docs/WORKFLOW_ARCHITECTURE.md](../../docs/WORKFLOW_ARCHITECTURE.md) - Technical deep dive
- [docs/ARGO_SETUP.md](../../docs/ARGO_SETUP.md) - Setup guide
- [openspec/changes/fix-argo-workflow-validation/](../../openspec/changes/fix-argo-workflow-validation/) - Workflow validation fix

---

## Related Documentation

- [Argo Setup Guide](../../docs/ARGO_SETUP.md)
- [Manual RunAI Execution](../../docs/MANUAL_RUNAI_EXECUTION.md)
- [RunAI Quick Reference](../../docs/RUNAI_QUICK_REFERENCE.md)
- [Deployment Testing](../../docs/DEPLOYMENT_TESTING.md)
- [Workflow Architecture](../../docs/WORKFLOW_ARCHITECTURE.md)

---

**Last Updated**: 2025-12-08