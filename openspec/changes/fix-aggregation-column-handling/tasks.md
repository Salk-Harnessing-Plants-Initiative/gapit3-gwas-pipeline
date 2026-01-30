## 1. Test Fixtures (TDD Setup)

- [x] 1.1 Create `tests/fixtures/aggregation/trait_blink_maf_swap/` with Filter file containing BLINK row with MAF=536
- [x] 1.2 Create `tests/fixtures/aggregation/trait_mixed_models/` with BLINK (invalid MAF) and MLM (valid MAF) rows
- [x] 1.3 Create `tests/fixtures/aggregation/trait_kansas_suffix/` with Kansas analysis type suffix
- [x] 1.4 Create `tests/fixtures/aggregation/trait_no_suffix/` with trait name without NYC/Kansas suffix

## 2. Unit Tests (TDD Red Phase)

- [x] 2.1 Add test: `read_filter_file` detects BLINK MAF > 1 and sets to NA
- [x] 2.2 Add test: `read_filter_file` retains valid MAF for MLM/FarmCPU models
- [x] 2.3 Add test: `read_filter_file` extracts `analysis_type=NYC` from trait suffix
- [x] 2.4 Add test: `read_filter_file` extracts `analysis_type=Kansas` from trait suffix
- [x] 2.5 Add test: `read_filter_file` sets `analysis_type=standard` when no suffix
- [x] 2.6 Add test: aggregated output includes `analysis_type` and `trait_dir` columns
- [ ] 2.7 Add test: summary_stats.json includes `data_quality.blink_maf_corrections` count (deferred - not critical)

## 3. Implementation (TDD Green Phase)

- [x] 3.1 Update `read_filter_file()` to detect BLINK MAF > 1 and set to NA with warning
- [x] 3.2 Update `read_filter_file()` to parse analysis_type from trait suffix
- [x] 3.3 Update `read_filter_file()` to strip suffix from trait name
- [x] 3.4 Update aggregation output to include `analysis_type` column
- [ ] 3.5 Update summary_stats.json generation to include `data_quality` section (deferred)
- [ ] 3.6 Verify all new tests pass (requires CI)

## 4. Documentation

- [x] 4.1 Add "GAPIT Output Quirks" section to `openspec/specs/results-aggregation/spec.md`
- [x] 4.2 Update `docs/METADATA_SCHEMA.md` if summary_stats.json schema changed (not needed - no schema change)
- [ ] 4.3 Update CHANGELOG.md with fix description

## 5. Validation

- [ ] 5.1 Run `Rscript tests/testthat.R` - all tests pass (requires CI)
- [ ] 5.2 Run aggregation on existing iron deficiency outputs to verify fix
- [ ] 5.3 Verify aggregated CSV has correct MAF values (0 < MAF <= 0.5 or NA)
- [ ] 5.4 Verify `analysis_type` column is populated correctly
- [x] 5.5 Run `openspec validate fix-aggregation-column-handling --strict`