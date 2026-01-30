## MODIFIED Requirements

### Requirement: GitHub Actions R Testing Workflow

The system SHALL provide a GitHub Actions workflow that runs R unit tests on every pull request and push to main.

**Modification**: All GitHub Actions MUST be pinned to SHA hashes (not floating tags) with version comments for auditability and supply-chain security. The `run:` blocks MUST NOT use `${{ }}` expressions directly (use `env:` block instead to prevent script injection). Cache keys MUST include `hashFiles('.github/workflows/test-r-scripts.yml')` to bust cache on workflow changes. Error suppression via `|| true` MUST be replaced with captured exit codes and warning messages.

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
- **AND** cache key includes workflow file hash for invalidation on workflow changes
- **AND** installation time is reduced by at least 50%

#### Scenario: Actions pinned to SHA hashes

- **WHEN** any GitHub Actions workflow file is inspected
- **THEN** all `uses:` directives MUST reference SHA hashes (e.g., `actions/checkout@abc123`)
- **AND** a version comment MUST follow (e.g., `# v4`)
- **AND** no floating tags (e.g., `@v4`) are used

#### Scenario: No script injection in run blocks

- **WHEN** workflow `run:` blocks need GitHub context values (e.g., PR title)
- **THEN** values MUST be passed via `env:` block
- **AND** `${{ }}` expressions MUST NOT appear inside `run:` blocks

### Requirement: Test Framework Structure

The system SHALL organize tests following R package conventions with testthat.

**Modification**: The `helper.R` `with_env_vars()` function MUST correctly set named environment variables using `do.call(Sys.setenv, ...)` pattern. Integration tests MUST have correct pass/fail logic in all branches (no tautological else-pass). Test names MUST be unique and accurately describe what they test.

#### Scenario: Test directory structure

- **WHEN** repository is cloned
- **THEN** `tests/testthat/` directory exists
- **AND** contains test files named `test-*.R`
- **AND** contains `helper.R` with shared test utilities

#### Scenario: with_env_vars sets named variables correctly

- **GIVEN** a call to `with_env_vars(list(MY_VAR = "test_value"), ...)`
- **WHEN** code runs inside the `with_env_vars` block
- **THEN** `Sys.getenv("MY_VAR")` MUST return `"test_value"`
- **AND** the variable name MUST NOT be set to literal string `"name"`

#### Scenario: with_env_vars restores original values

- **GIVEN** environment variable `MY_VAR` is set to `"original"`
- **WHEN** `with_env_vars(list(MY_VAR = "temporary"), ...)` completes
- **THEN** `Sys.getenv("MY_VAR")` MUST return `"original"`

## ADDED Requirements

### Requirement: Dependabot for GitHub Actions

The repository MUST include a `.github/dependabot.yml` configuration to automatically propose updates when pinned GitHub Action SHAs have newer versions available.

#### Scenario: Dependabot checks GitHub Actions weekly

- **GIVEN** `.github/dependabot.yml` exists
- **WHEN** a new version of a pinned GitHub Action is released
- **THEN** Dependabot MUST create a pull request proposing the SHA update
- **AND** the PR MUST include the version change in its title

### Requirement: Integration tests must have correct pass/fail logic

All integration test branches MUST increment `TESTS_FAILED` on failure. No test may have a code path that silently passes when it should fail.

#### Scenario: Fallback test fails correctly on mismatch

- **GIVEN** the integration test for fallback behavior
- **WHEN** the expected output does not match
- **THEN** the else branch MUST increment `TESTS_FAILED`
- **AND** MUST NOT silently pass

#### Scenario: P.value sort validation checks full ordering

- **GIVEN** an aggregated CSV with P.value column
- **WHEN** the sort order is validated
- **THEN** the test MUST verify `!is.unsorted(d$P.value)` across ALL rows
- **AND** MUST NOT only compare first and last values

### Requirement: Bash validation must cover integration test scripts

The bash validation workflow MUST validate all shell scripts including those in `tests/integration/`.

#### Scenario: Integration test scripts validated by shellcheck

- **GIVEN** the bash validation GitHub Actions workflow
- **WHEN** validation runs
- **THEN** scripts in `tests/integration/*.sh` MUST be included in shellcheck
- **AND** validation failures in integration scripts MUST fail the workflow
