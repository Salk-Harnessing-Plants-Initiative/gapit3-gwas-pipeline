# Proposal: Add Tests for Runtime Configuration

## Problem Statement

The runtime configuration feature (environment variables for GAPIT parameters) was implemented without corresponding test coverage, creating significant risk for production deployment.

### Current Test Gaps

**1. R Script Tests Are Outdated**
```r
# tests/testthat/test-config_parsing.R
test_that("Test config file loads successfully", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)  # ← BROKEN: yaml removed
  # ...
})
```

**Problem**: Tests still expect config.yaml, but runtime configuration uses environment variables.

**2. No Environment Variable Tests**
```r
# What we need but don't have:
test_that("Environment variables override defaults", {
  Sys.setenv(MODELS = "BLINK")
  Sys.setenv(PCA_COMPONENTS = "5")
  # Test that R script reads these correctly
})
```

**Problem**: No verification that env vars are parsed correctly by R scripts.

**3. No Entrypoint Validation Tests**
```bash
# scripts/entrypoint.sh has validation but no tests:
validate_models() {
    local valid_models="BLINK FarmCPU MLM MLMM SUPER CMLM"
    # ... validation logic untested
}
```

**Problem**: Invalid configuration could reach cluster and fail jobs.

**4. No Bash Script Tests**
- `submit-all-traits-runai.sh` - No tests for env var passing
- `monitor-runai-jobs.sh` - No tests for job status parsing
- `cleanup-runai.sh` - No tests for dry-run vs real deletion
- `entrypoint.sh` - No tests for validation or command routing

**Problem**: Scripts could break and we wouldn't know until manual testing.

**5. CI Workflow Out of Sync**
```yaml
# .github/workflows/test-r-scripts.yml
- name: Install R package dependencies
  run: |
    install.packages(c(
      'yaml',  # ← BROKEN: removed from Dockerfile
      # ...
    ))
```

**Problem**: CI installs packages we no longer use, masking dependency issues.

### Real-World Impact

**Scenario**: Deploy to production without tests
```bash
# User sets invalid PCA value
export PCA_COMPONENTS=100  # Valid range: 0-20

# Job submission succeeds (no validation)
runai workspace submit job --environment PCA_COMPONENTS=100

# Job starts, runs for 30 minutes, then fails in GAPIT
# Wasted: 30 min compute + user's time debugging
# Impact: 186 jobs × 30 min = 93 hours wasted if all fail
```

**With tests**: Would catch invalid value in CI before deployment.

## Proposed Solution

Add three layers of test coverage to ensure runtime configuration works correctly.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Unit Tests (Component-level)                     │
├─────────────────────────────────────────────────────────────┤
│  • R script env var parsing (testthat)                     │
│  • Entrypoint validation functions (bats)                  │
│  • Parameter validation logic (bats)                        │
│  • Helper function tests (bash)                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Integration Tests (End-to-End)                   │
├─────────────────────────────────────────────────────────────┤
│  • Env vars → Entrypoint → R script pipeline               │
│  • Docker container with env vars                           │
│  • Command routing (run-single-trait, run-aggregation)     │
│  • Error propagation (invalid config → exit code)          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: CI/CD Pipeline                                    │
├─────────────────────────────────────────────────────────────┤
│  • GitHub Actions workflow updates                          │
│  • Automated test runs on push/PR                           │
│  • Docker image build + test                                │
│  • Fast feedback on configuration errors                    │
└─────────────────────────────────────────────────────────────┘
```

### Test Categories

**Category 1: R Script Environment Variable Tests**
```r
# tests/testthat/test-env_var_parsing.R
test_that("MODELS env var parsed correctly", {
  Sys.setenv(MODELS = "BLINK,FarmCPU")
  opt <- parse_env_and_args()
  expect_equal(opt$models, "BLINK,FarmCPU")

  models_list <- strsplit(opt$models, ",")[[1]]
  expect_equal(length(models_list), 2)
  expect_true("BLINK" %in% models_list)
})

