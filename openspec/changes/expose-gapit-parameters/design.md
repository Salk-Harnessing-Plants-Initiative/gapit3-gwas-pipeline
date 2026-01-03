# Design: Expose All GAPIT Parameters

## Architectural Overview

This change spans multiple system layers:
1. **Entrypoint (bash)** - Environment variable parsing and validation
2. **R Script** - Option parsing and GAPIT() call construction
3. **Metadata** - Parameter recording for reproducibility
4. **Argo/RunAI** - Workflow parameter propagation
5. **Documentation** - User-facing parameter reference

## Parameter Naming Convention

### Transformation Rule
```
GAPIT parameter → Environment variable
SNP.MAF        → SNP_MAF
PCA.total      → PCA_TOTAL
kinship.algorithm → KINSHIP_ALGORITHM
```

**Rule**: Replace `.` with `_`, convert to UPPERCASE.

### R Script Option Naming
```
Environment variable → CLI option → R variable
SNP_MAF             → --snp-maf  → opt$`snp-maf`
PCA_TOTAL           → --pca-total → opt$`pca-total`
KINSHIP_ALGORITHM   → --kinship-algorithm → opt$`kinship-algorithm`
```

**Rule**: Replace `_` with `-`, convert to lowercase for CLI options.

## Parameter Categories and Validation

### Category 1: Numeric Range Parameters
| Parameter | Type | Min | Max | GAPIT Default |
|-----------|------|-----|-----|---------------|
| `PCA_TOTAL` | integer | 0 | 20 | 0 |
| `SNP_MAF` | float | 0.0 | 0.5 | 0 |
| `SNP_FDR` | float | 0.0 | 1.0 | 1 |
| `CUTOFF` | float | 0.0 | 1.0 | 0.05 |
| `SNP_FRACTION` | float | 0.0 | 1.0 | 1 |

### Category 2: Enumerated Parameters
| Parameter | Valid Values | GAPIT Default |
|-----------|--------------|---------------|
| `MODEL` | GLM, MLM, CMLM, MLMM, SUPER, FarmCPU, BLINK | MLM |
| `KINSHIP_ALGORITHM` | VanRaden, Zhang, Loiselle, EMMA | Zhang |
| `SNP_EFFECT` | Add, Dom | Add |
| `SNP_IMPUTE` | Middle, Major, Minor | Middle |
| `KINSHIP_CLUSTER` | average, complete, single, ward | average |
| `KINSHIP_GROUP` | Mean, Max, Min, Median | Mean |

### Category 3: Boolean Parameters
| Parameter | GAPIT Default |
|-----------|---------------|
| `SNP_P3D` | TRUE |
| `MULTIPLE_ANALYSIS` | TRUE |
| `MAJOR_ALLELE_ZERO` | FALSE |

### Category 4: List Parameters
| Parameter | Format | Example |
|-----------|--------|---------|
| `MODEL` | Comma-separated | `BLINK,FarmCPU,MLM` |

## GAPIT Parameter Relationships

### Dependencies
```
MODEL=CMLM → Enables group.from, group.to, group.by
MODEL=SUPER → Enables bin.from, bin.to, bin.by, inclosure.*
kinship.algorithm → Affects kinship matrix calculation
SNP.MAF > 0 → Triggers MAF filtering in QC module
SNP.FDR < 1 → Triggers FDR filtering in output
```

### Conflicts
```
SNP.MAF + pre-filtered data → Redundant filtering (warn)
PCA.total > n_samples → Invalid (error)
```

## Implementation Architecture

### Layer 1: Entrypoint Validation (entrypoint.sh)
```bash
# Parse with defaults matching GAPIT
MODEL="${MODEL:-MLM}"
PCA_TOTAL="${PCA_TOTAL:-0}"
SNP_MAF="${SNP_MAF:-0}"
SNP_FDR="${SNP_FDR:-1}"
KINSHIP_ALGORITHM="${KINSHIP_ALGORITHM:-Zhang}"
SNP_EFFECT="${SNP_EFFECT:-Add}"
SNP_IMPUTE="${SNP_IMPUTE:-Middle}"
SNP_P3D="${SNP_P3D:-TRUE}"

# Validate enumerations
validate_enum "MODEL" "$MODEL" "GLM,MLM,CMLM,MLMM,SUPER,FarmCPU,BLINK"
validate_enum "KINSHIP_ALGORITHM" "$KINSHIP_ALGORITHM" "VanRaden,Zhang,Loiselle,EMMA"
validate_enum "SNP_EFFECT" "$SNP_EFFECT" "Add,Dom"
validate_enum "SNP_IMPUTE" "$SNP_IMPUTE" "Middle,Major,Minor"

# Validate ranges
validate_range "PCA_TOTAL" "$PCA_TOTAL" 0 20
validate_range "SNP_MAF" "$SNP_MAF" 0 0.5
validate_range "SNP_FDR" "$SNP_FDR" 0 1
```

