# Testing Guide

This document describes the testing strategy and procedures for the GAPIT3 GWAS Pipeline.

## Overview

The project uses a multi-layered testing approach:

1. **Unit Tests** - Test individual R script functions with `testthat`
2. **Functional Tests** - Test Docker container commands with synthetic data
3. **Devcontainer Tests** - Validate local development environment consistency
4. **Manual Integration Tests** - Full pipeline testing on cluster (documented below)

## Quick Start

### Running Tests Locally

#### R Unit Tests

```bash
# From project root
Rscript tests/testthat.R

# Or using testthat directly
R -e "library(testthat); test_dir('tests/testthat')"
```

#### Docker Functional Tests

```bash
# Build container
docker build -t gapit3-test .

# Test validation
docker run --rm \
  -v $(pwd)/tests/fixtures:/data \
  -v $(pwd)/tests/fixtures:/config \
  gapit3-test validate

# Test trait extraction
docker run --rm \
  -v $(pwd)/tests/fixtures:/data \
  -v $(pwd)/tests:/outputs \
  gapit3-test extract-traits /data/phenotype_mini.txt /outputs/manifest.yaml
```

#### Devcontainer Tests

```bash
# Using VS Code
# 1. Open project in VS Code
# 2. Command Palette: "Dev Containers: Reopen in Container"
# 3. Terminal inside container: R --version

# Using devcontainer CLI
npm install -g @devcontainers/cli
devcontainer build --workspace-folder .
devcontainer exec --workspace-folder . R --version
```

## Test Framework

### Structure

```
tests/
├── testthat.R              # Test runner
├── testthat/
│   ├── helper.R            # Shared test utilities
│   ├── test-config_parsing.R
│   ├── test-input_validation.R
│   └── test-trait_extraction.R
└── fixtures/               # Synthetic test data
    ├── genotype_mini.hmp.txt     # 10 SNPs, 5 samples
    ├── phenotype_mini.txt        # 5 samples, 3 traits
    ├── phenotype_malformed.txt   # Missing Taxa column
    ├── config_test.yaml          # Test configuration
    └── ids_test.txt              # Sample IDs
```

### Test Fixtures

#### Genotype Fixture (`genotype_mini.hmp.txt`)
- **Format**: HapMap format
- **Size**: 10 SNPs × 5 samples
- **Purpose**: Test file format parsing, sample ID matching

#### Phenotype Fixture (`phenotype_mini.txt`)
- **Format**: Tab-delimited with Taxa column
- **Size**: 5 samples × 3 traits
- **Purpose**: Test trait extraction, column indexing

#### Malformed Phenotype (`phenotype_malformed.txt`)
- **Issue**: Uses "SampleID" instead of "Taxa"
- **Purpose**: Test error detection and validation

#### Config Fixture (`config_test.yaml`)
- **Models**: BLINK, FarmCPU
- **PCA**: 3 components
- **Purpose**: Test configuration parsing

## Unit Tests

### Config Parsing Tests

Tests in `test-config_parsing.R`:

- ✅ Config file loads successfully
- ✅ GAPIT models parsed correctly
- ✅ PCA components read as integer
- ✅ Validation settings present
- ✅ Data paths specified
- ✅ Resource settings valid

### Input Validation Tests

Tests in `test-input_validation.R`:

- ✅ Genotype file has correct HapMap format
- ✅ Expected number of SNPs (10)
- ✅ Phenotype has Taxa column
- ✅ Correct number of samples (5)
- ✅ Valid GAPIT models in config
- ✅ PCA components >= 0
- ✅ File size checks work
- ✅ Missing file detection
- ✅ Minimum sample size validation
- ✅ Malformed file detection (missing Taxa)

### Trait Extraction Tests

Tests in `test-trait_extraction.R`:

- ✅ Phenotype fixture is valid
- ✅ Correct number of traits extracted (3)
- ✅ Trait column indices correct
- ✅ Trait values are numeric
- ✅ Taxa IDs match genotype samples
- ✅ Malformed file detected

## GitHub Actions CI Workflows

### R Script Tests (`.github/workflows/test-r-scripts.yml`)

**Triggers**:
- Push to main affecting `scripts/**/*.R` or `tests/**`
- Pull requests affecting same paths
- Manual workflow dispatch

**Steps**:
1. Setup R 4.4.1
2. Install dependencies (cached)
3. Run testthat tests
4. Report results

**Runtime**: ~3-5 minutes

### Devcontainer Tests (`.github/workflows/test-devcontainer.yml`)

**Triggers**:
- Push to main affecting `.devcontainer/**` or `Dockerfile`
- Pull requests affecting same paths
- Manual workflow dispatch

