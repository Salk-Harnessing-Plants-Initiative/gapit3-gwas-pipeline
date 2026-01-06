# GAPIT3 GWAS Pipeline

[![Docker Build](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/docker-build.yml/badge.svg)](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/docker-build.yml)
[![R Script Tests](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/test-r-scripts.yml/badge.svg)](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/test-r-scripts.yml)
[![Devcontainer Tests](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/test-devcontainer.yml/badge.svg)](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/test-devcontainer.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Dockerized, parallelized GAPIT3 pipeline for high-throughput genome-wide association studies (GWAS) on GPU/CPU clusters using Argo Workflows. Designed for reproducible, traceable, and FAIR-compliant GWAS analysis in plants and other organisms.

## Pipeline Overview

**What is GWAS?** Genome-Wide Association Studies identify genetic variants (SNPs) that are statistically associated with phenotypic traits. This pipeline automates GWAS analysis for any number of traits in parallel.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Data Flow                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Genotype (HapMap)  +  Phenotype (N traits)                   │
│          │                    │                                 │
│          └────────┬───────────┘                                 │
│                   ↓                                             │
│   ┌───────────────────────────────────────┐                    │
│   │  GAPIT3 Models (per trait, parallel)  │                    │
│   │  • BLINK (fast, high power)           │                    │
│   │  • FarmCPU (balanced)                 │                    │
│   │  • MLM (traditional)                  │                    │
│   └───────────────────────────────────────┘                    │
│                   ↓                                             │
│   ┌───────────────────────────────────────┐                    │
│   │  Outputs (per trait)                  │                    │
│   │  • Manhattan plots                    │                    │
│   │  • QQ plots                           │                    │
│   │  • Significant SNPs CSV               │                    │
│   │  • Execution metadata (JSON)          │                    │
│   └───────────────────────────────────────┘                    │
│                   ↓                                             │
│   Aggregated Results (all traits combined)                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Learn More:**
- [GAPIT3 Documentation](https://zzlab.net/GAPIT/) - Algorithm details and parameters
- [docs/WORKFLOW_ARCHITECTURE.md](docs/WORKFLOW_ARCHITECTURE.md) - Technical implementation
- [docs/SCRIPTS_REFERENCE.md](docs/SCRIPTS_REFERENCE.md) - Script parameters and usage

---

## Features

- **Parallelized Execution**: Run N traits simultaneously on Argo Workflows (trait count detected from phenotype file)
- **Fully Containerized**: Docker + devcontainer support for local development
- **Multi-Model Support**: BLINK, FarmCPU, MLM, and other [GAPIT3 models](https://zzlab.net/GAPIT/)
- **FAIR Principles**: Metadata tracking, provenance, and reproducibility
- **Optimized Performance**: Multi-threaded OpenBLAS for fast linear algebra
- **Auto-Aggregation**: Collect and summarize results from all traits
- **Species-Agnostic**: Works with any organism using HapMap-format genotype data

---

## Current Status

### Fully Operational

Both execution methods are working:

- **Argo Workflows** - Full orchestration with parallel execution
- **RunAI CLI** - Direct job submission (alternative method)

See [QUICKSTART.md](QUICKSTART.md) to get started.

---

## Quick Start

### For Cluster Users (Argo Workflows)

```bash
# 1. Clone repository
git clone https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline.git
cd gapit3-gwas-pipeline

# 2. Update paths in cluster/argo workflows (see docs/ARGO_SETUP.md)

# 3. Install workflow templates
cd cluster/argo
./scripts/submit_workflow.sh templates

# 4. Run test (3 traits)
./scripts/submit_workflow.sh test \
  --data-path /your/nfs/path/data \
  --output-path /your/nfs/path/outputs

# 5. Run full pipeline (all traits in phenotype file)
./scripts/submit_workflow.sh full \
  --data-path /your/nfs/path/data \
  --output-path /your/nfs/path/outputs \
  --max-parallel 50
```

**See [docs/ARGO_SETUP.md](docs/ARGO_SETUP.md) for detailed instructions.**

### For Local Development

```bash
# Open in VS Code with devcontainer
code .
# VS Code will prompt to "Reopen in Container"

# Or build Docker image locally
docker build -t gapit3-gwas-pipeline .

# Run single trait
docker run -v $(pwd)/data:/data -v $(pwd)/outputs:/outputs \
  gapit3-gwas-pipeline run-single-trait --trait-index 2
```

---

## Runtime Configuration

The GAPIT3 container is **fully configurable at runtime** via environment variables - no image rebuild required to change analysis parameters.

### Quick Examples

**Change models without rebuilding:**
```bash
# Fast preliminary scan (BLINK only)
docker run --rm \
  -v /data:/data \
  -v /outputs:/outputs \
  -e TRAIT_INDEX=2 \
  -e MODEL=BLINK \
  gapit3:latest

# Validation run (multiple models with population structure)
docker run --rm \
  -e TRAIT_INDEX=2 \
  -e MODEL=BLINK,FarmCPU,MLM \
  -e PCA_TOTAL=5 \
  gapit3:latest
```

**RunAI deployment:**
```bash
runai workspace submit gapit3-trait-2 \
  --project talmo-lab \
  --image ghcr.io/.../gapit3:latest \
  --environment TRAIT_INDEX=2 \
  --environment MODEL=BLINK \
  --environment PCA_TOTAL=5 \
  --environment SNP_THRESHOLD=5e-8
```

**Local development with .env file:**
```bash
# Copy example and customize
cp .env.example .env
nano .env

# Run with your configuration
docker run --rm --env-file .env gapit3:latest
```

### GAPIT Parameters

Parameter names follow GAPIT v3.0.0 conventions. **See [docs/GAPIT_PARAMETERS.md](docs/GAPIT_PARAMETERS.md) for complete parameter reference.**

**Core Parameters (GAPIT native names):**

| Parameter | Description | GAPIT Default |
|-----------|-------------|---------------|
| `MODEL` | GWAS models (BLINK, FarmCPU, MLM, etc.) | `MLM` |
| `PCA_TOTAL` | Principal components (0-20) | `0` |
| `SNP_MAF` | Minor allele frequency filter | `0` |
| `SNP_THRESHOLD` | Significance p-value cutoff | `0.05` |
| `SNP_FDR` | FDR correction threshold | disabled |

**Additional GAPIT Parameters:**

| Parameter | Description | GAPIT Default |
|-----------|-------------|---------------|
| `KINSHIP_ALGORITHM` | Kinship matrix method (VanRaden, Zhang, Loiselle, EMMA) | `VanRaden` |
| `SNP_EFFECT` | Genetic effect model (Add, Dom) | `Add` |
| `SNP_IMPUTE` | Missing data imputation (Middle, Major, Minor) | `Middle` |

**Paths:**
- `TRAIT_INDEX` - Which trait column to analyze (required)
- `DATA_PATH` - Input data directory
- `OUTPUT_PATH` - Output directory
- `GENOTYPE_FILE` - Genotype HapMap file path
- `PHENOTYPE_FILE` - Phenotype file path

**Computational Resources:**
- `OPENBLAS_NUM_THREADS` - Linear algebra threads (default: `12`)
- `OMP_NUM_THREADS` - OpenMP threads (default: `12`)

> **Note**: Legacy parameter names (`MODELS`, `PCA_COMPONENTS`, `MAF_FILTER`) are still supported but deprecated. They will show warnings and be automatically mapped to the new names.

**See [.env.example](.env.example) for complete documentation of all options.**

### Configuration Priority

1. **Command-line arguments** (highest priority)
2. **Environment variables** (RunAI `--environment` or Docker `-e`)
3. **Defaults in entrypoint.sh** (lowest priority)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Argo Workflows (Cluster Orchestration)                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Validation Step (Pre-flight checks)                    │
│     └─ Validate input files, config, parameters            │
│                                                             │
│  2. Trait Extraction (Generate manifest)                   │
│     └─ Extract N trait names from phenotype file           │
│                                                             │
│  3. Parallel GWAS Execution (N concurrent jobs)            │
│     ├─ Trait 1: BLINK + FarmCPU  (configurable resources) │
│     ├─ Trait 2: BLINK + FarmCPU  (configurable resources) │
│     ├─ ...                                                  │
│     └─ Trait N: BLINK + FarmCPU  (configurable resources) │
│        │                                                    │
│        └─ Each job produces:                                │
│           ├─ Manhattan plots                                │
│           ├─ QQ plots                                       │
│           ├─ GWAS results (p-values, effect sizes)         │
│           └─ Execution metadata (JSON)                      │
│                                                             │
│  4. Results Collection (Aggregation)                        │
│     └─ Combine significant SNPs with model tracking        │
│        - Reads GAPIT Filter files (significant SNPs only)  │
│        - Tracks which model found each SNP                 │
│        - Generates per-model summary statistics            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

> **Note**: N = number of trait columns in your phenotype file (columns 2 through end).
> See [docs/RESOURCE_SIZING.md](docs/RESOURCE_SIZING.md) for memory/CPU recommendations.

### File Structure

```
gapit3-gwas-pipeline/
├── Dockerfile                  # Production container
├── .devcontainer/             # VS Code devcontainer config
├── .env.example               # Runtime configuration documentation
├── cluster/
│   └── argo/
│       ├── workflow-templates/  # Reusable Argo templates
│       ├── workflows/           # Main workflows (test, full)
│       └── scripts/             # Helper scripts (submit, monitor)
├── scripts/
│   ├── run_gwas_single_trait.R    # Core GWAS script
│   ├── collect_results.R          # Results aggregator (with model tracking)
│   ├── validate_inputs.R          # Input validation
│   ├── entrypoint.sh              # Container entrypoint (handles runtime config)
│   ├── submit-all-traits-runai.sh # Batch submission helper
│   ├── monitor-runai-jobs.sh      # Job monitoring dashboard
│   ├── aggregate-runai-results.sh # Results aggregation
│   └── cleanup-runai.sh           # Cleanup helper
└── docs/
    ├── ARGO_SETUP.md              # Cluster setup guide
    ├── MANUAL_RUNAI_EXECUTION.md  # RunAI workaround guide
    └── RBAC_PERMISSIONS_ISSUE.md  # Admin information
```

---

## Requirements

### Computational Resources (Per Trait)

> **Example**: Based on reference dataset (546 samples, ~1.4M SNPs). Your requirements will vary based on dataset size. See [docs/RESOURCE_SIZING.md](docs/RESOURCE_SIZING.md) for sizing formulas.

| Resource | Minimum | Recommended | Optimal |
|----------|---------|-------------|---------|
| **RAM** | 16 GB | 32 GB | 64 GB |
| **CPU** | 8 cores | 12 cores | 16 cores |
| **Disk** | 10 GB | 20 GB | 50 GB |

### Software

- **Cluster**: Kubernetes with Argo Workflows
- **Local Dev**: Docker + VS Code (optional)
- **CLI Tools**: `argo`, `kubectl`, `git`

> **Windows Users**: If using WSL (Windows Subsystem for Linux), see [WSL Setup Guide](docs/DEPLOYMENT_TESTING.md#environment-specific-setup) for important configuration notes regarding kubectl and RunAI authentication.

### Input Data

```
data/
├── genotype/
│   └── acc_snps_filtered_maf_perl_edited_diploid.hmp.txt  # HapMap format
├── phenotype/
│   └── iron_traits_edited.txt                             # Tab-delimited with "Taxa" column
└── metadata/
    └── ids_gwas.txt                                        # Accession IDs (optional)
```

---

## Documentation

### Deployment & Execution
- **[Argo Setup Guide](docs/ARGO_SETUP.md)** - Complete cluster deployment instructions
- **[Manual RunAI Execution](docs/MANUAL_RUNAI_EXECUTION.md)** - Current workaround for RBAC issue
- **[RunAI Quick Reference](docs/RUNAI_QUICK_REFERENCE.md)** - Command cheat sheet
- **[RBAC Permissions Issue](docs/RBAC_PERMISSIONS_ISSUE.md)** - For cluster administrators

### Usage & Configuration
- **[Usage Guide](docs/USAGE.md)** - Parameter reference and configuration recipes
- **[Data Requirements](docs/DATA_REQUIREMENTS.md)** - Input/output file formats
- **[.env.example](.env.example)** - Complete runtime configuration reference

### Testing & Troubleshooting
- **[Deployment Testing](docs/DEPLOYMENT_TESTING.md)** - Test results and validation
- **[WSL Setup Notes](docs/DEPLOYMENT_TESTING.md#environment-specific-setup)** - Windows/WSL users

---

## Example Workflow

### Test Run (3 Traits)

```bash
cd cluster/argo

# Submit test workflow
./scripts/submit_workflow.sh test \
  --data-path /hpi/hpi_dev/users/yourname/gapit3-gwas/data \
  --output-path /hpi/hpi_dev/users/yourname/gapit3-gwas/outputs

# Monitor progress
./scripts/monitor_workflow.sh watch gapit3-test-abc123

# Expected output:
# ✓ Validation passed
# ✓ Extracted N traits (from phenotype file)
# ✓ Running traits 2, 3, 4 in parallel
# ✓ Workflow completed in ~45 minutes
```

### Production Run (All Traits)

```bash
# Submit full pipeline
./scripts/submit_workflow.sh full \
  --data-path /hpi/hpi_dev/users/yourname/gapit3-gwas/data \
  --output-path /hpi/hpi_dev/users/yourname/gapit3-gwas/outputs \
  --max-parallel 50 \
  --cpu 12 \
  --memory 32

# Monitor
./scripts/monitor_workflow.sh watch gapit3-gwas-parallel-xyz789

# Results will be in:
# outputs/
# ├── trait_002_*/                    (per-trait results)
# ├── trait_003_*/ ... trait_NNN_*/   (one directory per trait)
# └── aggregated_results/             (summary across all traits)
```

---

## Configuration

### Runtime Configuration via Environment Variables ([.env.example](.env.example))

All GAPIT parameters are configured through environment variables. See [.env.example](.env.example) and [docs/GAPIT_PARAMETERS.md](docs/GAPIT_PARAMETERS.md) for complete documentation.

```bash
# Key parameters (GAPIT v3.0.0 native names)
MODEL=BLINK,FarmCPU     # GWAS models to run
PCA_TOTAL=3             # Population structure correction
SNP_THRESHOLD=5e-8      # Significance threshold
SNP_MAF=0.05            # Minor allele frequency filter
```

### Argo Parallelization

```yaml
# In workflows/gapit3-parallel-pipeline.yaml
arguments:
  parameters:
  - name: max-parallelism
    value: "50"  # Adjust based on cluster capacity
```

---

## Results

### Individual Trait Output

Each trait produces:
- **Manhattan plot**: Genome-wide significance visualization
- **QQ plot**: P-value distribution
- **GWAS results CSV**: SNP positions, p-values, effect sizes
- **Metadata JSON**: Execution provenance (timestamps, versions, input checksums)

### Aggregated Results

```
outputs/aggregated_results/
├── pipeline_summary.md                # Human-readable summary report
├── summary_table.csv                  # All traits: sample sizes, durations, status
├── all_traits_significant_snps.csv    # SNPs below p < 5e-8 (with model column)
└── summary_stats.json                 # Per-model statistics and overlaps
```

**Pipeline Summary Report** (`pipeline_summary.md`):

The markdown summary provides a shareable, human-readable overview including:
- Executive summary (workflow ID, dates, totals, top hits)
- Configuration (models, PCA, MAF, SNP count)
- Top 20 significant SNPs table
- Top 10 traits by hit count
- Model statistics with cross-validation
- Chromosome distribution
- Quality metrics and reproducibility info

To regenerate the markdown from existing results:
```bash
Rscript scripts/collect_results.R --output-dir /path/to/outputs --markdown-only
```

**Output CSV format** (`all_traits_significant_snps.csv`):
```csv
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model
SNP_123,1,12345,1.2e-9,0.15,500,0.05,2.3e-8,root_length,BLINK
SNP_123,1,12345,2.3e-9,0.15,500,0.06,3.1e-8,root_length,FarmCPU
```

- Sorted by P.value (most significant first)
- SNPs found by multiple models appear as separate rows
- `model` column enables filtering and comparison

**Summary statistics** (`summary_stats.json`):
```json
{
  "snps_by_model": {
    "BLINK": 25,
    "FarmCPU": 28,
    "both_models": 11
  }
}
```

---

## Performance

### Benchmarks

> **Reference dataset**: 546 samples, ~1.4M SNPs, 184 traits. Your runtime will scale with dataset size.

| Configuration | Traits | Time | Notes |
|---------------|--------|------|-------|
| Single job (serial) | 1 trait | ~15 min | BLINK only |
| Parallel (50 jobs) | N traits | ~4 hours | BLINK + FarmCPU (reference dataset) |
| Parallel (100 jobs) | N traits | ~2.5 hours | If cluster allows |

### Optimization Tips

1. **BLINK only**: ~2x faster than BLINK + FarmCPU
2. **LD pruning**: Reduces SNP count, faster runtime
3. **Increase parallelism**: Limited by cluster capacity
4. **MAF filtering**: Exclude rare variants (pre-processing)

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `OOMKilled` (out of memory) | Increase `--memory 36` or reduce parallelism |
| `Directory not found` | Verify NFS paths exist on cluster nodes |
| `WorkflowTemplate not found` | Run `./scripts/submit_workflow.sh templates` |
| Image pull errors | Check GHCR permissions, verify image exists |

See [docs/ARGO_SETUP.md](docs/ARGO_SETUP.md#troubleshooting) for detailed troubleshooting.

---

## Citation

If you use this pipeline, please cite:

```bibtex
@software{gapit3_gwas_pipeline,
  author = {Salk Harnessing Plants Initiative},
  title = {GAPIT3 GWAS Pipeline: Parallelized GWAS for High-Throughput Analysis},
  year = {2025},
  url = {https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline}
}
```

**GAPIT3 Citation:**
```bibtex
@article{wang2021gapit3,
  title={GAPIT version 3: Boosting power and accuracy for genomic association and prediction},
  author={Wang, Jiabo and Zhang, Zhiwu},
  journal={Genomics, Proteomics & Bioinformatics},
  year={2021}
}
```

---

## Contributing

Contributions welcome! Please follow these steps:

### Development Workflow

1. **Fork and clone** the repository
2. **Open in devcontainer** (recommended) for consistent environment:
   ```bash
   code .
   # VS Code will prompt: "Reopen in Container"
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes** and write tests
5. **Run tests locally**:
   ```bash
   # R unit tests
   Rscript tests/testthat.R

   # Docker build test
   docker build -t gapit3-test .
   ```
6. **Commit with conventional commits**:
   ```bash
   git commit -m "feat: Add new feature"
   git commit -m "fix: Correct validation bug"
   git commit -m "docs: Update README"
   ```
7. **Push and create Pull Request**:
   ```bash
   git push origin feature/your-feature-name
   ```

### Testing Requirements

All PRs must:
- ✅ Pass R unit tests
- ✅ Pass Docker build and functional tests
- ✅ Include tests for new functionality
- ✅ Update documentation as needed

See [docs/TESTING.md](docs/TESTING.md) for detailed testing guide.

### Code Style

- **R Scripts**: snake_case, descriptive names, optparse for arguments
- **YAML Files**: kebab-case, inline comments, TODO for customization
- **Commits**: Conventional commits (feat, fix, docs, test, chore)

See [openspec/project.md](openspec/project.md) for complete conventions.

---

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **GAPIT3 Development Team** (Jiabo Wang, Zhiwu Zhang)
- **Salk Institute Harnessing Plants Initiative**
- **Run.AI and Argo Workflows communities**
- Inspired by [SLEAP-Roots Pipeline](https://github.com/talmolab/sleap-roots-pipeline)

---

## Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/discussions)

---

**Status**: Production-ready ✅

Last updated: 2026-01-05