test_that("PCA_COMPONENTS env var parsed as integer", {
  Sys.setenv(PCA_COMPONENTS = "5")
  opt <- parse_env_and_args()
  expect_equal(opt$pca, 5)
  expect_type(opt$pca, "integer")
})

test_that("Command-line args override env vars", {
  Sys.setenv(MODELS = "BLINK")
  opt <- parse_args(c("--models", "FarmCPU"))
  expect_equal(opt$models, "FarmCPU")
})
```

**Category 2: Entrypoint Validation Tests**
```bash
# tests/bash/test-entrypoint-validation.bats

@test "validate_models accepts valid models" {
  export MODELS="BLINK,FarmCPU"
  run validate_models
  [ "$status" -eq 0 ]
}

@test "validate_models rejects invalid model" {
  export MODELS="INVALID"
  run validate_models
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid model" ]]
}

@test "validate_pca_components rejects out of range" {
  export PCA_COMPONENTS="100"
  run validate_pca_components
  [ "$status" -eq 1 ]
  [[ "$output" =~ "must be between 0 and 20" ]]
}

@test "validate_paths catches missing files" {
  export GENOTYPE_FILE="/nonexistent/file.hmp.txt"
  run validate_paths
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Missing required files" ]]
}
```

**Category 3: Integration Tests**
```bash
# tests/integration/test-env-vars-e2e.sh

test_env_vars_reach_r_script() {
  # Build test image
  docker build -t gapit3:test .

  # Run with custom env vars
  output=$(docker run --rm \
    -e TRAIT_INDEX=2 \
    -e MODELS=BLINK \
    -e PCA_COMPONENTS=5 \
    gapit3:test help 2>&1)

  # Verify env vars logged correctly
  assert_contains "$output" "Models: BLINK"
  assert_contains "$output" "PCA Components: 5"
}

test_invalid_config_fails_fast() {
  output=$(docker run --rm \
    -e PCA_COMPONENTS=100 \
    gapit3:test run-single-trait 2>&1 || true)

  # Should fail in entrypoint validation
  assert_contains "$output" "must be between 0 and 20"
  # Should NOT reach R script
  assert_not_contains "$output" "Loading genotype"
}
```

**Category 4: CI Workflow Updates**
```yaml
# .github/workflows/test-r-scripts.yml (updated)
- name: Install R package dependencies
  run: |
    install.packages(c(
      'testthat',
      'data.table',
      'dplyr',
      'optparse',
      'jsonlite'
      # NO MORE 'yaml' - removed
    ))

- name: Test environment variable parsing
  run: |
    Rscript -e "
    library(testthat)
    test_file('tests/testthat/test-env_var_parsing.R')
    "

- name: Test entrypoint validation
  run: |
    sudo npm install -g bats
    bats tests/bash/test-entrypoint-validation.bats
```

## Benefits

### For Development
✅ **Catch errors early** - Invalid config fails in CI, not on cluster
✅ **Faster iteration** - Know immediately if changes break configuration
✅ **Documentation** - Tests serve as examples of correct usage

### For Production
✅ **Confidence** - Deploy knowing validation works
✅ **Reduced waste** - No failed jobs due to bad configuration
✅ **Better error messages** - Tests verify error messages are helpful

### For Maintenance
✅ **Regression prevention** - Can't accidentally break env var parsing
✅ **Refactoring safety** - Tests protect during code changes
✅ **Onboarding** - New developers see how config works

## Implementation

### Phase 1: Update Existing R Tests (1 hour)

**Task 1.1**: Update test-config_parsing.R
- Remove yaml dependency
- Test environment variable parsing instead
- Test command-line argument parsing
- Test argument precedence (CLI > env > defaults)

**Task 1.2**: Add test-env_var_parsing.R
- Test all env vars (MODELS, PCA_COMPONENTS, etc.)
- Test type conversions (string → integer, string → logical)
- Test list parsing (comma-separated MODELS)
- Test edge cases (empty strings, whitespace)

### Phase 2: Add Bash Tests (1 hour)

**Task 2.1**: Install bats framework
```bash
# Add to .github/workflows/test-bash-scripts.yml
- name: Install bats
  run: sudo npm install -g bats
