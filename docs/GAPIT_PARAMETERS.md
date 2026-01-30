# GAPIT Parameter Reference

This document provides a complete reference for all GAPIT parameters exposed by the pipeline.

**All defaults match GAPIT's native defaults** for consistency and scientific reproducibility.

## Parameter Naming Convention

| GAPIT Parameter | Environment Variable | CLI Option |
|-----------------|---------------------|------------|
| `model` | `MODEL` | `--models` |
| `PCA.total` | `PCA_TOTAL` | `--pca` |
| `SNP.MAF` | `SNP_MAF` | `--maf` |
| `SNP.FDR` | `SNP_FDR` | `--snp-fdr` |
| `cutOff` | `SNP_THRESHOLD` | `--cutoff` |
| `kinship.algorithm` | `KINSHIP_ALGORITHM` | `--kinship-algorithm` |
| `SNP.effect` | `SNP_EFFECT` | `--snp-effect` |
| `SNP.impute` | `SNP_IMPUTE` | `--snp-impute` |
| `Multiple_analysis` | `MULTIPLE_ANALYSIS` | `--multiple-analysis` |

**Rule**: GAPIT uses dots (`.`) in parameter names. Environment variables use underscores (`_`) and UPPERCASE.

## Default Values

All defaults match GAPIT's native defaults (verified from [GAPIT source code](https://github.com/jiabowang/GAPIT)):

| Parameter | GAPIT Default | Description |
|-----------|---------------|-------------|
| `MODEL` | `MLM` | Mixed Linear Model |
| `PCA_TOTAL` | `0` | No PCA correction |
| `SNP_MAF` | `0` | No MAF filtering |
| `SNP_FDR` | disabled | No FDR filtering (GAPIT default is 1) |
| `SNP_THRESHOLD` | `0.05` | Significance cutoff |
| `KINSHIP_ALGORITHM` | `Zhang` | Kinship calculation method |
| `SNP_EFFECT` | `Add` | Additive genetic model |
| `SNP_IMPUTE` | `Middle` | Mean imputation for missing genotypes |
| `MULTIPLE_ANALYSIS` | `TRUE` | Run multiple trait analysis |

## Core Parameters (Tier 1)

### MODEL

GWAS model(s) to run.

| Property | Value |
|----------|-------|
| GAPIT parameter | `model` |
| Type | String (comma-separated for multiple) |
| Valid values | `GLM`, `MLM`, `CMLM`, `MLMM`, `SUPER`, `FarmCPU`, `BLINK` |
| Default | `MLM` |

**Examples**:
```bash
# Single model (GAPIT default)
MODEL=MLM

# Fast analysis
MODEL=BLINK

# Multiple models for comparison
MODEL=BLINK,FarmCPU,MLM
```

**Model descriptions**:
- `GLM` - General Linear Model (no kinship correction)
- `MLM` - Mixed Linear Model (standard GWAS with kinship)
- `CMLM` - Compressed MLM (groups similar individuals)
- `MLMM` - Multi-Locus MLM (multiple QTL detection)
- `SUPER` - Settlement of MLM Under Progressively Exclusive Relationship
- `FarmCPU` - Fixed and Random Model Circulating Probability Unification
- `BLINK` - Bayesian-information and Linkage-disequilibrium Iteratively Nested Keyway

### PCA_TOTAL

Number of principal components for population structure correction.

| Property | Value |
|----------|-------|
| GAPIT parameter | `PCA.total` |
| Type | Integer |
| Range | 0-20 |
| Default | `0` (no PCA) |

**Examples**:
```bash
# No PCA correction (GAPIT default)
PCA_TOTAL=0

# Moderate correction for structured populations
PCA_TOTAL=3

# Strong correction for highly structured populations
PCA_TOTAL=10
```

**Recommendations**:
- Use `0` for homogeneous populations
- Use `3-5` for moderately structured populations
- Use `5-10` for highly structured populations

### SNP_MAF

Minor allele frequency threshold for filtering rare variants.

| Property | Value |
|----------|-------|
| GAPIT parameter | `SNP.MAF` |
| Type | Float |
| Range | 0.0-0.5 |
| Default | `0` (no filtering) |

**Examples**:
```bash
# No MAF filtering (GAPIT default)
SNP_MAF=0

# Standard filtering (5% MAF)
SNP_MAF=0.05

# Rare variant analysis
SNP_MAF=0.01
```

