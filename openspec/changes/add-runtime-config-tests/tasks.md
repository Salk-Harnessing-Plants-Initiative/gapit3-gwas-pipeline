# Implementation Tasks: Add Tests for Runtime Configuration

## Overview

Step-by-step tasks for adding comprehensive test coverage for runtime configuration.

**Estimated Time**: 3-4 hours total

## Phase 1: Update Existing R Tests (1 hour)

### Task 1.1: Create test-env_var_parsing.R (30 min)

**File**: `tests/testthat/test-env_var_parsing.R`

**Steps**:
1. Create new test file
2. Add helper function to create option parser (from run_gwas_single_trait.R)
3. Write tests for each environment variable:
   - TRAIT_INDEX (integer parsing)
   - MODELS (string parsing and list splitting)
   - PCA_COMPONENTS (integer parsing)
   - SNP_THRESHOLD (scientific notation parsing)
   - MAF_FILTER (numeric parsing)
   - MULTIPLE_ANALYSIS (logical parsing)
4. Test argument precedence (CLI > env > defaults)
5. Test edge cases (empty strings, whitespace, invalid values)

**Acceptance Criteria**:
- [ ] All env vars tested
- [ ] Type conversions verified
- [ ] Precedence order tested
- [ ] Edge cases covered

### Task 1.2: Update test-config_parsing.R (15 min)

**File**: `tests/testthat/test-config_parsing.R`

**Steps**:
1. Remove yaml library dependency
2. Update tests to not expect config.yaml
3. Consider deprecating this file entirely (config.yaml no longer used)
4. Or repurpose for testing backward compatibility

**Acceptance Criteria**:
- [ ] No yaml dependency
- [ ] Tests pass without config.yaml

### Task 1.3: Update helper.R if needed (15 min)

**File**: `tests/testthat/helper.R`

**Steps**:
1. Review existing helper functions
2. Add helpers for setting/unsetting env vars cleanly
3. Add helpers for running R scripts with env vars

**Example helper**:
```r
with_env_vars <- function(vars, code) {
  old_vals <- list()
  for (name in names(vars)) {
    old_vals[[name]] <- Sys.getenv(name, unset = NA)
    Sys.setenv(name = vars[[name]])
  }

  on.exit({
    for (name in names(old_vals)) {
      if (is.na(old_vals[[name]])) {
        Sys.unsetenv(name)
      } else {
        Sys.setenv(name = old_vals[[name]])
      }
    }
  })

  force(code)
}
```

**Acceptance Criteria**:
- [ ] Helper functions added
- [ ] Cleanup guaranteed via on.exit

## Phase 2: Add Bash Tests (1 hour)

### Task 2.1: Set up bats framework (10 min)

**Steps**:
1. Add bats installation to CI workflow
2. Create `tests/bash/` directory
3. Create `tests/bash/setup.sh` with common test utilities

**Acceptance Criteria**:
- [ ] bats installs in CI
- [ ] Directory structure created

### Task 2.2: Create test-entrypoint.bats (40 min)

**File**: `tests/bash/test-entrypoint.bats`

**Steps**:
1. Set up test fixtures (temp directories, test files)
2. Write tests for validate_models():
   - Single valid model
   - Multiple valid models
   - Invalid model
   - Mixed valid/invalid
3. Write tests for validate_pca_components():
   - Valid range (0-20)
   - Zero (special case - disable PCA)
   - Negative (should fail)
   - Too large (should fail)
   - Non-integer (should fail)
4. Write tests for validate_threshold():
   - Scientific notation (5e-8)
   - Decimal notation
   - Invalid strings
5. Write tests for validate_maf_filter():
   - Valid range (0.0-0.5)
   - Zero (special case - disable)
   - Negative (should fail)
   - Too large (should fail)
6. Write tests for validate_trait_index():
   - Valid (>= 2)
   - Invalid (< 2)
   - Non-integer
7. Write tests for validate_paths():
   - Existing paths
   - Missing files
   - Output directory creation

**Acceptance Criteria**:
- [ ] All validation functions tested
- [ ] Both success and failure cases covered
- [ ] Error messages verified

### Task 2.3: Add shellcheck to CI (10 min)

**Steps**:
1. Install shellcheck in CI
2. Run on all bash scripts
3. Fix any issues found

**Command**:
```bash
shellcheck scripts/*.sh
```

**Acceptance Criteria**:
- [ ] shellcheck passes on all scripts
- [ ] Common bash issues caught

## Phase 3: Add Integration Tests (1 hour)

### Task 3.1: Create test-env-vars-e2e.sh (30 min)

**File**: `tests/integration/test-env-vars-e2e.sh`

**Steps**:
1. Create test script framework
2. Test 1: Help command shows env var documentation
3. Test 2: Custom env vars reach entrypoint and are logged
4. Test 3: Invalid model caught by validation (fails fast)
5. Test 4: Invalid PCA caught by validation
6. Test 5: Invalid MAF caught by validation
7. Test 6: Missing paths caught by validation
8. Test 7: Default values work when no env vars set
9. Test 8: Multiple env vars work together

**Example test**:
```bash
test_invalid_config_fails_fast() {
  echo "Test: Invalid configuration fails in entrypoint"

  output=$(docker run --rm \
    -e PCA_COMPONENTS=100 \
    gapit3:test run-single-trait 2>&1 || true)

  # Should fail in entrypoint validation
  if [[ "$output" =~ "must be between 0 and 20" ]]; then
    pass "Invalid PCA caught in validation"
  else
    fail "Invalid PCA not caught"
  fi

  # Should NOT reach R script
  if [[ "$output" =~ "Loading genotype" ]]; then
    fail "Validation did not stop execution"
  fi
}
```

