# Tasks: Fix Unnecessary GWAS_Results Fallback for Empty Filter Files

## Test-Driven Development Tasks

### Phase 1: Write Failing Tests (TDD Red Phase)

#### 1. Create test fixture for empty Filter file without traits column
- [ ] Create `tests/fixtures/aggregation/trait_empty_no_traits/`
- [ ] Add `GAPIT.Association.Filter_GWAS_results.csv` with header: `SNP,Chr,Pos,P.value,MAF,nobs,Effect,H.B.P.Value`
- [ ] Ensure file has no `traits` column and no data rows
- [ ] Add `metadata.json` for trait
- **Estimated**: 5 minutes

#### 2. Create test fixture for empty Filter file with traits column
- [ ] Create `tests/fixtures/aggregation/trait_empty_with_traits/`
- [ ] Add `GAPIT.Association.Filter_GWAS_results.csv` with header: `SNP,Chr,Pos,P.value,MAF,traits`
- [ ] Ensure file has `traits` column but no data rows
- [ ] Add `metadata.json` for trait
- **Estimated**: 5 minutes

#### 3. Write test for Filter file without traits column
- [ ] Add test case in `tests/testthat/test-aggregation.R`
- [ ] Test name: `"read_filter_file returns empty immediately for Filter without traits column"`
- [ ] Assert: `nrow(result) == 0`
- [ ] Assert: `class(result) == "data.frame"`
- [ ] Assert: Function completes in <0.1 seconds
- [ ] Expect: Test FAILS (currently triggers fallback)
- **Estimated**: 10 minutes

#### 4. Write test for Filter file with traits column but no rows
- [ ] Add test case in `tests/testthat/test-aggregation.R`
- [ ] Test name: `"read_filter_file returns empty for Filter with traits but no data"`
- [ ] Assert: `nrow(result) == 0`
- [ ] Assert: Does NOT call `read_gwas_results_fallback`
- [ ] Expect: Test FAILS initially
- **Estimated**: 10 minutes

#### 5. Write test for completely missing Filter file (fallback case)
- [ ] Add test case ensuring fallback still works
- [ ] Test name: `"read_filter_file falls back when Filter file missing entirely"`
- [ ] Assert: `read_gwas_results_fallback()` IS called
- [ ] Assert: Model column exists in result
- [ ] Expect: Test PASSES (existing behavior)
- **Estimated**: 10 minutes

#### 6. Write performance test for empty traits
- [ ] Add test comparing runtime with/without fallback
- [ ] Test name: `"aggregation completes quickly with many empty traits"`
- [ ] Create 30 empty trait fixtures
- [ ] Assert: Total runtime < 5 seconds for 30 empty traits
- [ ] Expect: Test FAILS (currently takes much longer)
- **Estimated**: 15 minutes

### Phase 2: Implement Fix (TDD Green Phase)

#### 7. Modify read_filter_file() to return empty for missing traits column
- [ ] Open `scripts/collect_results.R`
- [ ] Find check for `"traits" %in% colnames(filter_data)` (around line 76)
- [ ] Replace fallback call with `return(data.frame())`
- [ ] Remove warning message for missing traits column
- [ ] Keep fallback only for completely missing Filter file
- **Estimated**: 10 minutes

#### 8. Run tests to verify fix
- [ ] Run `Rscript tests/testthat/test-aggregation.R`
- [ ] Verify all new tests PASS
- [ ] Verify existing tests still PASS
- [ ] Verify no regressions in other test files
- **Estimated**: 5 minutes

### Phase 3: Refactor (TDD Refactor Phase)

#### 9. Add optional informational logging
- [ ] Optionally add note when skipping empty trait
- [ ] Format: `"  Note: No significant SNPs in trait_003 (skipping)"`
- [ ] Ensure it's informational, not a warning
- [ ] Make it consistent with existing logging style
- **Estimated**: 5 minutes

#### 10. Update inline comments
- [ ] Add comment explaining why we return empty for missing traits column
- [ ] Document the three-way branching logic
- [ ] Reference the spec or design doc
- **Estimated**: 5 minutes

### Phase 4: Integration Testing

#### 11. Test with real GAPIT output data
- [ ] Run aggregation on user's actual 186 traits
- [ ] Verify ~30 empty traits are skipped immediately
- [ ] Verify no "fallback" warnings for empty traits
- [ ] Verify output CSV is identical to before
- [ ] Measure runtime improvement
- **Estimated**: 10 minutes

#### 12. Verify performance improvement
- [ ] Measure aggregation time before fix
- [ ] Measure aggregation time after fix
- [ ] Calculate speedup factor
- [ ] Assert: Speedup > 2× for datasets with many empty traits
- [ ] Document results in commit message
- **Estimated**: 5 minutes

### Phase 5: Documentation

#### 13. Update function docstring
- [ ] Update `read_filter_file()` documentation
- [ ] Document the three-way branching logic
- [ ] Explain when fallback is vs isn't triggered
- [ ] Add parameter descriptions
- **Estimated**: 10 minutes

#### 14. Update CHANGELOG.md
- [ ] Add entry under "Fixed" section
- [ ] Title: "Eliminated unnecessary GWAS_Results fallback for empty Filter files"
- [ ] Describe performance improvement
- [ ] Note: No breaking changes
- **Estimated**: 5 minutes

## Summary

**Total Tasks**: 14
**Estimated Time**: ~2 hours
**Test Coverage**: 6 new tests + 1 performance test
**Breaking Changes**: None

## Dependencies

- Depends on: `fix-aggregation-model-tracking` (provides base Filter file reading)
- Blocks: None (pure optimization)

## Parallelization Opportunities

- Tasks 1-6 (test writing) can be done in parallel with minimal coordination
- Tasks 7-10 (implementation) must be sequential
- Tasks 11-14 (validation/docs) can be done in parallel