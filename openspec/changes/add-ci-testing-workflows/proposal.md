# Change Proposal: Add CI Testing Workflows

## Why
The project currently has a Docker build workflow but lacks automated testing for R scripts and unit tests. Without CI testing, developers cannot verify that code changes don't break functionality before merging. Additionally, the devcontainer configuration is not validated in CI, which could lead to environment inconsistencies between local development and production.

## What Changes
- Add GitHub Actions workflow for R script unit tests
- Add workflow to validate devcontainer configuration and build
- Extend existing Docker build workflow to include functional tests
- Create test framework structure for R scripts (using testthat)
- Add sample unit tests for validation and extraction scripts

## Impact

### Affected Specs
- **NEW**: `ci-testing` - Defines CI/CD testing requirements

### Affected Code
- `.github/workflows/` - New workflows: `test-r-scripts.yml`, `test-devcontainer.yml`
- `.github/workflows/docker-build.yml` - Enhanced with more comprehensive tests
- `tests/` - New directory with testthat unit tests
- `tests/testthat/` - Test files for R scripts
- `scripts/` - R scripts may need minor refactoring for testability

### Breaking Changes
None. This is purely additive functionality.

### Dependencies
- R package: `testthat` (for unit testing)
- GitHub Actions: `actions/checkout@v5`, `r-lib/actions/setup-r@v2`
- Devcontainer CLI: `devcontainers/cli` (for devcontainer testing)
