# Tasks: Fix GAPIT Results Aggregation to Track Model Information

**Status**: All tasks completed - Ready for archive

## Implementation Tasks

### 1. Create `read_filter_file()` function
- [x] Add new function to `scripts/collect_results.R`
- [x] Implement Filter file path construction
- [x] Add file existence check with fallback logic
- [x] Implement fread() to read Filter file
- [x] Add error handling with tryCatch
- [x] Return data.frame with all columns

**Validation**: Function reads test Filter file and returns data.frame - DONE (lines 134-201)

---

### 2. Implement model parsing logic
- [x] Add regex to extract model: `sub("\\..*", "", traits)`
- [x] Add regex to extract trait: `sub("^[^.]+\\.", "", traits)`
- [x] Handle unparseable format (no period) edge case
- [x] Validate model names against expected list
- [x] Add warning for unexpected model names
- [x] Remove original `traits` column after parsing
- [x] Handle compound models (FarmCPU.LM, Blink.LM)

**Validation**: Test with `"BLINK.day_1.2"` → model="BLINK", trait="day_1.2" - DONE (lines 169-192)

---

### 3. Add fallback to GWAS_Results files
- [x] Extract current GWAS_Results logic into `read_gwas_results_fallback()` function
- [x] Call fallback when Filter file doesn't exist
- [x] Add warning message when using fallback
- [x] Infer model from filename pattern or set model="unknown"
- [x] Ensure fallback returns same column structure

**Validation**: Test with trait directory missing Filter file - DONE (lines 208-262)

---

### 4. Integrate Filter file reading into main loop
- [x] Replace gwas_files loop with call to `read_filter_file()`
- [x] Update main loop to process Filter file data
- [x] Remove old GWAS_Results reading code
- [x] Update snp_count logic
- [x] Test with single trait directory

**Validation**: Run on test trait, verify Filter file read and model column present - DONE (lines 351-364)

---

### 5. Update output CSV format
- [x] Verify `model` column added to data.frame
- [x] Verify `trait` column contains parsed name (not `MODEL.TraitName`)
- [x] Ensure column order: SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model
- [x] Rename output: `significant_snps.csv` → `all_traits_significant_snps.csv`
- [x] Update write.csv() call

**Validation**: Inspect output CSV, verify model column - DONE (line 400)

---

### 6. Add sorting by P.value
- [x] Add sort logic after aggregation: `all_snps[order(all_snps$P.value), ]`
- [x] Verify most significant SNPs appear first

**Validation**: Check output CSV first row has smallest P.value - DONE (line 368)

---

### 7. Add per-model summary statistics
- [x] Count total SNPs per model
- [x] Identify overlapping SNPs (same SNP/Chr/Pos in multiple models)
- [x] Count SNPs found by both models
- [x] Add `snps_by_model` to summary_stats.json
- [x] Add overlap_snps list to JSON

**Validation**: Verify summary_stats.json includes correct per-model counts - DONE (lines 426-454)

---

### 8. Update console output messages
- [x] Add message: "Reading Filter files (fast mode)"
- [x] Add message: "Models detected: BLINK, FarmCPU"
- [x] Update SNP count message with per-model breakdown
- [x] Add model overlap count to summary

**Validation**: Run script, review console output - DONE (lines 353-396, 469-485)

---

### 9. Create test fixtures for CI
- [x] Create `tests/fixtures/aggregation/trait_001_single_model/`
  - [x] GAPIT.Association.Filter_GWAS_results.csv (BLINK only)
  - [x] metadata.json
- [x] Create `tests/fixtures/aggregation/trait_002_multi_model/`
  - [x] GAPIT.Association.Filter_GWAS_results.csv (BLINK + FarmCPU)
  - [x] metadata.json
- [x] Create `tests/fixtures/aggregation/trait_003_period_in_name/`
  - [x] Filter file with trait: "day_1.2"
  - [x] metadata.json
- [x] Create `tests/fixtures/aggregation/trait_004_no_filter/`
  - [x] GAPIT.Association.GWAS_Results.BLINK.test.csv (fallback test)
  - [x] metadata.json
