# Design: Add Tests for Runtime Configuration

## Overview

This document details the technical design for comprehensive test coverage of the runtime configuration feature.

## Test Architecture

### Directory Structure

```
tests/
├── testthat/                    # R unit tests
│   ├── helper.R                 # Test utilities (existing)
│   ├── test-env_var_parsing.R   # NEW: Environment variable tests
│   ├── test-validation.R        # NEW: R-side validation
│   └── test-input_validation.R  # UPDATED: Remove yaml dependency
├── bash/                        # NEW: Bash unit tests
│   ├── setup.sh                 # Test setup and helpers
│   ├── test-entrypoint.bats     # Entrypoint validation tests
│   ├── test-submit-script.bats  # Submit script tests
│   └── test-validation.bats     # Bash validation functions
├── integration/                 # NEW: End-to-end tests
│   ├── fixtures/                # Test data
│   │   ├── genotype_mini.hmp.txt
│   │   └── phenotype_mini.txt
│   ├── test-env-vars-e2e.sh     # Env vars pipeline test
│   └── test-docker-entrypoint.sh # Docker ENTRYPOINT test
└── fixtures/                    # UPDATED: Remove config.yaml references
    ├── genotype_mini.hmp.txt
    └── phenotype_mini.txt
```

### CI Workflow Architecture

```
.github/workflows/
├── test-r-scripts.yml           # UPDATED: Remove yaml, add env var tests
├── test-bash-scripts.yml        # NEW: Bash unit tests
├── test-integration.yml         # NEW: Docker integration tests
└── docker-build.yml             # UPDATED: Add entrypoint tests
```

## Test Implementation Details

### 1. R Script Environment Variable Tests

**File**: `tests/testthat/test-env_var_parsing.R`

```r
# ==============================================================================
# Tests for Environment Variable Parsing in R Scripts
# ==============================================================================

library(testthat)
library(optparse)

# Helper to create option parser (same as run_gwas_single_trait.R)
create_option_parser <- function() {
  option_list <- list(
    make_option(c("-t", "--trait-index"), type = "integer",
                default = as.integer(Sys.getenv("TRAIT_INDEX", "2")),
                help = "Trait column index"),
    make_option(c("-m", "--models"), type = "character",
                default = Sys.getenv("MODELS", "BLINK,FarmCPU"),
                help = "Comma-separated models"),
    make_option(c("--pca"), type = "integer",
                default = as.integer(Sys.getenv("PCA_COMPONENTS", "3")),
                help = "Number of PCA components"),
    make_option(c("--maf"), type = "numeric",
                default = as.numeric(Sys.getenv("MAF_FILTER", "0.05")),
                help = "Minor allele frequency filter")
  )

  OptionParser(option_list = option_list)
}

# ==============================================================================
# Environment Variable Parsing Tests
# ==============================================================================

test_that("Default values used when no env vars set", {
  # Clear any existing env vars
  Sys.unsetenv("TRAIT_INDEX")
  Sys.unsetenv("MODELS")
  Sys.unsetenv("PCA_COMPONENTS")

  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$`trait-index`, 2)
  expect_equal(opt$models, "BLINK,FarmCPU")
  expect_equal(opt$pca, 3)
})

test_that("MODELS env var parsed correctly", {
  Sys.setenv(MODELS = "BLINK")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$models, "BLINK")

  # Test list parsing
  models_list <- strsplit(opt$models, ",")[[1]]
  expect_equal(length(models_list), 1)
  expect_equal(models_list[1], "BLINK")

  Sys.unsetenv("MODELS")
})

test_that("PCA_COMPONENTS env var parsed as integer", {
  Sys.setenv(PCA_COMPONENTS = "5")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$pca, 5)
  expect_type(opt$pca, "integer")

  Sys.unsetenv("PCA_COMPONENTS")
})

test_that("MAF_FILTER env var parsed as numeric", {
  Sys.setenv(MAF_FILTER = "0.01")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$maf, 0.01)
  expect_type(opt$maf, "double")

  Sys.unsetenv("MAF_FILTER")
})

test_that("Command-line args override env vars", {
  Sys.setenv(MODELS = "BLINK")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = c("--models", "FarmCPU"))

  expect_equal(opt$models, "FarmCPU")

  Sys.unsetenv("MODELS")
})

test_that("Comma-separated models parsed correctly", {
  Sys.setenv(MODELS = "BLINK,FarmCPU,MLM")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  models_list <- strsplit(opt$models, ",")[[1]]
  expect_equal(length(models_list), 3)
  expect_true("BLINK" %in% models_list)
  expect_true("FarmCPU" %in% models_list)
  expect_true("MLM" %in% models_list)

  Sys.unsetenv("MODELS")
})

test_that("Whitespace in models trimmed correctly", {
  Sys.setenv(MODELS = "BLINK, FarmCPU")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  models_list <- strsplit(opt$models, ",")[[1]]
  models_list <- trimws(models_list)

  expect_equal(models_list[1], "BLINK")
  expect_equal(models_list[2], "FarmCPU")

  Sys.unsetenv("MODELS")
})

test_that("Empty string env vars use defaults", {
  Sys.setenv(MODELS = "")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  # Empty string should still be read (not replaced with default)
  expect_equal(opt$models, "")

  Sys.unsetenv("MODELS")
})

test_that("All env vars work together", {
  Sys.setenv(TRAIT_INDEX = "10")
  Sys.setenv(MODELS = "BLINK")
  Sys.setenv(PCA_COMPONENTS = "5")
  Sys.setenv(MAF_FILTER = "0.01")

  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$`trait-index`, 10)
  expect_equal(opt$models, "BLINK")
  expect_equal(opt$pca, 5)
  expect_equal(opt$maf, 0.01)

  # Cleanup
  Sys.unsetenv("TRAIT_INDEX")
  Sys.unsetenv("MODELS")
  Sys.unsetenv("PCA_COMPONENTS")
  Sys.unsetenv("MAF_FILTER")
})
```

