## Why

The aggregation script produces incorrect MAF values for BLINK model results and embeds analysis type metadata in trait names rather than as a separate column. This impacts data quality and usability of GWAS results.

### Issues Discovered

1. **BLINK MAF column contains sample counts instead of frequencies**: GAPIT's BLINK model outputs columns in a different order than the CSV header claims. Row data shows `MAF=536` (sample count) instead of proper frequencies like `0.07`.

2. **Analysis type suffix embedded in trait names**: Trait names contain `(NYC)` suffix (e.g., `mean_GR_rootLength_day_1.2(NYC)`) which should be parsed into a separate column for cleaner data organization and filtering.

### Investigation Findings

- **Kansas vs NYC are duplicates**: GAPIT generates both Kansas and NYC result files for BLINK/FarmCPU, but they contain identical data. The Filter file correctly captures only NYC.
- **Column swap is BLINK-specific**: MLM and FarmCPU have correct column order; only BLINK is affected.
- **Filter file is the correct data source**: It contains only significant SNPs and is much faster than reading full GWAS_Results files.

## What Changes

- **FIX**: Detect BLINK model and correct MAF column values during aggregation
- **ADD**: Parse `(NYC)/(Kansas)` suffix from trait names into separate `analysis_type` column
- **ADD**: Document GAPIT output quirks in spec for maintainability
- **MODIFY**: Update spec to reflect actual Filter file columns (remove nobs/effect/H&B.P.Value from expected output)

## Impact

- Affected specs: `results-aggregation`
- Affected code: `scripts/collect_results.R`
- Affected tests: `tests/testthat/test-aggregation.R`
- New fixtures: BLINK column swap test case