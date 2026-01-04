# Tasks: Expose All GAPIT Parameters

**Approach: Test-Driven Development (TDD)**
- Write tests FIRST for each feature
- Run tests to confirm they fail
- Implement the feature
- Run tests to confirm they pass

## Phase 1: Test Infrastructure & Fixtures

### 1.1 Create Test Fixtures for Schema v3.0.0
- [x] Create `tests/fixtures/gapit_params/v3_full/metadata.json` with all GAPIT params
- [x] Create `tests/fixtures/gapit_params/v3_minimal/metadata.json` with minimal params
- [x] Create `tests/fixtures/gapit_params/v2_legacy/metadata.json` for backward compat

### 1.2 Create Unit Test File
- [x] Create `tests/testthat/test-gapit-parameters.R`
- [x] Add tests for `get_gapit_param()` helper function
- [x] Add tests for schema v3.0.0 reading
- [x] Add tests for backward compatibility with v2.0.0
- [ ] **BLOCKED**: Tests cannot run because `collect_results.R` executes on source (needs main guard refactor)

### 1.3 Create Integration Test File
- [x] Create `tests/integration/test-gapit-params-e2e.sh`
- [x] Add tests for new env var names (MODEL, PCA_TOTAL, SNP_MAF)
- [x] Add tests for deprecated name warnings
- [x] Add tests for new parameters (KINSHIP_ALGORITHM, etc.)
- [x] All 12 integration tests PASSING

## Phase 2: Fix MAF Parameter Bug (TDD)

### 2.1 Write Tests for MAF Fix
- [x] Add test: GAPIT receives `SNP.MAF` not `MAF.Threshold`
- [x] Add test: Metadata records `SNP.MAF` in gapit section
- [x] Run tests - should FAIL

### 2.2 Implement MAF Fix
- [x] Change `gapit_args$MAF.Threshold` to `gapit_args$SNP.MAF` in run_gwas_single_trait.R
- [x] Run tests - should PASS

## Phase 3: Update Metadata Schema (TDD)

### 3.1 Write Tests for Schema v3.0.0
- [x] Add test: metadata has `schema_version: "3.0.0"`
- [x] Add test: parameters nested under `parameters.gapit`
- [x] Add test: GAPIT params use native names (model, PCA.total, SNP.MAF, SNP.FDR)
- [x] Run tests - should FAIL

### 3.2 Implement Schema v3.0.0
- [x] Update metadata structure in run_gwas_single_trait.R
- [x] Keep legacy fields for backward compatibility
- [x] Run tests - should PASS

## Phase 4: Update Pipeline Summary (TDD)

### 4.1 Write Tests for New Summary Format
- [x] Add test: summary reads from `parameters.gapit.*`
- [x] Add test: summary falls back to legacy `parameters.*`
- [x] Add test: summary displays grouped sections (GAPIT Parameters, Filtering, Data)
- [x] Add test: summary shows GAPIT native param names
- [ ] **BLOCKED**: R unit tests cannot run (see Phase 1.2)

### 4.2 Implement Summary Updates
- [x] Add `get_gapit_param()` helper to collect_results.R
- [x] Update `generate_configuration_section()` with grouped format
- [ ] **BLOCKED**: R unit tests cannot run (see Phase 1.2)

## Phase 5: Add Deprecation Warnings (TDD)

### 5.1 Write Tests for Deprecation
- [x] Add integration test: MODELS triggers warning, sets MODEL
- [x] Add integration test: PCA_COMPONENTS triggers warning, sets PCA_TOTAL
- [x] Add integration test: MAF_FILTER triggers warning, sets SNP_MAF
- [x] Add integration test: new name takes precedence over deprecated
- [x] All deprecation tests PASSING

### 5.2 Implement Deprecation Handling
- [x] Add `handle_deprecated_params()` function to entrypoint.sh
- [x] Call function before validation
- [x] Call function in help command so warnings show there too
- [x] Run tests - should PASS

## Phase 6: Add New GAPIT Parameters (TDD)

### 6.1 Write Tests for New Parameters
- [x] Add test: KINSHIP_ALGORITHM env var accepted (VanRaden, Zhang, Loiselle, EMMA)
- [x] Add test: SNP_EFFECT env var accepted (Add, Dom)
- [x] Add test: SNP_IMPUTE env var accepted (Middle, Major, Minor)
- [x] Add test: Invalid values rejected with clear error message
- [x] All new parameter tests PASSING

