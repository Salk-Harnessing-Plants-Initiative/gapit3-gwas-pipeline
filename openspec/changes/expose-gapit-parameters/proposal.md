# Proposal: Expose All GAPIT Parameters

## Why

The current pipeline exposes only a subset of GAPIT's configurable parameters, and uses inconsistent naming conventions that differ from GAPIT's native parameter names. This causes confusion for users familiar with GAPIT who must mentally map `MAF_FILTER` → `SNP.MAF`, `PCA_COMPONENTS` → `PCA.total`. Key parameters like `kinship.algorithm`, `SNP.effect`, `SNP.impute` are hardcoded, limiting functionality. Metadata records our custom names instead of GAPIT's actual parameters, creating reproducibility concerns.

## What Changes

- **BREAKING**: Rename `MODELS` → `MODEL`, `PCA_COMPONENTS` → `PCA_TOTAL`, `MAF_FILTER` → `SNP_MAF`
- Add deprecation warnings for old parameter names
- Fix bug: Change `MAF.Threshold` to `SNP.MAF` in R script (correct GAPIT parameter name)
- Add new parameters: `KINSHIP_ALGORITHM`, `SNP_EFFECT`, `SNP_IMPUTE`, `SNP_P3D`, `CUTOFF`
- Update metadata schema to use GAPIT native parameter names
- Update pipeline summary to show all GAPIT parameters

## Impact

- Affected specs: runtime-configuration, argo-workflow-configuration
- Affected code: entrypoint.sh, run_gwas_single_trait.R, collect_results.R, WorkflowTemplates

---

## Details

### Proposed Solution

Expose ALL relevant GAPIT parameters using **exact GAPIT naming** converted to environment variable format:
- GAPIT parameter `SNP.MAF` → Environment variable `SNP_MAF`
- GAPIT parameter `PCA.total` → Environment variable `PCA_TOTAL`
- GAPIT parameter `kinship.algorithm` → Environment variable `KINSHIP_ALGORITHM`

Use **GAPIT's exact default values** so users get identical behavior to native GAPIT unless they explicitly configure otherwise.

## GAPIT Parameter Analysis

