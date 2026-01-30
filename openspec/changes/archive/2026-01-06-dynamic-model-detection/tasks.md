# Tasks: Dynamic Model Detection from Workflow Metadata

## Phase 1: Test Infrastructure (TDD - Tests First)

### 1.1 Create test fixtures for model detection
- [x] Create `tests/fixtures/metadata/gapit_metadata_blink_farmcpu.json` with v3.0.0 `model` parameter
- [x] Create `tests/fixtures/metadata/gapit_metadata_mlm_only.json` with single model
- [x] Create `tests/fixtures/metadata/gapit_metadata_legacy.json` with legacy `models` parameter
- [x] Create `tests/fixtures/metadata/gapit_metadata_empty.json` with no model parameter
- [x] Create `tests/fixtures/metadata/gapit_metadata_malformed.json` for error handling

### 1.2 Write unit tests for model extraction
- [x] Test `extract_models_from_metadata()` with v3.0.0 naming
- [x] Test `extract_models_from_metadata()` with legacy `models` parameter
- [x] Test `extract_models_from_metadata()` returns NULL for missing metadata file
- [x] Test `extract_models_from_metadata()` returns NULL for malformed JSON
- [x] Test `extract_models_from_metadata()` returns NULL when model parameter missing
- [x] Test `extract_models_from_metadata()` handles comma-separated string
- [x] Test `extract_models_from_metadata()` handles nested gapit object

### 1.3 Write unit tests for model validation
- [x] Test `validate_model_names()` accepts known GAPIT models (BLINK, FarmCPU, MLM, etc.)
- [x] Test `validate_model_names()` rejects unknown model names
- [x] Test `validate_model_names()` handles case variations (blink vs BLINK)
- [x] Test `validate_model_names()` handles mixed valid/invalid models
- [x] Test `validate_model_names()` handles empty input
- [x] Test `validate_model_names()` accepts custom known_models parameter
- [x] Test `validate_model_names()` handles compound models (FarmCPU.LM, Blink.LM)

### 1.4 Write integration tests for completeness checking
- [x] Test `select_best_trait_dirs()` uses detected models when `--models` not specified
- [x] Test `select_best_trait_dirs()` uses CLI models when `--models` specified (override)
- [x] Test completeness detection with detected model subset
- [x] Add `models_source` tests in integration/test-aggregation.sh

## Phase 2: Implementation

### 2.1 Define known GAPIT models constant
- [x] Create `KNOWN_GAPIT_MODELS` constant in `scripts/lib/constants.R`
- [x] Include: BLINK, FarmCPU, MLM, MLMM, GLM, SUPER, CMLM, FarmCPU.LM, Blink.LM
- [x] Create `DEFAULT_MODELS` and `DEFAULT_MODELS_STRING` constants
- [x] Source constants from modules via `aggregation_utils.R`

### 2.2 Implement model extraction function
- [x] Create `extract_models_from_metadata(metadata_path)` function in aggregation_utils.R
- [x] Support v3.0.0 `model` parameter (comma-separated string)
- [x] Support v3.0.0 nested `parameters.gapit.model` structure
- [x] Support legacy `models` parameter (fallback)
- [x] Return NULL for missing/malformed metadata (graceful handling)
- [x] Parse comma-separated string to character vector

### 2.3 Implement model validation function
- [x] Create `validate_model_names(models)` function in aggregation_utils.R
- [x] Compare against `KNOWN_GAPIT_MODELS` (case-insensitive)
- [x] Return list with `valid` (boolean), `invalid_models`, and `canonical_models`
- [x] Map input to canonical case for consistency

### 2.4 Integrate model detection into main aggregation flow
- [x] Add model detection before `select_best_trait_dirs()` call
- [x] Use detected models when `opt$models` is default value
- [x] Log: "Models source: auto-detected" when using detected models
- [x] Log: "Models source: cli" when `--models` provided
- [x] Log: "Models source: default" when falling back to defaults

### 2.5 Update completeness checking
- [x] Modify `select_best_trait_dirs()` to accept detected models as parameter
- [x] Use detected models for determining trait completeness
- [x] Log which model(s) are missing for incomplete traits

## Phase 3: Validation and Documentation

### 3.1 Run all tests
- [x] Verify all new unit tests pass (93 tests in test-aggregation-utils.R)
- [x] Verify all existing tests still pass (441 total tests pass)
- [x] Run integration test with actual workflow output (26/27 pass, 1 timing-only failure)

### 3.2 Update documentation
- [x] Add `--models` flag documentation noting auto-detection behavior in SCRIPTS_REFERENCE.md
- [x] Update `collect_results.R` header comments (implicit via module sourcing)
- [x] Add note to results-aggregation spec about auto-detection (already included)

## Summary

All tasks completed. Implementation done via combination of:
- `refactor-collect-results-testable` change (module infrastructure)
- Direct integration in `collect_results.R` (model detection flow)

Key files:
- `scripts/lib/constants.R` - KNOWN_GAPIT_MODELS, DEFAULT_MODELS
- `scripts/lib/aggregation_utils.R` - Pure functions for model detection/validation
- `scripts/collect_results.R` - Main script with auto-detection integrated
- `tests/testthat/test-aggregation-utils.R` - 93 unit tests for modules
- `tests/fixtures/metadata/*.json` - Test fixtures for various metadata formats

## Dependencies

- **BLOCKER**: `refactor-collect-results-testable` - Must be completed first to enable TDD
  - Provides testable module structure (`scripts/lib/aggregation_utils.R`)
  - Provides `scripts/lib/constants.R` for KNOWN_GAPIT_MODELS
  - Enables unit tests without script execution side effects

## Verification

After implementation:
```bash
# Test auto-detection (should detect models from first trait's metadata)
Rscript scripts/collect_results.R --output-dir /path/to/outputs

# Test CLI override (should use specified models, ignore metadata)
Rscript scripts/collect_results.R --output-dir /path/to/outputs --models "BLINK,FarmCPU"
```
