# Tasks: Refactor collect_results.R for Testability

## Phase 1: Create Module Infrastructure

### 1.1 Create lib directory and constants module
- [x] Create `scripts/lib/` directory
- [x] Create `scripts/lib/constants.R` with KNOWN_GAPIT_MODELS
- [x] Add DEFAULT_MODELS and DEFAULT_MODELS_STRING constants
- [x] Add header documentation with update instructions

### 1.2 Create aggregation_utils module
- [x] Create `scripts/lib/aggregation_utils.R`
- [x] Add module header with function documentation
- [x] Source constants.R from within module

## Phase 2: Extract Functions (TDD)

### 2.1 Write unit tests first (TDD)
- [x] Create `tests/testthat/test-aggregation-utils.R`
- [x] Write tests for `extract_models_from_metadata()`
- [x] Write tests for `validate_model_names()`
- [x] Write tests for `detect_models_from_first_trait()`
- [x] Write tests for `get_gapit_param()`
- [x] Write tests for `select_best_trait_dirs()`
- [x] Verify tests pass (implemented alongside tests)

### 2.2 Extract extract_models_from_metadata()
- [x] Move function to aggregation_utils.R
- [x] Ensure pure function (no global state)
- [x] Add parameter documentation
- [x] Run tests - should pass

### 2.3 Extract validate_model_names()
- [x] Move function to aggregation_utils.R
- [x] Add `known_models` parameter with default
- [x] Ensure pure function
- [x] Run tests - should pass

### 2.4 Extract detect_models_from_first_trait()
- [x] Move function to aggregation_utils.R
- [x] Ensure pure function
- [x] Run tests - should pass

### 2.5 Extract get_gapit_param()
- [x] Move function to aggregation_utils.R
- [x] Ensure pure function
- [x] Run tests - should pass

### 2.6 Extract select_best_trait_dirs()
- [x] Move function to aggregation_utils.R
- [x] Ensure pure function (pass expected_models as param)
- [x] Run tests - should pass

### 2.7 Extract formatting helpers (added during implementation)
- [x] Extract format_pvalue() to aggregation_utils.R
- [x] Extract format_number() to aggregation_utils.R
- [x] Extract format_duration() to aggregation_utils.R
- [x] Extract truncate_string() to aggregation_utils.R
- [x] Extract generate_configuration_section() to aggregation_utils.R

## Phase 3: Update Main Script

### 3.1 Modify collect_results.R to use modules
- [x] Add module sourcing at top of script
- [ ] Remove duplicate function definitions (use module functions)
- [x] Use KNOWN_GAPIT_MODELS from constants in validation
- [x] Use DEFAULT_MODELS_STRING for CLI default
- [ ] Verify script still runs correctly after removing duplicates

### 3.2 Add configuration to metadata output
- [x] Add `configuration` section to summary_stats.json
- [x] Include expected_models, models_source, threshold
- [x] Include allow_incomplete flag
- [x] Add model auto-detection from first trait metadata

## Phase 4: Validation

### 4.1 Run all tests
- [x] Run new unit tests for extracted functions (93 tests pass)
- [x] Run existing aggregation tests (all pass)
- [x] Verify no regressions (all 300+ tests pass)

### 4.2 Integration testing
- [x] Update test-aggregation.R to source modules directly
- [x] Update test-gapit-parameters.R to source modules directly
- [x] Update test-pipeline-summary.R to source modules directly
- [x] Verify tests match GAPIT v3.0.0 naming conventions
- [x] Add configuration section tests to tests/integration/test-aggregation.sh
- [x] Add integration tests to CI workflow (.github/workflows/test-r-scripts.yml)

### 4.3 Verify dynamic-model-detection unblocked
- [x] Modules can be sourced independently without script execution
- [x] All functions available for import by other tests

## Phase 5: Documentation

### 5.1 Update code documentation
- [x] Add module documentation headers
- [x] Document function parameters and return values
- [x] Add examples in comments

### 5.2 Update project documentation
- [ ] Note module structure in relevant docs (optional, not blocking)
- [ ] Update SCRIPTS_REFERENCE.md if exists (optional)

## Dependencies

- None (foundational refactor)

## Unblocks

- `dynamic-model-detection` proposal (test infrastructure)
- Future TDD features for aggregation

## Verification

After implementation:
```bash
# Unit tests pass
docker run --rm --entrypoint="" -v "$PWD:/tests" -w /tests gapit3-test:latest \
  Rscript -e "library(testthat); test_file('tests/testthat/test-aggregation-utils.R')"

# All tests pass
docker run --rm --entrypoint="" -v "$PWD:/tests" -w /tests gapit3-test:latest \
  Rscript -e "library(testthat); test_dir('tests/testthat')"

# CLI unchanged (example)
docker run --rm --entrypoint="" -v "$PWD:/tests" -w /tests gapit3-test:latest \
  Rscript scripts/collect_results.R --help
```

## Summary of Changes

### New Files
- `scripts/lib/constants.R` - Authoritative constants for GAPIT models
- `scripts/lib/aggregation_utils.R` - Reusable pure functions
- `tests/testthat/test-aggregation-utils.R` - Unit tests for modules (93 tests)

### Modified Files
- `scripts/collect_results.R` - Sources modules, uses constants, adds configuration tracking
- `tests/testthat/test-aggregation.R` - Sources modules directly
- `tests/testthat/test-gapit-parameters.R` - Sources modules directly
- `tests/testthat/test-pipeline-summary.R` - Sources modules directly
- `tests/integration/test-aggregation.sh` - Added configuration section tests
- `.github/workflows/test-r-scripts.yml` - Added integration tests to CI

### Key Features
- All tests source modules directly (no script execution during testing)
- Model auto-detection from first trait's metadata
- Configuration section in summary_stats.json tracks models_source
- Case-insensitive model validation with canonical case output