### 2. Bash Entrypoint Validation Tests

**File**: `tests/bash/test-entrypoint.bats`

```bash
#!/usr/bin/env bats
# ==============================================================================
# Tests for entrypoint.sh validation functions
# ==============================================================================

# Setup: Source the entrypoint script functions
setup() {
  # Source the validation functions from entrypoint.sh
  # Extract just the functions for testing
  export TEST_MODE=true

  # Create minimal test environment
  export DATA_PATH="/tmp/test-data"
  export OUTPUT_PATH="/tmp/test-output"
  mkdir -p "$DATA_PATH" "$OUTPUT_PATH"
  touch "$DATA_PATH/test.txt"
}

teardown() {
  rm -rf /tmp/test-data /tmp/test-output
  unset TEST_MODE
}

# ==============================================================================
# Model Validation Tests
# ==============================================================================

@test "validate_models: accepts single valid model" {
  export MODELS="BLINK"
  source scripts/entrypoint.sh
  run validate_models
  [ "$status" -eq 0 ]
}

@test "validate_models: accepts multiple valid models" {
  export MODELS="BLINK,FarmCPU"
  source scripts/entrypoint.sh
  run validate_models
  [ "$status" -eq 0 ]
}

@test "validate_models: rejects invalid model" {
  export MODELS="INVALID"
  source scripts/entrypoint.sh
  run validate_models
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid model" ]]
}

@test "validate_models: rejects one invalid in list" {
  export MODELS="BLINK,INVALID"
  source scripts/entrypoint.sh
  run validate_models
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid model" ]]
}

# ==============================================================================
# PCA Validation Tests
# ==============================================================================

@test "validate_pca_components: accepts valid range" {
  export PCA_COMPONENTS="3"
  source scripts/entrypoint.sh
  run validate_pca_components
  [ "$status" -eq 0 ]
}

@test "validate_pca_components: accepts zero" {
  export PCA_COMPONENTS="0"
  source scripts/entrypoint.sh
  run validate_pca_components
  [ "$status" -eq 0 ]
}

@test "validate_pca_components: accepts maximum" {
  export PCA_COMPONENTS="20"
  source scripts/entrypoint.sh
  run validate_pca_components
  [ "$status" -eq 0 ]
}

@test "validate_pca_components: rejects negative" {
  export PCA_COMPONENTS="-1"
  source scripts/entrypoint.sh
  run validate_pca_components
  [ "$status" -eq 1 ]
  [[ "$output" =~ "must be between 0 and 20" ]]
}

@test "validate_pca_components: rejects too large" {
  export PCA_COMPONENTS="100"
  source scripts/entrypoint.sh
  run validate_pca_components
  [ "$status" -eq 1 ]
  [[ "$output" =~ "must be between 0 and 20" ]]
}

@test "validate_pca_components: rejects non-integer" {
  export PCA_COMPONENTS="three"
  source scripts/entrypoint.sh
  run validate_pca_components
  [ "$status" -eq 1 ]
  [[ "$output" =~ "must be an integer" ]]
}

# ==============================================================================
# Threshold Validation Tests
# ==============================================================================

@test "validate_threshold: accepts scientific notation" {
  export SNP_THRESHOLD="5e-8"
  source scripts/entrypoint.sh
  run validate_threshold
  [ "$status" -eq 0 ]
}

@test "validate_threshold: accepts decimal" {
  export SNP_THRESHOLD="0.00000005"
  source scripts/entrypoint.sh
  run validate_threshold
  [ "$status" -eq 0 ]
}

@test "validate_threshold: rejects non-numeric" {
  export SNP_THRESHOLD="invalid"
  source scripts/entrypoint.sh
  run validate_threshold
  [ "$status" -eq 1 ]
  [[ "$output" =~ "must be a number" ]]
}

# ==============================================================================
# MAF Filter Validation Tests
# ==============================================================================

@test "validate_maf_filter: accepts valid range" {
  export MAF_FILTER="0.05"
  source scripts/entrypoint.sh
  run validate_maf_filter
  [ "$status" -eq 0 ]
}

@test "validate_maf_filter: accepts zero" {
  export MAF_FILTER="0.0"
  source scripts/entrypoint.sh
  run validate_maf_filter
  [ "$status" -eq 0 ]
}

@test "validate_maf_filter: rejects negative" {
  export MAF_FILTER="-0.1"
  source scripts/entrypoint.sh
  run validate_maf_filter
  [ "$status" -eq 1 ]
  [[ "$output" =~ "must be between 0.0 and 0.5" ]]
}

@test "validate_maf_filter: rejects too large" {
  export MAF_FILTER="0.6"
  source scripts/entrypoint.sh
  run validate_maf_filter
  [ "$status" -eq 1 ]
  [[ "$output" =~ "must be between 0.0 and 0.5" ]]
}

# ==============================================================================
# Trait Index Validation Tests
# ==============================================================================

@test "validate_trait_index: accepts valid index" {
  export TRAIT_INDEX="2"
  source scripts/entrypoint.sh
  run validate_trait_index
  [ "$status" -eq 0 ]
}

@test "validate_trait_index: rejects less than 2" {
  export TRAIT_INDEX="1"
  source scripts/entrypoint.sh
  run validate_trait_index
  [ "$status" -eq 1 ]
  [[ "$output" =~ "must be >= 2" ]]
}

@test "validate_trait_index: rejects non-integer" {
  export TRAIT_INDEX="2.5"
  source scripts/entrypoint.sh
  run validate_trait_index
  [ "$status" -eq 1 ]
}

# ==============================================================================
# Path Validation Tests
# ==============================================================================

@test "validate_paths: accepts existing paths" {
  export DATA_PATH="/tmp/test-data"
  export GENOTYPE_FILE="/tmp/test-data/test.txt"
  export PHENOTYPE_FILE="/tmp/test-data/test.txt"
  export OUTPUT_PATH="/tmp/test-output"

  source scripts/entrypoint.sh
  run validate_paths
  [ "$status" -eq 0 ]
}

@test "validate_paths: rejects missing data path" {
  export DATA_PATH="/nonexistent"

  source scripts/entrypoint.sh
  run validate_paths
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Missing required files" ]]
}

@test "validate_paths: creates output path if missing" {
  export OUTPUT_PATH="/tmp/test-new-output"

  source scripts/entrypoint.sh
  run validate_paths
  [ "$status" -eq 0 ]
  [ -d "/tmp/test-new-output" ]

  rm -rf /tmp/test-new-output
}
```

