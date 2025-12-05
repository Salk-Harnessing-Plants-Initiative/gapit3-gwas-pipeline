# Tasks: Fix GAPIT Results Aggregation to Track Model Information

## Implementation Tasks

### 1. Create `read_filter_file()` function
- [ ] Add new function to `scripts/collect_results.R`
- [ ] Implement Filter file path construction
- [ ] Add file existence check with fallback logic
- [ ] Implement fread() to read Filter file
- [ ] Add error handling with tryCatch
- [ ] Return data.frame with all columns

**Validation**: Function reads test Filter file and returns data.frame

---

### 2. Implement model parsing logic
- [ ] Add regex to extract model: `sub("\\..*", "", traits)`
- [ ] Add regex to extract trait: `sub("^[^.]+\\.", "", traits)`
- [ ] Handle unparseable format (no period) edge case
- [ ] Validate model names against expected list
- [ ] Add warning for unexpected model names
- [ ] Remove original `traits` column after parsing

**Validation**: Test with `"BLINK.day_1.2"` → model="BLINK", trait="day_1.2"

---

### 3. Add fallback to GWAS_Results files
- [ ] Extract current GWAS_Results logic into `read_gwas_results_fallback()` function
- [ ] Call fallback when Filter file doesn't exist
- [ ] Add warning message when using fallback
- [ ] Infer model from filename pattern or set model="unknown"
- [ ] Ensure fallback returns same column structure

**Validation**: Test with trait directory missing Filter file

---

### 4. Integrate Filter file reading into main loop
- [ ] Replace gwas_files loop (lines ~142-173) with call to `read_filter_file()`
- [ ] Update main loop to process Filter file data
- [ ] Remove old GWAS_Results reading code
- [ ] Update snp_count logic
- [ ] Test with single trait directory

**Validation**: Run on test trait, verify Filter file read and model column present

---

### 5. Update output CSV format
- [ ] Verify `model` column added to data.frame
- [ ] Verify `trait` column contains parsed name (not `MODEL.TraitName`)
- [ ] Ensure column order: SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model
- [ ] Rename output: `significant_snps.csv` → `all_traits_significant_snps.csv`
- [ ] Update write.csv() call

**Validation**: Inspect output CSV, verify model column

---

### 6. Add sorting by P.value
- [ ] Add sort logic after aggregation: `all_snps[order(all_snps$P.value), ]`
- [ ] Verify most significant SNPs appear first

**Validation**: Check output CSV first row has smallest P.value

---

### 7. Add per-model summary statistics
- [ ] Count total SNPs per model
- [ ] Identify overlapping SNPs (same SNP/Chr/Pos in multiple models)
- [ ] Count SNPs found by both models
- [ ] Add `snps_by_model` to summary_stats.json
- [ ] Add overlap_snps list to JSON

**Validation**: Verify summary_stats.json includes correct per-model counts

---

### 8. Update console output messages
- [ ] Add message: "Reading Filter files (fast mode)"
- [ ] Add message: "Models detected: BLINK, FarmCPU"
- [ ] Update SNP count message with per-model breakdown
- [ ] Add model overlap count to summary

**Validation**: Run script, review console output

---

### 9. Create test fixtures for CI
- [ ] Create `tests/fixtures/aggregation/trait_001_single_model/`
  - [ ] GAPIT.Association.Filter_GWAS_results.csv (BLINK only)
  - [ ] metadata.json
- [ ] Create `tests/fixtures/aggregation/trait_002_multi_model/`
  - [ ] GAPIT.Association.Filter_GWAS_results.csv (BLINK + FarmCPU)
  - [ ] metadata.json
- [ ] Create `tests/fixtures/aggregation/trait_003_no_filter/`
  - [ ] GAPIT.Association.GWAS_Results.BLINK.test.csv (fallback test, small subset)
  - [ ] metadata.json
- [ ] Create `tests/fixtures/aggregation/trait_004_period_in_name/`
  - [ ] Filter file with trait: "day_1.2"
  - [ ] metadata.json

