# Implementation Tasks

## 1. Test Framework Setup
- [x] 1.1 Create `tests/testthat/` directory structure
- [x] 1.2 Add `testthat.R` test runner script
- [x] 1.3 Add `testthat` to Dockerfile R package installation
- [x] 1.4 Create test helper utilities in `tests/testthat/helper.R`

## 2. R Script Unit Tests
- [x] 2.1 Write tests for input validation logic (`test-validate_inputs.R`)
- [x] 2.2 Write tests for trait extraction logic (`test-extract_trait_names.R`)
- [x] 2.3 Write tests for entrypoint argument parsing (integration test)
- [x] 2.4 Create mock data fixtures in `tests/fixtures/` for testing
- [x] 2.5 Add tests for config file parsing

## 3. GitHub Workflow: R Script Testing
- [x] 3.1 Create `.github/workflows/test-r-scripts.yml`
- [x] 3.2 Configure R environment setup (R 4.4.1)
- [x] 3.3 Install required R packages in CI
- [x] 3.4 Run testthat tests and generate coverage report
- [x] 3.5 Add status badge to README.md

## 4. GitHub Workflow: Devcontainer Testing
- [x] 4.1 Create `.github/workflows/test-devcontainer.yml`
- [x] 4.2 Install devcontainer CLI
- [x] 4.3 Build devcontainer from `.devcontainer/devcontainer.json`
- [x] 4.4 Verify R and GAPIT installation inside devcontainer
- [x] 4.5 Run smoke tests inside devcontainer environment

## 5. Enhanced Docker Build Tests
- [x] 5.1 Add functional test for `validate` command with mock data
- [x] 5.2 Add functional test for `extract-traits` with sample phenotype
- [x] 5.3 Add test for `run-single-trait` with minimal synthetic dataset
- [x] 5.4 Verify all entrypoint commands execute without errors
- [x] 5.5 Add test for environment variable configuration (OPENBLAS_NUM_THREADS)

## 6. Documentation
- [x] 6.1 Document test framework in `docs/TESTING.md`
- [x] 6.2 Add "Contributing" section to README with test instructions
- [x] 6.3 Update `openspec/project.md` testing strategy section
- [x] 6.4 Add workflow status badges to README

## 7. Validation
- [x] 7.1 Run all tests locally to verify they pass (R not available in Claude env, will run in CI)
- [x] 7.2 Create PR to trigger workflows and verify they run
- [x] 7.3 Validate `openspec validate add-ci-testing-workflows --strict` (PASSED)
- [x] 7.4 Ensure all workflows complete successfully in CI (verified 2025-12-08: both test-r-scripts and test-devcontainer passing)
