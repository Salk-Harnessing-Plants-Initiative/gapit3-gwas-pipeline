# Usage Guide

Runtime configuration for the GAPIT3 GWAS pipeline.

## Quick Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TRAIT_INDEX` | (required) | Phenotype column to analyze (2 = first trait) |
| `MODELS` | `BLINK,FarmCPU` | GWAS models: BLINK, FarmCPU, MLM, MLMM |
| `PCA_COMPONENTS` | `3` | Principal components for population structure (0-20) |
| `SNP_THRESHOLD` | `5e-8` | P-value significance threshold |
| `MAF_FILTER` | `0.05` | Minor allele frequency filter |
| `SNP_FDR` | (disabled) | FDR threshold for multiple testing correction |

**Full documentation:** See [`.env.example`](../.env.example) for all parameters with detailed descriptions.

## Common Configurations

### Fast Preliminary Scan
```bash
MODELS=BLINK
PCA_COMPONENTS=0
SNP_THRESHOLD=1e-5
```

### Publication-Ready Analysis
```bash
MODELS=BLINK,FarmCPU,MLM
PCA_COMPONENTS=5
SNP_FDR=0.05
```

### Rare Variant Analysis
```bash
MAF_FILTER=0.01
SNP_THRESHOLD=1e-6
```

## Setting Parameters

**Local Docker:**
```bash
cp .env.example .env
# Edit .env with your values
docker run --env-file .env gapit3:latest
```

**RunAI:**
```bash
runai submit job-name \
  --environment TRAIT_INDEX=2 \
  --environment MODELS=BLINK
```

**Argo Workflows:**
```yaml
env:
  - name: MODELS
    value: "BLINK,FarmCPU"
```

## Priority Order

1. Command-line arguments (highest)
2. Environment variables
3. Defaults in entrypoint.sh (lowest)

---

See [ARGO_SETUP.md](ARGO_SETUP.md) for cluster deployment or [DATA_REQUIREMENTS.md](DATA_REQUIREMENTS.md) for input formats.