Based on [GAPIT source code](https://github.com/jiabowang/GAPIT/blob/master/R/GAPIT.R) and [documentation](https://zzlab.net/GAPIT/gapit_help_document.pdf):

### Tier 1: Core GWAS Parameters (MUST expose)
| GAPIT Parameter | Default | Description | Env Var |
|-----------------|---------|-------------|---------|
| `model` | `"MLM"` | GWAS model(s) | `MODEL` |
| `PCA.total` | `0` | Principal components for population structure | `PCA_TOTAL` |
| `SNP.MAF` | `0` | Minor allele frequency threshold | `SNP_MAF` |
| `SNP.FDR` | `1` | FDR threshold (1=no filtering) | `SNP_FDR` |
| `Multiple_analysis` | `TRUE` | Run all traits automatically | `MULTIPLE_ANALYSIS` |

### Tier 2: Advanced Analysis Parameters (SHOULD expose)
| GAPIT Parameter | Default | Description | Env Var |
|-----------------|---------|-------------|---------|
| `kinship.algorithm` | `"Zhang"` | Kinship calculation method | `KINSHIP_ALGORITHM` |
| `SNP.effect` | `"Add"` | Genetic model (Add/Dom) | `SNP_EFFECT` |
| `SNP.impute` | `"Middle"` | Missing genotype imputation | `SNP_IMPUTE` |
| `SNP.P3D` | `TRUE` | Use P3D for faster computation | `SNP_P3D` |
| `cutOff` | `0.05` | Significance threshold | `CUTOFF` |

### Tier 3: Kinship/Grouping Parameters (MAY expose)
| GAPIT Parameter | Default | Description | Env Var |
|-----------------|---------|-------------|---------|
| `kinship.cluster` | `"average"` | Clustering method for kinship | `KINSHIP_CLUSTER` |
| `kinship.group` | `"Mean"` | Group kinship method | `KINSHIP_GROUP` |
| `group.from` | `1000000` | Min groups for CMLM | `GROUP_FROM` |
| `group.to` | `1000000` | Max groups for CMLM | `GROUP_TO` |
| `group.by` | `50` | Group increment | `GROUP_BY` |

### Parameters NOT to Expose (Data/Internal)
- `Y`, `G`, `GD`, `GM` - Data inputs (handled by file paths)
- `KI`, `Z`, `CV` - Computed internally or advanced use
- `file.output`, `Geno.View.output`, `PCA.View.output` - Output control
- `testY`, `buspred`, `lmpred` - Genomic prediction (not GWAS)

## Current Bugs to Fix

### Bug 1: Wrong GAPIT parameter name for MAF
**Current code** passes `MAF.Threshold` but GAPIT's parameter is `SNP.MAF`:
```r
# WRONG (current):
gapit_args$MAF.Threshold <- opt$maf

# CORRECT (should be):
gapit_args$SNP.MAF <- opt$`snp-maf`
```

### Bug 2: Pipeline summary missing new parameters
The `generate_configuration_section()` in `collect_results.R` needs to display all GAPIT parameters.

## Breaking Changes

### Naming Changes (with deprecation period)
| Old Name | New Name | Migration |
|----------|----------|-----------|
| `MODELS` | `MODEL` | Accept both, warn on old |
| `PCA_COMPONENTS` | `PCA_TOTAL` | Accept both, warn on old |
| `MAF_FILTER` | `SNP_MAF` | Accept both, warn on old |
| `SNP_FDR` | `SNP_FDR` | No change |
| `MULTIPLE_ANALYSIS` | `MULTIPLE_ANALYSIS` | No change |

### R Script Fix: Use correct GAPIT parameter
| Current (Wrong) | Correct (GAPIT) |
|-----------------|-----------------|
| `MAF.Threshold` | `SNP.MAF` |

### Default Value Changes
| Parameter | Old Default | New Default (GAPIT) | Impact |
|-----------|-------------|---------------------|--------|
| `MODEL` | `BLINK,FarmCPU` | `MLM` | More conservative default |
| `PCA_TOTAL` | `3` | `0` | No PCA by default |
| `SNP_MAF` | `0.05` | `0` | No MAF filtering by default |
| `KINSHIP_ALGORITHM` | `VanRaden` | `Zhang` | GAPIT default algorithm |
| `SNP_THRESHOLD` | `5e-8` | `0.05` | GAPIT cutOff default |

**Decision**: Use GAPIT's exact default values. This ensures users get identical behavior to native GAPIT unless they explicitly configure otherwise. Users familiar with GAPIT won't be surprised, and scientific reproducibility is maintained.

## Scope

### In Scope
- Rename existing parameters to match GAPIT naming
- Add new parameters for Tier 1 and Tier 2
- Update metadata schema to use GAPIT parameter names
- Add validation for all parameters
- Update documentation with parameter reference
- Add deprecation warnings for old names
- Comprehensive test coverage

### Out of Scope
- Tier 3 parameters (can be added later)
- Genomic prediction parameters (separate feature)
- Interactive/visualization parameters

## Success Criteria

1. All Tier 1 and Tier 2 parameters configurable via environment variables
2. Parameter names match GAPIT exactly (with underscore substitution)
3. Validation catches invalid values with clear error messages
4. Metadata records all parameters using consistent naming
5. Documentation provides complete parameter reference
6. Tests verify parameter propagation end-to-end
7. Deprecation warnings guide users to new names

## References

- [GAPIT GitHub Repository](https://github.com/jiabowang/GAPIT)
- [GAPIT User Manual (PDF)](https://zzlab.net/GAPIT/gapit_help_document.pdf)
- [GAPIT Version 3 Paper (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9121400/)
- [Colleague's recommended parameters](https://salkinstitute.box.com/s/0wsr0a4re7otz5a7d5nk12delzz0bn3w)