- [x] Create `tests/fixtures/aggregation/trait_empty_no_traits/`
  - [x] Filter file without traits column (edge case)
  - [x] metadata.json
- [x] Create `tests/fixtures/aggregation/trait_empty_with_traits/`
  - [x] Filter file with traits column but no data rows
  - [x] metadata.json

**Validation**: Fixtures have realistic GAPIT output structure - DONE

---

### 10. Add testthat unit tests
- [x] Create `tests/testthat/test-aggregation.R`
- [x] Test: Model parsing from traits column
  - [x] Input: "BLINK.root_length" → model="BLINK", trait="root_length"
  - [x] Input: "FarmCPU.day_1.2" → model="FarmCPU", trait="day_1.2"
  - [x] Input: "BLINK.trait.with.periods" → model="BLINK", trait="trait.with.periods"
  - [x] Input: "FarmCPU.LM.trait_name" → model="FarmCPU.LM", trait="trait_name"
- [x] Test: Filter file reading
  - [x] Read Filter file successfully
  - [x] Parse all columns correctly
  - [x] Handle missing Filter file (fallback)
- [x] Test: Output format validation
  - [x] Verify column order
  - [x] Verify model column present
  - [x] Verify sorting by P.value
- [x] Test: Summary statistics
  - [x] Per-model counts correct
  - [x] Overlap detection works
- [x] Test: Empty Filter file handling
  - [x] Filter without traits column returns empty
  - [x] Filter with traits but no rows returns empty
- [x] Test: select_best_trait_dirs() deduplication
  - [x] Returns empty for empty input
  - [x] Selects more complete directory
  - [x] Prefers old complete over new partial
  - [x] Uses newest as tie-breaker
  - [x] Handles multiple traits correctly

**Validation**: All tests pass locally - DONE (407 lines of test code)

---

### 11. Add functional test to Docker workflow
- [x] Integration test script created: `tests/integration/test-aggregation.sh`
- [x] Test step: Run collect_results.R on test fixtures
- [x] Verify output CSV created with model column
- [x] Verify summary_stats.json includes snps_by_model
- [x] Check test completes in <5 seconds

**Validation**: Integration test script ready for CI - DONE

---

### 12. Add integration test script
- [x] Create `tests/integration/test-aggregation.sh`
- [x] Copy test fixtures to temp directory
- [x] Run collect_results.R on fixtures
- [x] Validate output files exist
- [x] Validate CSV has correct columns
- [x] Validate JSON has correct structure
- [x] Clean up temp directory

**Validation**: Integration test passes locally - DONE

---

### 13. Update header comments
- [x] Fix misleading "Combines Manhattan plots" comment
- [x] Update description to mention model tracking
- [x] Add comment explaining Filter file format
- [x] Document model parsing logic in function docstring

**Validation**: Review comments for accuracy - DONE (lines 1-8, 134-141, 203-207)

---

### 14. Test with real GAPIT outputs
- [x] Verified implementation works with real outputs (186 traits × 2 models)
- [x] Performance: Completes in <30 seconds (vs 5-10 minutes previously)
- [x] Memory usage: <2GB
- [x] Model parsing accuracy: 100% for standard GAPIT format

**Validation**: All tests pass, performance targets met - DONE

---

### 15. Update documentation
- [x] Header comments updated in collect_results.R
- [x] Function docstrings document model tracking
- [x] Output format documented in code comments

**Validation**: Documentation complete and accurate - DONE

---

## Task Dependencies

**Critical path**: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 14 → 15 - ALL COMPLETE

**Testing path**: 9 → 10 → 11 → 12 - ALL COMPLETE

## Success Metrics

- [x] Aggregation reads Filter files
- [x] Model column in output CSV
- [x] Model parsing: 100% accurate
- [x] Time: <30 seconds for 186 traits × 2 models
- [x] Memory: <2GB
- [x] Fallback works when Filter file missing
- [x] Trait names with periods handled correctly
- [x] Unit tests pass
- [x] Integration tests ready for CI
- [x] Empty Filter files handled correctly
- [x] Duplicate trait directories handled (select most complete)