```

**Task 2.2**: Create test-entrypoint-validation.bats
- Test validate_models()
- Test validate_pca_components()
- Test validate_threshold()
- Test validate_maf_filter()
- Test validate_trait_index()
- Test validate_paths()
- Test validate_config() (orchestration)

**Task 2.3**: Create test-bash-helpers.bats
- Test submit script argument parsing
- Test monitor script status parsing
- Test cleanup script dry-run mode

### Phase 3: Add Integration Tests (1 hour)

**Task 3.1**: Create test-env-vars-e2e.sh
- Build Docker image with test fixtures
- Test env vars reach R script
- Test invalid config fails in entrypoint
- Test command routing (run-single-trait, help, etc.)

**Task 3.2**: Create test-docker-entrypoint.sh
- Test ENTRYPOINT with various commands
- Test CMD defaults
- Test volume mounts with env vars

### Phase 4: Update CI Workflows (30 min)

**Task 4.1**: Update test-r-scripts.yml
- Remove yaml from package list
- Add env var parsing tests
- Add test for script without config.yaml

**Task 4.2**: Create test-bash-scripts.yml (new)
- Run bats tests on entrypoint
- Run bats tests on helper scripts
- Check for common bash issues (shellcheck)

**Task 4.3**: Update docker-build.yml
- Add integration tests after build
- Test entrypoint with sample env vars
- Verify validation catches errors

## Test Coverage Goals

| Component | Current | Target | Priority |
|-----------|---------|--------|----------|
| R script env parsing | 0% | 100% | Critical |
| Entrypoint validation | 0% | 100% | Critical |
| Bash helper scripts | 0% | 80% | High |
| Integration (Docker) | 0% | 90% | High |
| CI workflows | 50% | 100% | High |

## Risks and Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Tests take too long | Medium | Use test fixtures, mock GAPIT calls |
| bats not available in CI | Low | Install via npm (fast) |
| Docker tests slow | Medium | Use alpine base for test images |
| Existing tests break | Medium | Update incrementally, keep old tests until new pass |

## Success Metrics

- [ ] All R script tests pass without yaml dependency
- [ ] 100% of validation functions have test coverage
- [ ] Integration test verifies env vars work end-to-end
- [ ] CI fails on invalid configuration (tested)
- [ ] Test suite runs in < 5 minutes
- [ ] Zero test failures before merge to main

## Migration Path

**Week 1 - Update Existing Tests**
1. Fix test-config_parsing.R to work without yaml
2. Add test-env_var_parsing.R
3. Verify tests pass locally

**Week 1 - Add Bash Tests**
4. Install bats in CI
5. Create entrypoint validation tests
6. Verify bash tests pass locally

**Week 1 - Integration & CI**
7. Add Docker integration tests
8. Update CI workflows
9. Run full test suite
10. Fix any failures

**Week 2 - Deploy**
11. Merge to main with passing tests
12. Deploy to production with confidence

## Alternative Approaches Considered

**Option 1: Manual Testing Only**
- ❌ No regression prevention
- ❌ Time-consuming
- ❌ Error-prone
- ✅ Faster short-term

**Option 2: Integration Tests Only**
- ❌ Slow feedback
- ❌ Hard to debug failures
- ✅ Real-world scenarios
- ✅ Less test code

**Option 3: Comprehensive Testing (Chosen)**
- ✅ Fast feedback (unit tests)
- ✅ Real scenarios (integration)
- ✅ Regression prevention
- ✅ Good documentation
- ❌ More upfront work

## References

- [bats-core](https://github.com/bats-core/bats-core) - Bash testing framework
- [testthat](https://testthat.r-lib.org/) - R testing framework
- [GitHub Actions Testing Best Practices](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-nodejs-or-python)
