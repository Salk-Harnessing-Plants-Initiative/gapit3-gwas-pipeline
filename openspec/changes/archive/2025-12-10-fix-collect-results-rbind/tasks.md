## 1. Write Tests (TDD)

- [x] 1.1 Create test fixture: complete trait directory with Filter file
- [x] 1.2 Create test fixture: incomplete trait directory (GWAS_Results only, no Filter)
- [x] 1.3 Write testthat test: aggregation succeeds with all complete traits
- [x] 1.4 Write testthat test: aggregation fails with error when incomplete trait found (default behavior)
- [x] 1.5 Write testthat test: aggregation succeeds with `--allow-incomplete` flag, skipping incomplete traits
- [x] 1.6 Write testthat test: error message lists all incomplete trait directories

## 2. Remove Fallback Function

- [x] 2.1 Remove `read_gwas_results_fallback()` function entirely
- [x] 2.2 Update `read_filter_file()` to return NULL when Filter file missing

## 3. Add Completeness Check

- [x] 3.1 Add pre-aggregation scan that counts traits missing Filter files
- [x] 3.2 If any traits incomplete and `--allow-incomplete` not set, exit with error code 1
- [x] 3.3 Error message format: `"ERROR: X traits are incomplete (missing Filter file). Run retry-argo-traits.sh --output-dir <path> first, or use --allow-incomplete to skip."`
- [x] 3.4 List each incomplete trait directory in the error output

## 4. Add CLI Flag

- [x] 4.1 Add `--allow-incomplete` flag to optparse options
- [x] 4.2 When flag set, skip incomplete traits with warning instead of failing
- [x] 4.3 Summary output shows: "Aggregated X of Y traits (Z skipped due to missing Filter file)"

## 5. Integration Testing

- [x] 5.1 Test on complete dataset - verify success (unit tests pass)
- [x] 5.2 Test on dataset with incomplete traits - verify fails with clear error (unit tests pass)
- [x] 5.3 Test with `--allow-incomplete` flag - verify skips and succeeds (unit tests pass)

## 6. Cleanup

- [ ] 6.1 Archive this OpenSpec change after deployment
