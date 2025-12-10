# Fix collect_results.R rbind Column Mismatch Error

## Problem Analysis

### Root Cause
The `collect_results.R` script fails with `Error in rbind: numbers of columns of arguments do not match` when aggregating SNP results across traits.

### How It Occurs
1. The script has two code paths for reading significant SNPs:
   - **Primary**: `read_filter_file()` - reads `GAPIT.Association.Filter_GWAS_results.csv`
   - **Fallback**: `read_gwas_results_fallback()` - reads full `GAPIT.Association.GWAS_Results.<MODEL>.<trait>.csv` files

2. **Column structure differences:**
   - **Filter file** (6 columns + 2 added): `[row_index], SNP, Chr, Pos, P.value, MAF, traits` → processed to have `model`, `trait`
   - **GWAS_Results file** (8 columns + 2 added): `SNP, Chr, Pos, P.value, MAF, nobs, effect, H&B.P.Value` + `model`, `trait`

3. When `rbind()` is called on dataframes with different column counts, R throws this error.

### Affected Traits
4 traits missing Filter files (partial/incomplete runs):
- trait_173 (only BLINK completed - no FarmCPU, no MLM, no Filter, no metadata.json)
- trait_180, trait_184, trait_186 (similar situation)

These traits only have BLINK model results but no combined Filter file (which is created at the end of all models running).

## Solution Options

### Option A: Use bind_rows() instead of rbind() (Quick Fix)
Replace `rbind()` with `dplyr::bind_rows()` which gracefully handles different column sets by filling missing columns with NA.

**Pros:** Simple one-line fix, handles column mismatches gracefully
**Cons:** Results will have extra columns (nobs, effect, H&B.P.Value) with NA for most rows

### Option B: Normalize columns in fallback function (Better Fix)
Modify `read_gwas_results_fallback()` to return only the same columns as `read_filter_file()`: SNP, Chr, Pos, P.value, MAF, model, trait.

**Pros:** Clean, consistent output; no extra columns with NAs
**Cons:** Loses effect size and H&B.P.Value data from fallback traits

### Option C: Skip fallback entirely, warn about incomplete traits (Conservative)
When Filter file is missing, return empty dataframe and log which traits were skipped.

**Pros:** Only processes complete traits; avoids data quality issues
**Cons:** Loses data from partially complete traits

## Recommended Solution: Option B

Normalize columns in the fallback function to match the Filter file structure. This is the cleanest approach because:

1. The fallback is meant to be equivalent to reading the Filter file, just slower
2. The extra columns (nobs, effect, H&B.P.Value) aren't used downstream
3. Data consistency is maintained across all traits

## Implementation

### Change 1: Modify read_gwas_results_fallback() (lines 208-262)
Select only the columns that match Filter file format before returning:
- Keep: SNP, Chr, Pos, P.value, MAF, model, trait
- Drop: nobs, effect, H&B.P.Value

### Change 2: Also fix the internal rbind in fallback (line 253)
The fallback function itself uses `rbind(all_snps, sig_snps)` internally, which could also fail if different GWAS files have different columns.

## Files to Modify
- `scripts/collect_results.R`: Lines 229-262 (read_gwas_results_fallback function)

## Testing
1. Run aggregation on current dataset with 4 incomplete traits
2. Verify summary_table.csv and all_traits_significant_snps.csv are created
3. Verify no rbind errors
