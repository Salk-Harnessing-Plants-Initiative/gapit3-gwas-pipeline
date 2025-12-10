## Why

The aggregation script's fallback behavior when `Filter_GWAS_results.csv` is missing is fundamentally flawed:

1. **Filter file is the completion signal**: GAPIT only creates `Filter_GWAS_results.csv` at the very end of `GAPIT.Multiple.Manhattan()` after ALL models complete. If this file is missing, the trait did not complete successfully.

2. **Fallback masks incomplete data**: Using GWAS_Results as fallback silently includes partial results, giving users a false sense of completeness.

3. **Technical issue**: The fallback function returns different columns than Filter files, causing `rbind` errors when mixing complete and incomplete traits.

**Root cause**: The original spec incorrectly assumed missing Filter files could be a legitimate state requiring fallback. Investigation of [GAPIT source code](https://github.com/jiabowang/GAPIT/blob/master/R/GAPIT.Multiple.Manhattan.R) shows this is never the case - missing Filter = incomplete trait = needs retry.

## What Changes

### 1. Remove Fallback Behavior (**BREAKING**)
- Remove `read_gwas_results_fallback()` function entirely
- Missing Filter file is now an error condition, not a fallback trigger

### 2. Add Strict Completeness Enforcement
- Aggregation fails by default if ANY trait is missing Filter file
- New `--allow-incomplete` flag to explicitly opt-in to partial aggregation
- Clear error message listing which traits are incomplete

### 3. Improve Error Reporting
- Count and list incomplete traits before failing
- Suggest running retry script to complete missing traits

## Impact

- Affected specs: `results-aggregation`
- Affected code: `scripts/collect_results.R`
  - Remove `read_gwas_results_fallback()` (lines 203-274)
  - Modify `read_filter_file()` to return NULL instead of fallback
  - Add completeness check before aggregation loop
  - Add `--allow-incomplete` CLI flag
- Risk: **Medium** - Breaking change for workflows relying on fallback
- Migration: Run `retry-argo-traits.sh --output-dir` before aggregation to ensure all traits complete