**Steps**:
1. Install devcontainer CLI
2. Build devcontainer
3. Verify R 4.4.1 inside container
4. Verify GAPIT3 package loads
5. Verify all required R packages present

**Runtime**: ~8-12 minutes

### Docker Build Tests (`.github/workflows/docker-build.yml`)

**Triggers**:
- Push to main affecting `Dockerfile`, `scripts/**`, `config/**`
- Pull requests affecting same paths
- Manual workflow dispatch

**Enhanced Tests**:
- ✅ R installation
- ✅ GAPIT3 package
- ✅ Required R packages
- ✅ Entrypoint script
- ✅ **NEW**: Validation with test fixtures
- ✅ **NEW**: Trait extraction functional test
- ✅ **NEW**: Environment variable configuration

**Runtime**: ~6-10 minutes

## Manual Integration Testing

While CI provides automated smoke tests, full pipeline validation requires manual testing on the cluster with real data.

### Test Pipeline (3 Traits)

```bash
cd cluster/argo

# Submit test workflow
./scripts/submit_workflow.sh test \
  --data-path /path/to/test/data \
  --output-path /path/to/test/outputs

# Monitor
./scripts/monitor_workflow.sh watch gapit3-test-<id>
```

**Expected Results**:
- ✅ Validation passes
- ✅ 3 traits extracted
- ✅ 3 GWAS jobs complete successfully
- ✅ Output directories contain:
  - Manhattan plots
  - QQ plots
  - GWAS results CSV
  - Metadata JSON

**Runtime**: ~30-45 minutes (3 traits with BLINK + FarmCPU)

### Validation Checklist

Before deploying to production:

- [ ] Local unit tests pass (`Rscript tests/testthat.R`)
- [ ] Docker build succeeds locally
- [ ] Devcontainer builds and R/GAPIT work
- [ ] All GitHub Actions workflows pass
- [ ] Test pipeline completes on cluster (3 traits)
- [ ] Output files are valid (plots viewable, CSV readable)
- [ ] Aggregated results summary generated

## Writing New Tests

### Adding Unit Tests

1. Create test file in `tests/testthat/test-<feature>.R`
2. Use testthat syntax:

```r
library(testthat)

test_that("Feature works correctly", {
  result <- my_function()
  expect_equal(result, expected_value)
})
```

3. Run tests: `Rscript tests/testthat.R`

### Adding Test Fixtures

1. Create fixture in `tests/fixtures/`
2. Keep fixtures minimal (small file size)
3. Document purpose in this file
4. Reference in helper functions if needed

### Modifying Workflows

1. Edit workflow YAML in `.github/workflows/`
2. Test locally if possible (e.g., with `act` tool)
3. Create PR to trigger workflow
4. Verify workflow runs successfully

## Troubleshooting

### "Package testthat not found"

Install testthat:
```r
install.packages("testthat")
```

Or rebuild Docker container (includes testthat).

### Tests fail with "file not found"

Ensure you're running tests from project root:
```bash
cd /path/to/gapit3-gwas-pipeline
Rscript tests/testthat.R
```

### Devcontainer tests timeout

Devcontainer build can take 10-15 minutes due to R package compilation. Increase timeout or run locally first.

### Docker functional tests fail

Ensure test fixtures exist:
```bash
ls tests/fixtures/
# Should show: genotype_mini.hmp.txt, phenotype_mini.txt, config_test.yaml, etc.
```

## Test Coverage

### Current Coverage

| Component | Unit Tests | Functional Tests | Integration Tests |
|-----------|------------|------------------|-------------------|
| Config parsing | ✅ 6 tests | N/A | ✅ Manual |
| Input validation | ✅ 10 tests | ✅ Docker | ✅ Manual |
| Trait extraction | ✅ 6 tests | ✅ Docker | ✅ Manual |
| GWAS execution | ❌ | ✅ Docker (smoke) | ✅ Manual |
| Results aggregation | ❌ | ❌ | ✅ Manual |
| Entrypoint routing | ❌ | ✅ Docker | N/A |

### Future Improvements

- [ ] Add tests for results collection script
- [ ] Add tests for GWAS output validation
- [ ] Integrate code coverage reporting (covr package)
- [ ] Add performance benchmarking tests
- [ ] Create synthetic GWAS dataset for faster integration tests

## Resources

- **testthat documentation**: https://testthat.r-lib.org/
- **GitHub Actions R setup**: https://github.com/r-lib/actions
- **Devcontainer CLI**: https://github.com/devcontainers/cli
- **Project conventions**: See `openspec/project.md`

## Support

For testing issues:
1. Check this document
2. Review workflow logs in GitHub Actions
3. Open issue with test failure details
