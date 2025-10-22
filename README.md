# GAPIT3 GWAS Pipeline

[![Docker Build](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/docker-build.yml/badge.svg)](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/docker-build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Dockerized, parallelized GAPIT3 pipeline for high-throughput genome-wide association studies (GWAS) on GPU/CPU clusters using Argo Workflows. Designed for reproducible, traceable, and FAIR-compliant GWAS analysis in plants and other organisms.

## Features

- 🚀 **Parallelized Execution**: Run 184 traits simultaneously on Argo Workflows
- 🐳 **Fully Containerized**: Docker + devcontainer support for local development
- 📊 **Multi-Model Support**: BLINK, FarmCPU, and other GAPIT3 models
- 🔬 **FAIR Principles**: Metadata tracking, provenance, and reproducibility
- ⚡ **Optimized Performance**: Multi-threaded OpenBLAS for fast linear algebra
- 📈 **Auto-Aggregation**: Collect and summarize results from all traits
- 🎯 **Production-Ready**: Used for Arabidopsis thaliana iron trait analysis (546 accessions, ~1.4M SNPs)

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

# 5. Run full pipeline (184 traits)
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
│     └─ Extract 184 trait names from phenotype file         │
│                                                             │
│  3. Parallel GWAS Execution (184 concurrent jobs)          │
│     ├─ Trait 1: BLINK + FarmCPU  (32GB RAM, 12 CPUs)      │
│     ├─ Trait 2: BLINK + FarmCPU  (32GB RAM, 12 CPUs)      │
│     ├─ ...                                                  │
│     └─ Trait 184: BLINK + FarmCPU (32GB RAM, 12 CPUs)     │
│        │                                                    │
│        └─ Each job produces:                                │
│           ├─ Manhattan plots                                │
│           ├─ QQ plots                                       │
│           ├─ GWAS results (p-values, effect sizes)         │
│           └─ Execution metadata (JSON)                      │
│                                                             │
│  4. Results Collection (Aggregation)                        │
│     └─ Combine significant SNPs, generate summary report   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
gapit3-gwas-pipeline/
├── Dockerfile                  # Production container
├── .devcontainer/             # VS Code devcontainer config
├── cluster/
│   └── argo/
│       ├── workflow-templates/  # Reusable Argo templates
│       ├── workflows/           # Main workflows (test, full)
│       └── scripts/             # Helper scripts (submit, monitor)
├── scripts/
│   ├── run_gwas_single_trait.R    # Core GWAS script
│   ├── collect_results.R          # Results aggregator
│   ├── validate_inputs.R          # Input validation
│   └── entrypoint.sh              # Container entrypoint
├── config/
│   └── config.yaml                # GAPIT parameters
└── docs/
    ├── ARGO_SETUP.md              # Cluster setup guide
    └── USAGE.md                   # Detailed usage
```

---

## Requirements

### Computational Resources (Per Trait)

Based on 546 accessions, ~1.4M SNPs:

| Resource | Minimum | Recommended | Optimal |
|----------|---------|-------------|---------|
| **RAM** | 16 GB | 32 GB | 64 GB |
| **CPU** | 8 cores | 12 cores | 16 cores |
| **Disk** | 10 GB | 20 GB | 50 GB |

### Software

- **Cluster**: Kubernetes with Argo Workflows
- **Local Dev**: Docker + VS Code (optional)
- **CLI Tools**: `argo`, `kubectl`, `git`

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

- **[Argo Setup Guide](docs/ARGO_SETUP.md)** - Complete cluster deployment instructions
- **[Usage Guide](docs/USAGE.md)** - Parameter descriptions and advanced usage
- **[Data Dictionary](docs/DATA_DICTIONARY.md)** - Trait descriptions and metadata

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
# ✓ Extracted 186 traits
# ✓ Running traits 2, 3, 4 in parallel
# ✓ Workflow completed in ~45 minutes
```

### Production Run (All 184 Traits)

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
# ├── trait_002_*/ ... trait_187_*/  (individual results)
# └── aggregated_results/             (summary)
```

---

## Configuration

### GAPIT Parameters ([config/config.yaml](config/config.yaml))

```yaml
gapit:
  models:
    - BLINK      # Fast, effective
    - FarmCPU    # More accurate, slower
  pca_components: 3
  multiple_analysis: true
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
├── summary_table.csv       # All traits: sample sizes, durations, status
├── significant_snps.csv    # SNPs below p < 5e-8 threshold
└── summary_stats.json      # Overall statistics
```

---

## Performance

### Benchmarks (546 accessions, 1.4M SNPs)

| Configuration | Traits | Time | Notes |
|---------------|--------|------|-------|
| Single job (serial) | 1 trait | ~15 min | BLINK only |
| Parallel (50 jobs) | 184 traits | ~4 hours | BLINK + FarmCPU |
| Parallel (100 jobs) | 184 traits | ~2.5 hours | If cluster allows |

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

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

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

Last updated: 2025-10-22