### 3. Integration Tests

**File**: `tests/integration/test-env-vars-e2e.sh`

```bash
#!/bin/bash
# ==============================================================================
# End-to-End Integration Tests for Environment Variables
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Build test image
echo "Building test Docker image..."
docker build -t gapit3:test . || fail "Docker build failed"

# ==============================================================================
# Test 1: Help command works
# ==============================================================================
echo "Test 1: Help command shows env var documentation"
output=$(docker run --rm gapit3:test help 2>&1)

if [[ "$output" =~ "TRAIT_INDEX" ]] && [[ "$output" =~ "MODELS" ]]; then
  pass "Help command shows environment variables"
else
  fail "Help command missing env var documentation"
fi

# ==============================================================================
# Test 2: Environment variables logged correctly
# ==============================================================================
echo "Test 2: Custom env vars reach entrypoint"
output=$(docker run --rm \
  -e TRAIT_INDEX=5 \
  -e MODELS=BLINK \
  -e PCA_COMPONENTS=7 \
  gapit3:test help 2>&1)

if [[ "$output" =~ "Trait Index:      5" ]] && \
   [[ "$output" =~ "Models:           BLINK" ]] && \
   [[ "$output" =~ "PCA Components:   7" ]]; then
  pass "Environment variables logged correctly"
else
  fail "Environment variables not reflected in output"
fi

# ==============================================================================
# Test 3: Invalid model caught by validation
# ==============================================================================
echo "Test 3: Invalid model fails validation"
output=$(docker run --rm \
  -e MODELS=INVALID \
  gapit3:test run-single-trait 2>&1 || true)

if [[ "$output" =~ "Invalid model" ]]; then
  pass "Invalid model caught by validation"
else
  fail "Invalid model not caught"
fi

# ==============================================================================
# Test 4: Invalid PCA range caught
# ==============================================================================
echo "Test 4: Out-of-range PCA fails validation"
output=$(docker run --rm \
  -e PCA_COMPONENTS=100 \
  gapit3:test run-single-trait 2>&1 || true)

if [[ "$output" =~ "must be between 0 and 20" ]]; then
  pass "Out-of-range PCA caught"
else
  fail "Invalid PCA not caught"
fi

# ==============================================================================
# Test 5: Default values work
# ==============================================================================
echo "Test 5: Default values used when no env vars set"
output=$(docker run --rm gapit3:test help 2>&1)

if [[ "$output" =~ "Models:           BLINK,FarmCPU" ]] && \
   [[ "$output" =~ "PCA Components:   3" ]]; then
  pass "Default values work correctly"
else
  fail "Defaults not working"
fi

echo ""
echo "All integration tests passed!"
```