**Recommendations**:
- Use `0` to include all variants
- Use `0.05` to focus on common variants (recommended for most analyses)
- Use `0.01` for rare variant studies

### SNP_FDR

False Discovery Rate threshold for multiple testing correction.

| Property | Value |
|----------|-------|
| GAPIT parameter | `SNP.FDR` |
| Type | Float |
| Range | 0.0-1.0 (empty = disabled) |
| Default | disabled (GAPIT default is 1) |

**Examples**:
```bash
# Disabled (GAPIT default)
# SNP_FDR=   (leave empty or unset)

# 5% FDR (recommended for publication)
SNP_FDR=0.05

# 10% FDR (more permissive)
SNP_FDR=0.1
```

### SNP_THRESHOLD

P-value significance threshold (GAPIT's `cutOff` parameter).

| Property | Value |
|----------|-------|
| GAPIT parameter | `cutOff` |
| Type | Float |
| Range | 0.0-1.0 |
| Default | `0.05` |

**Examples**:
```bash
# GAPIT default
SNP_THRESHOLD=0.05

# Genome-wide significance (Bonferroni)
SNP_THRESHOLD=5e-8

# Suggestive significance
SNP_THRESHOLD=1e-5
```

## Advanced Parameters (Tier 2)

### KINSHIP_ALGORITHM

Method for calculating the kinship matrix.

| Property | Value |
|----------|-------|
| GAPIT parameter | `kinship.algorithm` |
| Type | String |
| Valid values | `VanRaden`, `Zhang`, `Loiselle`, `EMMA` |
| Default | `Zhang` |

**Algorithms**:
- `VanRaden` - VanRaden (2008) method, centered and scaled
- `Zhang` - Zhang et al. (2010) method (GAPIT default)
- `Loiselle` - Loiselle et al. (1995) coancestry method
- `EMMA` - Efficient Mixed-Model Association method

### SNP_EFFECT

Genetic effect model for SNP associations.

| Property | Value |
|----------|-------|
| GAPIT parameter | `SNP.effect` |
| Type | String |
| Valid values | `Add`, `Dom` |
| Default | `Add` |

**Models**:
- `Add` - Additive model (most common)
- `Dom` - Dominant model

### SNP_IMPUTE

Method for imputing missing genotypes.

| Property | Value |
|----------|-------|
| GAPIT parameter | `SNP.impute` |
| Type | String |
| Valid values | `Middle`, `Major`, `Minor` |
| Default | `Middle` |

**Methods**:
- `Middle` - Replace with mean (average) value
- `Major` - Replace with major allele
- `Minor` - Replace with minor allele

## Example Configurations

### Fast Preliminary Analysis

```bash
MODEL=BLINK
PCA_TOTAL=0
SNP_MAF=0.05
SNP_THRESHOLD=1e-5
```

### Publication-Ready Analysis

```bash
MODEL=BLINK,FarmCPU,MLM
PCA_TOTAL=3
SNP_MAF=0.05
SNP_FDR=0.05
KINSHIP_ALGORITHM=Zhang
```

### Rare Variant Analysis

```bash
MODEL=MLM
PCA_TOTAL=5
SNP_MAF=0.01
SNP_THRESHOLD=1e-6
```

### Using GAPIT Defaults (No Filtering)

```bash
MODEL=MLM
PCA_TOTAL=0
SNP_MAF=0
# SNP_FDR not set (disabled)
SNP_THRESHOLD=0.05
KINSHIP_ALGORITHM=Zhang
SNP_EFFECT=Add
SNP_IMPUTE=Middle
```

## Deprecated Parameters

The following parameter names are deprecated but still supported with warnings:

| Deprecated Name | New Name | Status |
|-----------------|----------|--------|
| `MODELS` | `MODEL` | Shows warning |
| `PCA_COMPONENTS` | `PCA_TOTAL` | Shows warning |
| `MAF_FILTER` | `SNP_MAF` | Shows warning |
| `KINSHIP_METHOD` | `KINSHIP_ALGORITHM` | Shows warning |

**Migration**: Update your `.env` files and scripts to use the new parameter names.

## References

- [GAPIT GitHub Repository](https://github.com/jiabowang/GAPIT)
- [GAPIT User Manual (PDF)](https://zzlab.net/GAPIT/gapit_help_document.pdf)
- [GAPIT Version 3 Paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC9121400/)