### Layer 2: R Script Option Parsing (run_gwas_single_trait.R)
```r
option_list <- list(
  # Core parameters (Tier 1)
  make_option("--model", type = "character",
              default = Sys.getenv("MODEL", "MLM"),
              help = "GWAS model(s), comma-separated [env: MODEL]"),
  make_option("--pca-total", type = "integer",
              default = as.integer(Sys.getenv("PCA_TOTAL", "0")),
              help = "Principal components [env: PCA_TOTAL]"),
  make_option("--snp-maf", type = "numeric",
              default = as.numeric(Sys.getenv("SNP_MAF", "0")),
              help = "Minor allele frequency threshold [env: SNP_MAF]"),
  make_option("--snp-fdr", type = "numeric",
              default = as.numeric(Sys.getenv("SNP_FDR", "1")),
              help = "FDR threshold [env: SNP_FDR]"),

  # Advanced parameters (Tier 2)
  make_option("--kinship-algorithm", type = "character",
              default = Sys.getenv("KINSHIP_ALGORITHM", "Zhang"),
              help = "Kinship calculation method [env: KINSHIP_ALGORITHM]"),
  make_option("--snp-effect", type = "character",
              default = Sys.getenv("SNP_EFFECT", "Add"),
              help = "Genetic effect model [env: SNP_EFFECT]"),
  make_option("--snp-impute", type = "character",
              default = Sys.getenv("SNP_IMPUTE", "Middle"),
              help = "Missing genotype imputation [env: SNP_IMPUTE]"),
  make_option("--snp-p3d", type = "logical",
              default = as.logical(Sys.getenv("SNP_P3D", "TRUE")),
              help = "Use P3D for faster computation [env: SNP_P3D]"),
  make_option("--cutoff", type = "numeric",
              default = as.numeric(Sys.getenv("CUTOFF", "0.05")),
              help = "Significance threshold [env: CUTOFF]")
)
```

### Layer 3: GAPIT Call Construction
```r
# Build GAPIT arguments dynamically
gapit_args <- list(
  Y = myY,
  G = myG,
  model = models,
  PCA.total = opt$`pca-total`,
  Multiple_analysis = opt$`multiple-analysis`,
  kinship.algorithm = opt$`kinship-algorithm`,
  SNP.effect = opt$`snp-effect`,
  SNP.impute = opt$`snp-impute`,
  SNP.P3D = opt$`snp-p3d`,
  cutOff = opt$cutoff
)

# Conditionally add filtering parameters
if (opt$`snp-maf` > 0) {
  gapit_args$SNP.MAF <- opt$`snp-maf`
}

if (opt$`snp-fdr` < 1) {
  gapit_args$SNP.FDR <- opt$`snp-fdr`
}

# Execute GAPIT
myGAPIT <- do.call(GAPIT, gapit_args)
```

### Layer 4: Metadata Schema (v3.0.0)
```json
{
  "schema_version": "3.0.0",
  "parameters": {
    "gapit": {
      "model": ["BLINK", "FarmCPU", "MLM"],
      "PCA.total": 3,
      "SNP.MAF": 0.0073,
      "SNP.FDR": 0.05,
      "kinship.algorithm": "VanRaden",
      "SNP.effect": "Add",
      "SNP.impute": "Middle",
      "SNP.P3D": true,
      "cutOff": 0.05,
      "Multiple_analysis": true
    },
    "compute": {
      "openblas_threads": 12,
      "omp_threads": 12
    }
  }
}
```

**Key change**: Parameters nested under `parameters.gapit` using exact GAPIT names.

### Layer 5: Deprecation Support
```bash
# entrypoint.sh - Check for deprecated names
if [ -n "$MODELS" ] && [ -z "$MODEL" ]; then
  echo "WARNING: MODELS is deprecated, use MODEL instead" >&2
  MODEL="$MODELS"
fi

if [ -n "$PCA_COMPONENTS" ] && [ -z "$PCA_TOTAL" ]; then
  echo "WARNING: PCA_COMPONENTS is deprecated, use PCA_TOTAL instead" >&2
  PCA_TOTAL="$PCA_COMPONENTS"
fi

if [ -n "$MAF_FILTER" ] && [ -z "$SNP_MAF" ]; then
  echo "WARNING: MAF_FILTER is deprecated, use SNP_MAF instead" >&2
  SNP_MAF="$MAF_FILTER"
fi
```

## Runtime Configuration Display

```
================================================================================
GAPIT Configuration:
================================================================================
  Model(s):              BLINK, FarmCPU, MLM
  PCA Components:        3
  Kinship Algorithm:     VanRaden
  SNP Effect Model:      Add
  SNP Imputation:        Middle
  SNP P3D:               TRUE

  SNP Filtering:
    MAF Threshold:       0.0073 (MAC >= 8 equivalent)
    FDR Threshold:       0.05
    Significance Cutoff: 0.05

  Execution:
    Multiple Analysis:   TRUE
    OpenBLAS Threads:    12
================================================================================
```

## Trade-offs

### Option A: Keep Current Defaults (Recommended)
**Pros**:
- No breaking change for existing users
- Sensible defaults for common use cases
- MAF=0.05 prevents noise from rare variants

**Cons**:
- Differs from GAPIT defaults
- May surprise GAPIT experts

### Option B: Use GAPIT Defaults Exactly
**Pros**:
- Identical behavior to native GAPIT
- No surprises for GAPIT users

**Cons**:
- Breaking change for all existing pipelines
- MAF=0 may include unreliable rare variants
- PCA=0 may not correct for population structure

### Decision: Option A with Clear Documentation
- Keep current sensible defaults
- Document prominently that defaults differ from GAPIT
- Show defaults in help output and configuration display
- Users can set `SNP_MAF=0` etc. to get GAPIT behavior

## File Changes Summary

| File | Changes |
|------|---------|
| `scripts/entrypoint.sh` | Add new params, validation, deprecation |
| `scripts/run_gwas_single_trait.R` | New options, GAPIT args construction |
| `scripts/collect_results.R` | Update metadata extraction |
| `cluster/argo/workflow-templates/*.yaml` | Add new parameters |
| `scripts/submit-all-traits-runai.sh` | Add new parameters |
| `.env.example` | Complete parameter reference |
| `docs/GAPIT_PARAMETERS.md` | New comprehensive docs |
| `tests/testthat/test-gapit-parameters.R` | New test file |
| `tests/integration/test-gapit-params-e2e.sh` | Integration tests |