### 4. CI Workflow Updates

**File**: `.github/workflows/test-r-scripts.yml` (updated)

```yaml
name: R Script Tests

on:
  push:
    branches: ['**']
  pull_request:
    branches: ['**']

jobs:
  test-r-scripts:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Setup R
        uses: r-lib/actions/setup-r@v2
        with:
          r-version: '4.4.1'

      - name: Install dependencies
        run: |
          install.packages(c(
            'testthat',
            'optparse',
            'jsonlite',
            'data.table',
            'dplyr'
          ))
        shell: Rscript {0}

      - name: Run testthat tests
        run: |
          Rscript -e "
          library(testthat)
          results <- test_dir('tests/testthat')
          if (any(as.data.frame(results)[['failed']] > 0)) {
            quit(status = 1)
          }
          "

      - name: Test env var parsing specifically
        run: |
          Rscript tests/testthat/test-env_var_parsing.R
```

**File**: `.github/workflows/test-bash-scripts.yml` (new)

```yaml
name: Bash Script Tests

on:
  push:
    branches: ['**']
  pull_request:
    branches: ['**']

jobs:
  test-bash:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Install bats
        run: |
          sudo npm install -g bats
          bats --version

      - name: Run entrypoint tests
        run: |
          bats tests/bash/test-entrypoint.bats

      - name: Run shellcheck
        run: |
          sudo apt-get install -y shellcheck
          shellcheck scripts/*.sh
```

**File**: `.github/workflows/test-integration.yml` (new)

```yaml
name: Integration Tests

on:
  push:
    branches: ['**']
  pull_request:
    branches: ['**']

jobs:
  integration-tests:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build test image
        uses: docker/build-push-action@v5
        with:
          context: .
          tags: gapit3:test
          load: true

      - name: Run integration tests
        run: |
          chmod +x tests/integration/test-env-vars-e2e.sh
          ./tests/integration/test-env-vars-e2e.sh
```

## Test Execution Flow

```
Developer Push
      ↓
┌─────────────────────────────────────────┐
│  GitHub Actions Triggered               │
├─────────────────────────────────────────┤
│  1. R Script Tests                      │
│     - Environment variable parsing      │
│     - Type conversions                  │
│     - Argument precedence               │
│  2. Bash Script Tests                   │
│     - Entrypoint validation             │
│     - Helper function logic             │
│     - shellcheck linting                │
│  3. Integration Tests                   │
│     - Build Docker image                │
│     - Test env vars end-to-end          │
│     - Test error cases                  │
│  4. Docker Build                        │
│     - Full image build                  │
│     - Push to registry (if main)        │
└─────────────────────────────────────────┘
      ↓
  All Pass? → Merge allowed
  Any Fail? → PR blocked
```

## Performance Considerations

- **R tests**: < 10 seconds (unit tests only)
- **Bash tests**: < 5 seconds (bats is fast)
- **Integration tests**: < 60 seconds (Docker build cached)
- **Total CI time**: < 2 minutes (parallel execution)

## Maintenance

Tests should be updated whenever:
- New environment variables added
- Validation logic changes
- New bash scripts created
- Entrypoint commands added
