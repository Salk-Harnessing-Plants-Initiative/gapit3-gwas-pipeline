# ci-testing Specification

## Purpose
TBD - created by archiving change add-ci-testing-workflows. Update Purpose after archive.
## Requirements
### Requirement: R Script Unit Tests
The system SHALL provide automated unit tests for R scripts using the testthat framework.

#### Scenario: Validation logic test
- **WHEN** validation script is executed with invalid input path
- **THEN** test verifies that appropriate error message is returned
- **AND** exit code is non-zero

#### Scenario: Trait extraction test
- **WHEN** extraction script processes phenotype file with 3 traits
- **THEN** test verifies that 3 trait names are extracted
- **AND** output manifest contains correct trait column indices

#### Scenario: Config parsing test
- **WHEN** config file is loaded with BLINK and FarmCPU models
- **THEN** test verifies that models list contains exactly 2 entries
- **AND** PCA components parameter is correctly parsed

### Requirement: GitHub Actions R Testing Workflow
The system SHALL provide a GitHub Actions workflow that runs R unit tests on every pull request and push to main.

#### Scenario: Workflow triggers on R script changes
- **WHEN** a pull request modifies files in `scripts/**/*.R`
- **THEN** workflow executes and runs all testthat tests
- **AND** workflow reports pass/fail status to PR checks

#### Scenario: Workflow uses correct R version
- **WHEN** workflow runs
- **THEN** R version 4.4.1 is installed
- **AND** all required packages are available

#### Scenario: Workflow caches R packages
- **WHEN** workflow runs multiple times
- **THEN** R packages are restored from cache on subsequent runs
- **AND** installation time is reduced by at least 50%

#### Scenario: Workflow skips on documentation changes
- **WHEN** a pull request only modifies `*.md` files
- **THEN** R testing workflow does not run
- **AND** no CI minutes are consumed for this workflow

### Requirement: Devcontainer Validation Workflow
The system SHALL provide a GitHub Actions workflow that validates devcontainer configuration builds correctly.

#### Scenario: Devcontainer builds successfully
- **WHEN** devcontainer workflow is triggered
- **THEN** devcontainer builds without errors using devcontainers/cli
- **AND** build completes within 15 minutes

#### Scenario: Devcontainer contains R and GAPIT
- **WHEN** devcontainer build completes
- **THEN** R version 4.4.1 is installed inside container
- **AND** GAPIT3 package is loadable
- **AND** all required R packages are present

#### Scenario: Devcontainer workflow triggers selectively
- **WHEN** a pull request modifies `.devcontainer/devcontainer.json`
- **THEN** devcontainer workflow executes
- **AND** when unrelated files change, workflow does not run

### Requirement: Enhanced Docker Build Functional Tests
The system SHALL extend the existing docker-build workflow with functional tests using synthetic test data.

#### Scenario: Validate command with mock data
- **WHEN** Docker container runs `validate` command
- **THEN** validation executes against test fixture files
- **AND** returns expected validation results
- **AND** logs informative messages about file checks

#### Scenario: Extract traits with sample phenotype
- **WHEN** Docker container runs `extract-traits` on sample phenotype fixture
- **THEN** trait manifest is generated
- **AND** manifest contains expected trait names and indices
- **AND** output is valid YAML format

#### Scenario: Run single trait with synthetic data
- **WHEN** Docker container runs `run-single-trait` with minimal synthetic dataset
- **THEN** GWAS execution completes without errors
- **AND** output directory contains expected files (plots, results CSV)
- **AND** execution completes within 5 minutes

#### Scenario: Environment variable configuration test
- **WHEN** Docker container is run with custom OPENBLAS_NUM_THREADS value
- **THEN** R process uses specified thread count
- **AND** OpenBLAS configuration is logged

### Requirement: Test Fixtures and Mock Data
The system SHALL provide synthetic test datasets in `tests/fixtures/` directory for reproducible testing.

#### Scenario: Minimal genotype fixture
- **WHEN** tests require genotype data
- **THEN** `genotype_mini.hmp.txt` is available
- **AND** contains 10 SNPs across 5 samples
- **AND** follows valid HapMap format

#### Scenario: Minimal phenotype fixture
- **WHEN** tests require phenotype data
- **THEN** `phenotype_mini.txt` is available
- **AND** contains "Taxa" column and 3 trait columns
- **AND** has 5 samples matching genotype fixture

#### Scenario: Malformed data fixtures
- **WHEN** tests need to verify error handling
- **THEN** `phenotype_malformed.txt` is available (missing Taxa column)
- **AND** validation tests can verify appropriate error messages

#### Scenario: Test configuration file
- **WHEN** tests require config file
- **THEN** `config_test.yaml` is available
- **AND** contains valid GAPIT parameters
- **AND** references test fixture file paths

### Requirement: Test Framework Structure
The system SHALL organize tests following R package conventions with testthat.

#### Scenario: Test directory structure
- **WHEN** repository is cloned
- **THEN** `tests/testthat/` directory exists
- **AND** contains test files named `test-*.R`
- **AND** contains `helper.R` with shared test utilities

#### Scenario: Test runner script
- **WHEN** developer runs tests locally
- **THEN** `tests/testthat.R` script executes all tests
- **AND** outputs summary of pass/fail results
- **AND** exits with non-zero code on any test failure

#### Scenario: Testthat in Dockerfile
- **WHEN** Docker image is built
- **THEN** testthat package is installed
- **AND** available for running tests inside container

### Requirement: CI Status Badges
The system SHALL display CI workflow status badges in README.md for visibility.

#### Scenario: R tests badge
- **WHEN** README.md is viewed
- **THEN** badge shows status of R testing workflow
- **AND** badge links to workflow runs
- **AND** displays "passing" or "failing" status

#### Scenario: Docker build badge
- **WHEN** README.md is viewed
- **THEN** badge shows status of Docker build workflow (existing)
- **AND** reflects enhanced functional tests

#### Scenario: Devcontainer badge
- **WHEN** README.md is viewed
- **THEN** badge shows status of devcontainer validation workflow
- **AND** updates when devcontainer workflow runs

### Requirement: Test Documentation
The system SHALL provide comprehensive testing documentation for developers.

#### Scenario: Testing guide document
- **WHEN** developer wants to run tests
- **THEN** `docs/TESTING.md` exists
- **AND** documents how to run unit tests locally
- **AND** explains test fixture structure
- **AND** describes CI workflow behavior

#### Scenario: Contributing section in README
- **WHEN** contributor wants to add features
- **THEN** README contains "Contributing" section
- **AND** section references TESTING.md
- **AND** explains test requirements for PRs

#### Scenario: OpenSpec project.md update
- **WHEN** project.md is consulted
- **THEN** testing strategy section reflects new test framework
- **AND** describes testthat usage
- **AND** documents CI workflows and triggers

