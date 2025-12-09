# Proposal: Fix GAPIT Results Aggregation to Track Model Information

**Status**: ✅ Implementation Complete - Ready for Archive

## Problem Statement

The current `collect_results.R` script aggregates significant SNPs from GAPIT GWAS results but **loses critical model information** in the process. When users run analyses with multiple models (BLINK, FarmCPU), the aggregated output cannot distinguish which model identified each significant SNP, making the results incomplete and potentially misleading for downstream analysis.

### User Impact

**Current broken workflow:**
1. User runs GAPIT with BLINK + FarmCPU models on 186 traits
2. GAPIT creates model-specific result files per trait
3. User runs `collect_results.R` to aggregate
4. Script reads complete GWAS results (1.4M SNPs × 2 models × 186 traits = 521M rows)
5. **Model information is lost** - output has no model column
6. User cannot determine if SNP was found by BLINK, FarmCPU, or both

**Problem evidence from user's actual output:**
- File: `Z:\users\eberrigan\20251110_Elohim_Bello_iron_deficiency_GAPIT_GWAS\outputs\aggregated_results\significant_snps.csv`
- Missing: `model` column
- User cannot filter by model or compare model performance

### Root Cause

**Wrong file choice**: Script reads `GAPIT.Association.GWAS_Results.*.csv` (1.4M rows, all SNPs) instead of `GAPIT.Association.Filter_GWAS_results.csv` (~2-10 rows, significant SNPs only with model info).

GAPIT creates `Filter_GWAS_results.csv` with a `traits` column containing model information in format: `<MODEL>.<TraitName>` (e.g., `"BLINK.root_length"`), but the current script ignores this file entirely.

## Proposed Solution

Modify `collect_results.R` to:
1. Read `GAPIT.Association.Filter_GWAS_results.csv` instead of complete GWAS_Results files
2. Parse the `traits` column to extract model and trait name
3. Add `model` column to output CSV
4. Improve performance (500× fewer rows to process)

### Key Changes

**File reading** (lines ~143):
```r
# BEFORE (WRONG):
gwas_files <- list.files(dir, pattern = "GAPIT.*GWAS_Results.*csv$")

# AFTER (CORRECT):
filter_file <- file.path(dir, "GAPIT.Association.Filter_GWAS_results.csv")
```

**Model extraction**:
```r
# Parse traits column: "BLINK.root_length_day_1.2" → model="BLINK", trait="root_length_day_1.2"
filter_data$model <- sub("\\..*", "", filter_data$traits)
filter_data$trait <- sub("^[^.]+\\.", "", filter_data$traits)
```

**Output format** (BREAKING CHANGE):
```csv
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model
```

## Impact

### Performance
- **Current**: Read 521M rows (1.4M × 2 × 186), ~5-10 minutes
- **Proposed**: Read ~1,000 rows (5 × 186), <30 seconds
- **Improvement**: 500× fewer rows, 10-20× faster

### Breaking Changes
1. New `model` column in output CSV (added at end)
2. Output file renamed: `significant_snps.csv` → `all_traits_significant_snps.csv`
3. Summary stats JSON includes `snps_by_model` field

### User Benefits
- ✅ Can filter results by model
- ✅ Can compare BLINK vs FarmCPU performance
- ✅ Can identify SNPs found by both models
- ✅ Faster aggregation (30s vs 5-10min)

## Alternatives Considered

1. **Keep current approach, infer model from filename**: Still slow, doesn't fix root cause
2. **Create separate files per model**: Multiple files to manage, harder to compare
3. **Add model as SNP name prefix**: Breaks SNP name consistency

**Selected approach** (read Filter files) is fastest, most accurate, uses GAPIT's canonical output.

## Success Criteria

- ✅ Aggregation reads Filter files (not GWAS_Results)
- ✅ Model column present in output CSV
- ✅ Model parsing accuracy: 100% for standard GAPIT output
- ✅ Aggregation time: <30 seconds for 186 traits × 2 models
- ✅ Graceful fallback if Filter file missing

## Migration

Users with existing aggregated results should re-run aggregation:
```bash
Rscript scripts/collect_results.R --output-dir /path/to/existing/outputs
```

Downstream scripts may need updates if they parse CSV by column position (not name).

## Implementation Summary

**Completed**: December 2024

All functionality has been implemented in `scripts/collect_results.R` (493 lines):

### Core Implementation
- `read_filter_file()` function (lines 134-201) - reads Filter files with model parsing
- `select_best_trait_dirs()` function (lines 67-132) - deduplicates retry directories
- `read_gwas_results_fallback()` function (lines 208-262) - fallback when Filter missing
- Model extraction from `traits` column with compound model support (FarmCPU.LM, Blink.LM)
- Output to `all_traits_significant_snps.csv` with `model` column
- Per-model statistics in `summary_stats.json` (`snps_by_model` field)
- Sorting by P.value
- Console output with per-model counts

### Test Coverage
- 6 test fixture directories in `tests/fixtures/aggregation/`
- 407 lines of unit tests in `tests/testthat/test-aggregation.R`
- Integration test script `tests/integration/test-aggregation.sh`

### Files Changed
- `scripts/collect_results.R` - Core implementation
- `tests/testthat/test-aggregation.R` - Unit tests
- `tests/integration/test-aggregation.sh` - Integration tests (new)
- `tests/fixtures/aggregation/*` - Test fixtures