**Acceptance Criteria**:
- [ ] Docker image builds successfully
- [ ] All env vars tested end-to-end
- [ ] Validation catches errors before R execution
- [ ] Error messages are helpful

### Task 3.2: Create test-docker-entrypoint.sh (15 min)

**File**: `tests/integration/test-docker-entrypoint.sh`

**Steps**:
1. Test ENTRYPOINT with run-single-trait command
2. Test ENTRYPOINT with run-aggregation command
3. Test ENTRYPOINT with help command
4. Test ENTRYPOINT with invalid command
5. Test default CMD (should be run-single-trait)

**Acceptance Criteria**:
- [ ] All commands route correctly
- [ ] Invalid commands fail with helpful message
- [ ] Default CMD works

### Task 3.3: Create test fixtures (15 min)

**Directory**: `tests/integration/fixtures/`

**Steps**:
1. Create minimal genotype file (10 SNPs, 5 samples)
2. Create minimal phenotype file (5 samples, 3 traits)
3. Document fixture format

**Acceptance Criteria**:
- [ ] Fixtures small but valid
- [ ] Files in correct format (HapMap, tab-delimited)

## Phase 4: Update CI Workflows (30 min)

### Task 4.1: Update test-r-scripts.yml (10 min)

**File**: `.github/workflows/test-r-scripts.yml`

**Changes**:
1. Remove `yaml` from package installation list
2. Add specific test for env var parsing
3. Verify tests run without config.yaml

**Acceptance Criteria**:
- [ ] Workflow passes without yaml package
- [ ] Env var tests run specifically

### Task 4.2: Create test-bash-scripts.yml (10 min)

**File**: `.github/workflows/test-bash-scripts.yml` (new)

**Steps**:
1. Create new workflow file
2. Add bats installation
3. Run entrypoint tests
4. Run shellcheck
5. Set up to run on push/PR

**Acceptance Criteria**:
- [ ] Workflow created
- [ ] Runs on push and PR
- [ ] bats and shellcheck both run

### Task 4.3: Create test-integration.yml (10 min)

**File**: `.github/workflows/test-integration.yml` (new)

**Steps**:
1. Create new workflow file
2. Build Docker image (with caching)
3. Run integration test script
4. Set up to run on push/PR

**Acceptance Criteria**:
- [ ] Workflow created
- [ ] Docker build succeeds
- [ ] Integration tests run

## Phase 5: Documentation and Cleanup (30 min)

### Task 5.1: Update TESTING.md (15 min)

**File**: `docs/TESTING.md` (create if doesn't exist)

**Content**:
1. Overview of test structure
2. How to run tests locally
3. What each test suite covers
4. How to add new tests

**Acceptance Criteria**:
- [ ] Documentation clear and complete
- [ ] Local testing instructions work

### Task 5.2: Update CONTRIBUTING.md (10 min)

**File**: `CONTRIBUTING.md`

**Changes**:
1. Add requirement for tests with new features
2. Link to TESTING.md
3. Mention CI must pass before merge

**Acceptance Criteria**:
- [ ] Contributing guide updated
- [ ] Testing requirements clear

### Task 5.3: Update CHANGELOG.md (5 min)

**File**: `CHANGELOG.md`

**Changes**:
1. Add entry for comprehensive test suite
2. Note improved CI coverage
3. List test categories added

**Acceptance Criteria**:
- [ ] Changelog updated
- [ ] Credit given appropriately

## Verification Checklist

Before considering this complete, verify:

### Local Testing
- [ ] R tests pass: `Rscript -e "testthat::test_dir('tests/testthat')"`
- [ ] Bash tests pass: `bats tests/bash/test-entrypoint.bats`
- [ ] Integration tests pass: `./tests/integration/test-env-vars-e2e.sh`
- [ ] shellcheck passes: `shellcheck scripts/*.sh`

### CI Testing
- [ ] All CI workflows pass
- [ ] No yaml package installed
- [ ] Docker build succeeds
- [ ] Integration tests run automatically

### Code Coverage
- [ ] All validation functions have tests
- [ ] All env vars have tests
- [ ] Both success and failure paths tested
- [ ] Edge cases covered

### Documentation
- [ ] TESTING.md created/updated
- [ ] CONTRIBUTING.md updated
- [ ] CHANGELOG.md updated
- [ ] Comments in test files explain purpose

## Rollout Plan

### Week 1 - Development
- Day 1: Phase 1 (R tests)
- Day 2: Phase 2 (Bash tests)
- Day 3: Phase 3 (Integration tests)
- Day 4: Phase 4 (CI updates)
- Day 5: Phase 5 (Documentation)

### Week 1 - Testing
- Run full test suite locally
- Fix any failures
- Optimize test performance

### Week 2 - Deployment
- Merge to feat/add-ci-testing-workflows
- Verify CI passes
- Merge to main
- Monitor production

## Success Metrics

- [ ] Test suite runs in < 5 minutes
- [ ] 100% of validation logic covered
- [ ] Zero test failures before merge
- [ ] CI catches invalid configurations
- [ ] All team members can run tests locally

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| Tests take too long | Use small fixtures, mock GAPIT |
| bats not in CI | Install via npm (fast, reliable) |
| Docker tests slow | Cache layers, use buildx |
| Tests flaky | Isolate tests, clean up properly |
| Breaking changes | Update tests incrementally |
