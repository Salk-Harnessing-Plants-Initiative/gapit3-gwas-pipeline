# GAPIT3 GWAS Pipeline - Quick Start Guide

**For non-technical users**: This guide walks you through running the GWAS analysis step-by-step.

> **⚠️ IMPORTANT - Current Status (2025-11-07):**
>
> **Argo Workflows** require pending RBAC permissions from cluster administrators. Until those are granted, please use the **Manual RunAI execution method** documented in [Manual RunAI Execution Guide](docs/MANUAL_RUNAI_EXECUTION.md).
>
> **Quick workaround:** Use [scripts/submit-all-traits-runai.sh](scripts/submit-all-traits-runai.sh) to submit jobs directly via RunAI CLI. This fully works now!
>
> See [RBAC_PERMISSIONS_ISSUE.md](docs/RBAC_PERMISSIONS_ISSUE.md) for details.

---

## What This Pipeline Does

Analyzes **184 iron traits** across **546 Arabidopsis accessions** using **~1.4 million SNPs** to find genetic variants associated with each trait.

Instead of running 184 separate analyses sequentially (taking days), this pipeline runs them **in parallel on the cluster** (taking ~3-4 hours).

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] Access to the cluster with Argo Workflows installed
- [ ] Your data files on the shared NFS filesystem:
  - `acc_snps_filtered_maf_perl_edited_diploid.hmp.txt` (genotype data)
  - `iron_traits_edited.txt` (phenotype data)
  - `ids_gwas.txt` (accession IDs)
- [ ] `argo` CLI tool installed on your computer
- [ ] `kubectl` access to the cluster

---

## Step-by-Step Instructions

### 1. Get the Code

```bash
# Clone the repository
git clone https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline.git
cd gapit3-gwas-pipeline
```

### 2. Update Paths (One-Time Setup)

Open these files and replace `YOUR_USERNAME` with your actual username:

**Files to edit:**
- `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`
- `cluster/argo/workflow-templates/trait-extractor-template.yaml`
- `cluster/argo/workflow-templates/results-collector-template.yaml`
- `cluster/argo/workflows/gapit3-test-pipeline.yaml`
- `cluster/argo/workflows/gapit3-parallel-pipeline.yaml`

**Find and replace:**
```
/hpi/hpi_dev/users/YOUR_USERNAME
```
**With your actual path, for example:**
```
/hpi/hpi_dev/users/eberrigan
```

Or use this command (Linux/macOS):
```bash
export MY_USER="eberrigan"  # <-- CHANGE THIS

find cluster/argo -type f -name "*.yaml" -exec sed -i \
  "s|YOUR_USERNAME|$MY_USER|g" {} +
```

### 3. Install Workflow Templates (One-Time Setup)

```bash
cd cluster/argo

# Install templates to the cluster
./scripts/submit_workflow.sh templates

# You should see:
# ✓ Installed: gapit3-single-trait-template
# ✓ Installed: trait-extractor-template
# ✓ Installed: results-collector-template
```

### 4. Run a Test (Recommended First)

Test with 3 traits to make sure everything works:

```bash
./scripts/submit_workflow.sh test \
  --data-path /hpi/hpi_dev/users/eberrigan/gapit3-gwas/data \
  --output-path /hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs

# You'll be asked: "Submit workflow? (y/N):"
# Type: y

# The workflow will start and you'll see live updates
```

**Expected output:**
```
✓ Validation passed
✓ Extracted 186 traits
Running traits 2, 3, 4 in parallel...
⟳ Running:   3
✓ Succeeded: 0
⏸ Pending:   0
✗ Failed:    0
```

**Time:** ~30-45 minutes

### 5. Check Test Results

```bash
# On the cluster, check the outputs directory
ls -la /hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs/

# You should see:
# trait_002_20250222_143000/
# trait_003_20250222_143005/
# trait_004_20250222_143010/
```

Each directory contains:
- `GAPIT.Association.GWAS_Results.csv` - Main results
- `GAPIT.Manhattan.*.pdf` - Visualization
- `GAPIT.QQ-Plot.*.pdf` - QQ plot
- `metadata.json` - Run information

### 6. Run Full Analysis (All 184 Traits)

Once the test succeeds:

```bash
./scripts/submit_workflow.sh full \
  --data-path /hpi/hpi_dev/users/eberrigan/gapit3-gwas/data \
  --output-path /hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs \
  --max-parallel 50 \
  --cpu 12 \
  --memory 32

# Confirm: y
```

**Parameters explained:**
- `--max-parallel 50`: Run 50 traits at the same time (adjust based on cluster availability)
- `--cpu 12`: Use 12 CPU cores per trait
- `--memory 32`: Use 32GB RAM per trait

**Expected time:** ~3-4 hours (with 50 parallel jobs)

### 7. Monitor Progress

In a new terminal:

```bash
cd gapit3-gwas-pipeline/cluster/argo

# Live monitoring (auto-refresh every 10 seconds)
./scripts/monitor_workflow.sh watch gapit3-gwas-parallel-XXXXX
# (replace XXXXX with the actual workflow ID shown when you submitted)

# Or just check status once
./scripts/monitor_workflow.sh gapit3-gwas-parallel-XXXXX
```

You'll see:
```
========================================
GAPIT3 GWAS - Workflow Monitor
Workflow: gapit3-gwas-parallel-abc123
========================================

Status: Running

Progress:
  ✓ Succeeded: 47
  ⟳ Running:   50
  ⏸ Pending:   87
  ✗ Failed:    0
```

### 8. Get Results

After completion:

```bash
# Check the aggregated results
ls -la /hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs/aggregated_results/

# Files:
# summary_table.csv       - Overview of all traits
# significant_snps.csv    - All SNPs with p < 5e-8
# summary_stats.json      - Overall statistics
```

### 9. Download Results to Your Computer

```bash
# From your local computer:
rsync -avz username@cluster:/hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs ./results/

# Or tar and download:
ssh cluster "cd /hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs && tar czf results.tar.gz aggregated_results trait_*"
scp cluster:/hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs/results.tar.gz ./
```

---

## What to Do If Something Goes Wrong

### Test Failed?

```bash
# Check logs
./scripts/monitor_workflow.sh logs gapit3-test-XXXXX

# Common issues:
# 1. "Directory not found" → Check your NFS paths are correct
# 2. "OOMKilled" → Not enough memory (contact cluster admin)
# 3. "Image pull error" → Docker image not built yet (wait for GitHub Actions)
```

### Cancel a Running Workflow

```bash
argo terminate gapit3-gwas-parallel-XXXXX -n default
```

### Retry Failed Traits

```bash
# Argo can resume from failures
argo retry gapit3-gwas-parallel-XXXXX -n default
```

---

## For Your Collaborator (Non-Technical)

**Send them this checklist:**

1. ☐ I've put the data files on the cluster NFS
2. ☐ I've shared the data path with you
3. ☐ You've updated the paths in the YAML files
4. ☐ You've installed the workflow templates
5. ☐ The test run succeeded
6. ☐ I'm ready to submit the full 184-trait analysis

**Commands they need (copy-paste ready):**

```bash
# 1. Install templates (one-time)
cd gapit3-gwas-pipeline/cluster/argo
./scripts/submit_workflow.sh templates

# 2. Test (3 traits)
./scripts/submit_workflow.sh test \
  --data-path /path/to/your/data \
  --output-path /path/to/your/outputs

# 3. Full run (184 traits)
./scripts/submit_workflow.sh full \
  --data-path /path/to/your/data \
  --output-path /path/to/your/outputs \
  --max-parallel 50

# 4. Monitor
./scripts/monitor_workflow.sh watch <workflow-name>
```

---

## Questions?

- **Current workaround**: See [docs/MANUAL_RUNAI_EXECUTION.md](docs/MANUAL_RUNAI_EXECUTION.md)
- **RunAI commands**: See [docs/RUNAI_QUICK_REFERENCE.md](docs/RUNAI_QUICK_REFERENCE.md)
- **Detailed setup**: See [docs/ARGO_SETUP.md](docs/ARGO_SETUP.md)
- **Troubleshooting**: See [docs/ARGO_SETUP.md#troubleshooting](docs/ARGO_SETUP.md#troubleshooting)
- **GitHub issues**: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/issues

---

**Good luck with your GWAS analysis! 🧬🌱**
