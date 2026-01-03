# Tasks: Expose All GAPIT Parameters

**Approach: Test-Driven Development (TDD)**
- Write tests FIRST for each feature
- Run tests to confirm they fail
- Implement the feature
- Run tests to confirm they pass

## Phase 1: Test Infrastructure & Fixtures

### 1.1 Create Test Fixtures for Schema v3.0.0
- [ ] Create `tests/fixtures/gapit_params/v3_full/metadata.json` with all GAPIT params
- [ ] Create `tests/fixtures/gapit_params/v3_minimal/metadata.json` with minimal params
- [ ] Create `tests/fixtures/gapit_params/v2_legacy/metadata.json` for backward compat

### 1.2 Create Unit Test File
- [ ] Create `tests/testthat/test-gapit-parameters.R`
- [ ] Add tests for `get_gapit_param()` helper function
- [ ] Add tests for schema v3.0.0 reading
- [ ] Add tests for backward compatibility with v2.0.0

### 1.3 Create Integration Test File
- [ ] Create `tests/integration/test-gapit-params-e2e.sh`
- [ ] Add tests for new env var names (MODEL, PCA_TOTAL, SNP_MAF)
- [ ] Add tests for deprecated name warnings
- [ ] Add tests for new parameters (KINSHIP_ALGORITHM, etc.)

## Phase 2: Fix MAF Parameter Bug (TDD)

### 2.1 Write Tests for MAF Fix
- [ ] Add test: GAPIT receives `SNP.MAF` not `MAF.Threshold`
- [ ] Add test: Metadata records `SNP.MAF` in gapit section
- [ ] Run tests - should FAIL

### 2.2 Implement MAF Fix
- [ ] Change `gapit_args$MAF.Threshold` to `gapit_args$SNP.MAF` in run_gwas_single_trait.R
- [ ] Run tests - should PASS

## Phase 3: Update Metadata Schema (TDD)

### 3.1 Write Tests for Schema v3.0.0
- [ ] Add test: metadata has `schema_version: "3.0.0"`
- [ ] Add test: parameters nested under `parameters.gapit`
- [ ] Add test: GAPIT params use native names (model, PCA.total, SNP.MAF, SNP.FDR)
- [ ] Run tests - should FAIL

### 3.2 Implement Schema v3.0.0
- [ ] Update metadata structure in run_gwas_single_trait.R
- [ ] Keep legacy fields for backward compatibility
- [ ] Run tests - should PASS

## Phase 4: Update Pipeline Summary (TDD)

### 4.1 Write Tests for New Summary Format
- [ ] Add test: summary reads from `parameters.gapit.*`
- [ ] Add test: summary falls back to legacy `parameters.*`
- [ ] Add test: summary displays grouped sections (GAPIT Parameters, Filtering, Data)
- [ ] Add test: summary shows GAPIT native param names
- [ ] Run tests - should FAIL

### 4.2 Implement Summary Updates
- [ ] Add `get_gapit_param()` helper to collect_results.R
- [ ] Update `generate_configuration_section()` with grouped format
- [ ] Run tests - should PASS

## Phase 5: Add Deprecation Warnings (TDD)

### 5.1 Write Tests for Deprecation
- [ ] Add integration test: MODELS triggers warning, sets MODEL
- [ ] Add integration test: PCA_COMPONENTS triggers warning, sets PCA_TOTAL
- [ ] Add integration test: MAF_FILTER triggers warning, sets SNP_MAF
- [ ] Add integration test: new name takes precedence over deprecated
- [ ] Run tests - should FAIL

### 5.2 Implement Deprecation Handling
- [ ] Add `handle_deprecated_params()` function to entrypoint.sh
- [ ] Call function before validation
- [ ] Run tests - should PASS

## Phase 6: Add New GAPIT Parameters (TDD)

### 6.1 Write Tests for New Parameters
- [ ] Add test: KINSHIP_ALGORITHM env var accepted (VanRaden, Zhang, Loiselle, EMMA)
- [ ] Add test: SNP_EFFECT env var accepted (Add, Dom)
- [ ] Add test: SNP_IMPUTE env var accepted (Middle, Major, Minor)
- [ ] Add test: Invalid values rejected with clear error message
- [ ] Run tests - should FAIL

### 6.2 Implement New Parameters in entrypoint.sh
- [ ] Add new env var declarations with defaults
- [ ] Add validation functions for each parameter
- [ ] Update `log_config()` to display new parameters
- [ ] Run tests - should PASS

### 6.3 Implement New Parameters in R Script
- [ ] Add new CLI options to run_gwas_single_trait.R
- [ ] Pass new parameters to GAPIT
- [ ] Record in metadata
- [ ] Run tests - should PASS

## Phase 7: Update Argo/RunAI Templates

### 7.1 Update WorkflowTemplates
- [ ] Add new parameters to gapit3-gwas-single-trait template
- [ ] Map to environment variables
- [ ] Test workflow submission

### 7.2 Update RunAI Scripts
- [ ] Update submit-all-traits-runai.sh
- [ ] Load new parameters from .env

## Phase 8: Documentation

### 8.1 Create GAPIT_PARAMETERS.md
- [ ] Document all exposed parameters
- [ ] Show GAPIT defaults vs pipeline defaults
- [ ] Provide usage examples

### 8.2 Update .env.example
- [ ] Add all parameters grouped by category
- [ ] Include valid options for enums
- [ ] Show default values

### 8.3 Update README.md
- [ ] Add section on GAPIT parameter configuration
- [ ] Document deprecation warnings

## Phase 9: Final Validation

### 9.1 Run Full Test Suite
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] CI pipeline passes

### 9.2 Manual Validation
- [ ] Test with real GWAS data
- [ ] Verify metadata completeness
- [ ] Check pipeline summary output

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