### 6.2 Implement New Parameters in entrypoint.sh
- [x] Add new env var declarations with defaults
- [x] Add validation functions for each parameter
- [x] Update `log_config()` to display new parameters
- [x] Run tests - should PASS

### 6.3 Implement New Parameters in R Script
- [x] Add new CLI options to run_gwas_single_trait.R (KINSHIP_ALGORITHM, SNP_EFFECT, SNP_IMPUTE)
- [x] Pass new parameters to GAPIT
- [x] Record in metadata
- [x] Run tests - should PASS (12/12 integration tests)

### 6.4 Fix cutOff Parameter Bug (TDD)
- [x] Add test: SNP_THRESHOLD is displayed in config
- [x] Add CLI option --cutoff to run_gwas_single_trait.R
- [x] Pass cutOff to GAPIT call
- [x] Update documentation
- [ ] Run tests - should PASS (14/14 integration tests)

## Phase 7: Update Argo/RunAI Templates

### 7.1 Update WorkflowTemplates
- [x] Add new parameters to gapit3-gwas-single-trait template (all v3.0.0 params)
- [x] Add new parameters to gapit3-gwas-single-trait-highmem template
- [x] Map to environment variables
- [ ] Test workflow submission (requires cluster access)

### 7.2 Update RunAI Scripts
- [x] Update submit-all-traits-runai.sh with new parameter names
- [x] Support both legacy and v3.0.0 parameter names
- [x] Load new parameters from .env

## Phase 8: Documentation

### 8.1 Create GAPIT_PARAMETERS.md
- [ ] Document all exposed parameters with GAPIT native naming
- [ ] Show GAPIT defaults vs pipeline defaults
- [ ] Provide usage examples

### 8.2 Update .env.example
- [x] Update parameter names: MODELS→MODEL, PCA_COMPONENTS→PCA_TOTAL, MAF_FILTER→SNP_MAF
- [x] Add new parameters (KINSHIP_ALGORITHM, SNP_EFFECT, SNP_IMPUTE)
- [x] Include valid options for enums
- [x] Show default values and document deprecation

### 8.3 Update README.md
- [ ] Add section on GAPIT parameter configuration
- [ ] Document deprecation warnings and migration

## Phase 9: Final Validation

### 9.1 Run Full Test Suite
- [x] All integration tests pass (12/12)
- [ ] All R unit tests pass (BLOCKED - see Phase 1.2)
- [ ] CI pipeline passes

### 9.2 Manual Validation
- [ ] Test with real GWAS data
- [ ] Verify metadata completeness
- [ ] Check pipeline summary output

## Known Blockers

### R Unit Test Infrastructure (Phase 1.2)
The R unit tests for `get_gapit_param()` and `generate_configuration_section()` cannot run because:
- `collect_results.R` executes on source (no main guard)
- Functions are defined AFTER script execution starts
- Script exits with "No trait results found" before functions are defined

**Required fix**: Refactor `collect_results.R` to add main execution guard so functions can be sourced for testing without triggering script execution. This should be done as a separate change proposal to avoid breaking existing functionality.

## File Change Summary

| File | Phase | Changes |
|------|-------|---------|
| `tests/fixtures/gapit_params/` | 1.1 | New test fixtures for v3.0.0 schema |
| `tests/testthat/test-gapit-parameters.R` | 1.2 | New unit tests |
| `tests/integration/test-gapit-params-e2e.sh` | 1.3 | New integration tests |
| `scripts/run_gwas_single_trait.R` | 2.2, 3.2, 6.3 | Fix MAF, update schema, add params |
| `scripts/collect_results.R` | 4.2 | Update summary generation |
| `scripts/entrypoint.sh` | 5.2, 6.2 | Deprecation handling, new params |
| `cluster/argo/workflow-templates/*.yaml` | 7.1 | Add new parameters |
| `scripts/submit-all-traits-runai.sh` | 7.2 | Load new parameters |
| `docs/GAPIT_PARAMETERS.md` | 8.1 | New documentation |
| `.env.example` | 8.2 | Document all parameters |
| `README.md` | 8.3 | Link to docs |