**Validation**: Fixtures have realistic GAPIT output structure

---

### 10. Add testthat unit tests
- [ ] Create `tests/testthat/test-collect-results.R`
- [ ] Test: Model parsing from traits column
  - [ ] Input: "BLINK.root_length" → model="BLINK", trait="root_length"
  - [ ] Input: "FarmCPU.day_1.2" → model="FarmCPU", trait="day_1.2"
  - [ ] Input: "BLINK.trait.with.periods" → model="BLINK", trait="trait.with.periods"
- [ ] Test: Filter file reading
  - [ ] Read Filter file successfully
  - [ ] Parse all columns correctly
  - [ ] Handle missing Filter file (fallback)
- [ ] Test: Output format validation
  - [ ] Verify column order
  - [ ] Verify model column present
  - [ ] Verify sorting by P.value
- [ ] Test: Summary statistics
  - [ ] Per-model counts correct
  - [ ] Overlap detection works
- [ ] Run tests locally: `Rscript tests/testthat.R`

**Validation**: All tests pass locally

---

### 11. Add functional test to Docker workflow
- [ ] Update `.github/workflows/docker-build.yml`
- [ ] Add test step: Run collect_results.R on test fixtures
- [ ] Verify output CSV created with model column
- [ ] Verify summary_stats.json includes snps_by_model
- [ ] Check test completes in <5 seconds

**Validation**: CI test passes

---

### 12. Add integration test script
- [ ] Create `tests/integration/test-aggregation.sh`
- [ ] Copy test fixtures to temp directory
- [ ] Run collect_results.R on fixtures
- [ ] Validate output files exist
- [ ] Validate CSV has correct columns
- [ ] Validate JSON has correct structure
- [ ] Clean up temp directory

**Validation**: Integration test passes locally and in CI

---

### 13. Update header comments
- [ ] Fix misleading "Combines Manhattan plots" comment (line 6)
- [ ] Update description to mention model tracking
- [ ] Add comment explaining Filter file format
- [ ] Document model parsing logic in function docstring

**Validation**: Review comments for accuracy

---

### 14. Test with real GAPIT outputs
- [ ] Run on actual output directory (186 traits × 2 models)
- [ ] Verify completion in <30 seconds
- [ ] Verify memory usage <2GB
- [ ] Spot-check model parsing accuracy (10 traits)
- [ ] Verify summary statistics accuracy
- [ ] Compare to old output format

**Validation**: All tests pass, performance targets met

---

### 15. Update documentation
- [ ] Update README with new output format
- [ ] Document `model` column
- [ ] Add example of filtering by model
- [ ] Update performance notes
- [ ] Add troubleshooting for missing Filter files
- [ ] Document new test fixtures and CI tests

**Validation**: Documentation complete and accurate

---

## Task Dependencies

**Critical path**: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 14 → 15

**Testing path**: 9 → 10 → 11 → 12

**Can parallelize**:
- Task 13 (comments) can start anytime
- Tasks 9-12 (testing) can develop while Tasks 1-8 are in progress
- Task 9 (fixtures) should start early to enable Task 10 (unit tests)

**Estimated time**: ~6 hours total
- Core implementation (Tasks 1-8): 2.5 hours
- Test fixtures and unit tests (Tasks 9-10): 1.5 hours
- CI integration and testing (Tasks 11-12): 1 hour
- Real data testing and docs (Tasks 14-15): 1 hour

## Success Metrics

- ✅ Aggregation reads Filter files
- ✅ Model column in output CSV
- ✅ Model parsing: 100% accurate
- ✅ Time: <30 seconds for 186 traits × 2 models
- ✅ Memory: <2GB
- ✅ Fallback works when Filter file missing
- ✅ Trait names with periods handled correctly
- ✅ Unit tests pass in CI
- ✅ Functional tests pass in Docker build
- ✅ Integration tests pass locally and in CI
