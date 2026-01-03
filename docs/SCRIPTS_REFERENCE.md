# Scripts Reference

Comprehensive documentation for all R scripts and the container entrypoint in the GAPIT3 GWAS Pipeline.

> **Single Source of Truth**: This document describes script behavior. For parameter defaults, see [.env.example](../.env.example).

---

## Table of Contents

1. [Overview](#overview)
2. [GWAS Models](#gwas-models)
3. [Scripts](#scripts)
   - [run_gwas_single_trait.R](#run_gwas_single_traitr)
   - [collect_results.R](#collect_resultsr)
   - [validate_inputs.R](#validate_inputsr)
   - [extract_trait_names.R](#extract_trait_namesr)
   - [entrypoint.sh](#entrypointsh)
4. [Duplicate Handling](#duplicate-handling)
5. [Parameter Interactions](#parameter-interactions)
6. [Troubleshooting](#troubleshooting)
7. [GAPIT3 Documentation](#gapit3-documentation)

---

## Overview

The pipeline consists of five main scripts:

| Script | Purpose | Invocation |
|--------|---------|------------|
| `run_gwas_single_trait.R` | Core GWAS execution for one trait | Container default command |
| `collect_results.R` | Aggregate results from all traits | After parallel execution |
| `validate_inputs.R` | Pre-flight validation | Before GWAS execution |
| `extract_trait_names.R` | Generate trait manifest | Workflow orchestration |
| `entrypoint.sh` | Container router and env setup | Container entrypoint |

---

## GWAS Models

This pipeline uses [GAPIT3](https://github.com/jiabowang/GAPIT) for GWAS analysis. For detailed algorithm descriptions, see the [GAPIT User Manual (PDF)](https://zzlab.net/GAPIT/gapit_help_document.pdf).

### Model Selection Guide

| Model | Speed | Power | Memory | Best For |
|-------|-------|-------|--------|----------|
| **BLINK** | Fastest | Highest | Low | Default choice, large datasets |
| **FarmCPU** | Fast | High | Medium | Reducing false positives |
| **MLM** | Slow | Medium | High | Traditional analysis, validation |
| **MLMM** | Slow | High | High | Multiple QTL detection |
| **SUPER** | Medium | Medium | Medium | Settlement of MLM |
| **CMLM** | Medium | Medium | Medium | Compressed MLM |

### Model Descriptions

- **BLINK** (Bayesian-information and Linkage-disequilibrium Iteratively Nested Keyway): Multi-locus method with highest statistical power and computing efficiency. Recommended default.

- **FarmCPU** (Fixed and random model Circulating Probability Unification): Iterative method that controls false positives well. Good balance of speed and accuracy.

- **MLM** (Mixed Linear Model): Traditional single-locus approach. More conservative, useful for validation.

> **Note**: For detailed algorithm explanations, see [Wang & Zhang (2021)](https://doi.org/10.1016/j.gpb.2021.08.005) and the [GAPIT documentation](https://zzlab.net/GAPIT/).

### Combining Models

Running multiple models provides cross-validation:
```bash
MODELS=BLINK,FarmCPU,MLM  # SNPs found by multiple models have higher confidence
```

The aggregation script tracks which model found each SNP, enabling comparison.

---

## Scripts

### run_gwas_single_trait.R

**Purpose**: Execute GWAS analysis for a single trait using GAPIT3.

**Location**: `scripts/run_gwas_single_trait.R`

#### Parameters

| Parameter | Env Var | CLI Flag | Type | Default | Description |
|-----------|---------|----------|------|---------|-------------|
| Trait Index | `TRAIT_INDEX` | `--trait-index` | Integer | 2 | Phenotype column to analyze (2 = first trait after Taxa) |
| Models | `MODELS` | `--models` | String | `BLINK,FarmCPU` | Comma-separated GAPIT models |
| PCA Components | `PCA_COMPONENTS` | `--pca` | Integer | 3 | Principal components for population structure (0-20) |
| MAF Filter | `MAF_FILTER` | `--maf` | Float | 0.05 | Minor allele frequency threshold |
| SNP FDR | `SNP_FDR` | `--snp-fdr` | Float | (disabled) | FDR threshold for multiple testing correction |
| Multiple Analysis | `MULTIPLE_ANALYSIS` | `--multiple-analysis` | Boolean | TRUE | Run all models in single GAPIT call |
| Genotype File | `GENOTYPE_FILE` | `--genotype` | Path | `/data/genotype/...` | HapMap format genotype file |
| Phenotype File | `PHENOTYPE_FILE` | `--phenotype` | Path | `/data/phenotype/...` | Tab-delimited phenotype file |
| Output Dir | `OUTPUT_PATH` | `--output-dir` | Path | `/outputs` | Output directory |
| Threads | `OPENBLAS_NUM_THREADS` | `--threads` | Integer | 12 | CPU threads for linear algebra |

#### Output Files

For each trait, the script produces:

```
outputs/trait_NNN_TRAITNAME_YYYYMMDD_HHMMSS/
├── GAPIT.*.Manhattan.Plot.*.png     # Manhattan plot per model
├── GAPIT.*.QQ.Plot.*.png            # QQ plot per model
├── GAPIT.Association.GWAS_Results.*.csv  # All SNPs with p-values
├── GAPIT.Association.Filter_*.csv   # Significant SNPs only (per model)
└── metadata.json                    # Execution provenance (v2.0.0 schema)
```

#### Example Usage

```bash
# Via environment variables (recommended)
TRAIT_INDEX=5 MODELS=BLINK,FarmCPU Rscript scripts/run_gwas_single_trait.R

# Via CLI arguments
Rscript scripts/run_gwas_single_trait.R \
  --trait-index 5 \
  --models BLINK,FarmCPU \
  --pca 3 \
  --maf 0.05
```

---

### collect_results.R

**Purpose**: Aggregate results from all trait analyses into summary reports.

**Location**: `scripts/collect_results.R`

#### Parameters

| Parameter | CLI Flag | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| Output Dir | `--output-dir` | Path | `/outputs` | Directory containing trait results |
| Batch ID | `--batch-id` | String | `unknown` | Workflow ID for tracking |
| Threshold | `--threshold` | Float | 5e-8 | Genome-wide significance threshold |
| Models | `--models` | String | `BLINK,FarmCPU,MLM` | Expected models for completeness check |
| Allow Incomplete | `--allow-incomplete` | Flag | FALSE | Continue if some traits failed |
| No Markdown | `--no-markdown` | Flag | FALSE | Skip markdown summary generation |
| Markdown Only | `--markdown-only` | Flag | FALSE | Regenerate markdown from existing data |

#### Output Files

```
outputs/aggregated_results/
├── summary_table.csv              # Per-trait statistics
├── all_traits_significant_snps.csv  # Combined significant SNPs with model column
├── summary_stats.json             # Per-model statistics and overlaps
├── pipeline_summary.md            # Human-readable report
└── aggregation_metadata.json      # Aggregation provenance
```

#### Key Features

- **Model Tracking**: Each SNP row includes `model` column showing which GAPIT model found it
- **Deduplication**: SNPs found by multiple models appear as separate rows for comparison
- **Provenance**: Links results back to source trait directories via `trait_dir` column

#### Example Usage

```bash
# Full aggregation
Rscript scripts/collect_results.R \
  --output-dir /outputs \
  --batch-id gapit3-gwas-abc123 \
  --threshold 5e-8

# Regenerate markdown only
Rscript scripts/collect_results.R \
  --output-dir /outputs \
  --markdown-only
```

---

### validate_inputs.R

**Purpose**: Pre-flight validation of input files and configuration.

**Location**: `scripts/validate_inputs.R`

#### Checks Performed

1. **File Existence**: Genotype and phenotype files exist
2. **HapMap Format**: Genotype file has correct structure (11 metadata columns + samples)
3. **Taxa Column**: Phenotype file has required "Taxa" column
4. **Model Validity**: MODELS parameter contains valid GAPIT models
5. **PCA Range**: PCA_COMPONENTS is between 0 and 20
6. **Sample Size**: Minimum 50 samples required for GWAS

#### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Validation passed |
| 1 | Validation failed (see output for details) |

#### Example Usage

```bash
# Validation uses environment variables
GENOTYPE_FILE=/data/genotype/snps.hmp.txt \
PHENOTYPE_FILE=/data/phenotype/traits.txt \
MODELS=BLINK,FarmCPU \
Rscript scripts/validate_inputs.R
```

---

### extract_trait_names.R

**Purpose**: Parse phenotype file and generate trait manifest for parallel processing.

**Location**: `scripts/extract_trait_names.R`

#### Parameters

| Position | Description | Default |
|----------|-------------|---------|
| 1 | Phenotype file path | `/data/phenotype/iron_traits_edited.txt` |
| 2 | Output manifest path | `/config/traits_manifest.yaml` |

#### Output Format

```yaml
metadata:
  source_file: traits.txt
  extraction_date: 2025-01-01 12:00:00
  total_traits: 184
  total_accessions: 546
traits:
  - index: 2
    name: trait_name_1
    column_position: 2
    n_samples: 520
    missing_rate: 0.0476
  # ... more traits
```

#### Example Usage

```bash
Rscript scripts/extract_trait_names.R /data/phenotype/traits.txt /config/manifest.yaml
```

---

### entrypoint.sh

**Purpose**: Container entrypoint that routes commands and sets up environment.

**Location**: `scripts/entrypoint.sh`

#### Commands

| Command | Description |
|---------|-------------|
| `run-single-trait` | Execute GWAS for one trait (default) |
| `validate` | Run input validation |
| `extract-traits` | Generate trait manifest |
| `collect-results` | Aggregate results |
| `bash` / `sh` | Interactive shell |

#### Environment Detection

The entrypoint detects execution environment:
- **Argo Workflows**: Detected via `ARGO_WORKFLOW_NAME` or `/var/run/argo`
- **RunAI**: Detected via `RUNAI_JOB_NAME`

#### Environment Variables

See [.env.example](../.env.example) for the complete list of environment variables.

Key variables:
- `TRAIT_INDEX` - Which trait to analyze
- `MODELS` - GWAS models to run
- `DATA_PATH` - Input data directory
- `OUTPUT_PATH` - Output directory

---

## Duplicate Handling

The pipeline automatically handles duplicate entries at two levels:

### Phenotype Duplicates (run_gwas_single_trait.R)

When loading the phenotype file, the script removes duplicate Taxa entries:

```r
pheno_unique <- pheno_data[!duplicated(pheno_data$Taxa), ]
```

**Behavior**:
- Duplicate Taxa rows are detected using R's `duplicated()` function
- Only the **first occurrence** of each Taxa is kept
- Subsequent duplicates are silently removed
- The script logs the count before and after deduplication

**Example output**:
```
Loading phenotype data: /data/phenotype/traits.txt
  - Loaded 550 rows, 185 columns
  - After removing duplicates: 546 accessions
```

> **Note**: If your phenotype file has intentional duplicates (e.g., replicate measurements), you should pre-process the data to average or otherwise combine measurements for each Taxa before running the pipeline.

### Result Directory Duplicates (collect_results.R)

When aggregating results, the script handles duplicate trait directories that may occur from retries:

**Behavior**:
- Multiple directories for the same trait index can exist (e.g., from workflow retries)
- The `select_best_trait_dirs()` function selects one directory per trait
- Selection criteria (in order):
  1. **Most complete models**: Directory with more completed model outputs wins
  2. **Latest timestamp**: If tied, the newest directory (by timestamp in name) wins

**Example output**:
```
  Note: Found multiple directories for 3 trait(s)
  Selecting most complete directory for each:
    Trait 5: Using trait_5_Iron_20251201_143000 (3 models) over trait_5_Iron_20251201_120000 (1 model)
```

### Genotype Handling

The pipeline does **not** deduplicate genotype data. Genotype files should:
- Have unique SNP identifiers (column 1 in HapMap format)
- Have unique sample columns (columns 12+ in HapMap format)
- Be pre-processed to remove any duplicate markers if needed

If your genotype file contains duplicate SNP IDs, GAPIT3 may produce unexpected results. Validate your genotype file before running the pipeline.

---

## Parameter Interactions

### Model and Memory

| Models | Approximate Memory |
|--------|-------------------|
| BLINK only | ~20-25 GB |
| BLINK + FarmCPU | ~25-30 GB |
| BLINK + FarmCPU + MLM | ~30-40 GB |

### PCA and Runtime

More PCA components increase runtime but may improve population structure correction:
- `PCA_COMPONENTS=0`: No correction (fastest)
- `PCA_COMPONENTS=3`: Default, good for most datasets
- `PCA_COMPONENTS=5-10`: For highly structured populations

### SNP_FDR and Results

- **Disabled** (default): Uses fixed threshold (`SNP_THRESHOLD=5e-8`)
- **Enabled** (e.g., `SNP_FDR=0.05`): Applies Benjamini-Hochberg correction per trait

---

## Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `OOMKilled` | Insufficient memory | Increase memory to 64GB or use fewer models |
| `Taxa column not found` | Phenotype file format | Ensure first column is named "Taxa" exactly |
| `Invalid model` | Typo in MODELS | Use: BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM |
| `No significant SNPs` | Threshold too strict | Try `SNP_FDR=0.05` or lower `SNP_THRESHOLD` |
| `Genotype file too large` | Memory during load | Check genotype file size, may need more RAM |

### Exit Codes

| Script | Code | Meaning |
|--------|------|---------|
| All | 0 | Success |
| All | 1 | General error |
| validate_inputs.R | 1 | Validation failed |
| entrypoint.sh | 2 | Configuration error |
| Argo | 64 | RBAC permissions error |

### Debug Mode

Enable verbose logging:
```bash
# R scripts
Rscript --verbose scripts/run_gwas_single_trait.R

# Check environment
docker run --rm gapit3:latest env | grep -E 'TRAIT|MODEL|PATH'
```

---

## GAPIT3 Documentation

### Official Resources

- **User Manual**: [https://zzlab.net/GAPIT/gapit_help_document.pdf](https://zzlab.net/GAPIT/gapit_help_document.pdf)
- **GitHub Repository**: [https://github.com/jiabowang/GAPIT](https://github.com/jiabowang/GAPIT)
- **Website**: [https://zzlab.net/GAPIT/](https://zzlab.net/GAPIT/)

### Citation

If you use this pipeline, please cite GAPIT3:

> Wang, J., & Zhang, Z. (2021). GAPIT Version 3: Boosting Power and Accuracy for Genomic Association and Prediction. *Genomics, Proteomics & Bioinformatics*, 19(4), 629-640. [https://doi.org/10.1016/j.gpb.2021.08.005](https://doi.org/10.1016/j.gpb.2021.08.005)

### Advanced GAPIT Parameters

This pipeline exposes commonly-used GAPIT parameters. For advanced options (e.g., custom kinship matrices, specific bin sizes for FarmCPU), refer to the GAPIT documentation and modify `scripts/run_gwas_single_trait.R` directly.

**Exposed parameters** (configurable via environment):
- `model` (MODELS)
- `PCA.total` (PCA_COMPONENTS)
- `MAF` (MAF_FILTER)
- `cutOff` (SNP_THRESHOLD)
- `FDR.threshold` (SNP_FDR)

**Not exposed** (require script modification):
- `KI` (custom kinship matrix)
- `CV` (custom covariates)
- `bin.size`, `bin.selection` (FarmCPU-specific)
- `sangession.output`, `file.output` (output control)

---

## Related Documentation

- [.env.example](../.env.example) - Parameter defaults (authoritative source)
- [DATA_REQUIREMENTS.md](DATA_REQUIREMENTS.md) - Input/output file formats
- [WORKFLOW_ARCHITECTURE.md](WORKFLOW_ARCHITECTURE.md) - Argo Workflows technical details
- [USAGE.md](USAGE.md) - Quick configuration recipes

---

*Last updated: 2025-01-03*