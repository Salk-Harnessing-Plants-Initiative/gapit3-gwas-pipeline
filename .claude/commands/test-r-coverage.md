# Run R Tests with Coverage Analysis

Run R unit tests with code coverage reporting to identify untested code paths.

## Command

```bash
Rscript -e "covr::package_coverage(type = 'tests', line_exclusions = list('R/zzz.R'))" | tee coverage_report.txt
```

## Alternative: Simple Coverage

For a quick coverage summary:

```bash
Rscript -e "library(testthat); library(covr); covr::package_coverage(type = 'tests')"
```

## Description

This command runs all R unit tests while tracking which lines of code are executed. It generates a coverage report showing:

- Overall coverage percentage
- Per-file coverage percentages
- Specific uncovered lines

## Prerequisites

Install the `covr` package if not already available:

```bash
Rscript -e "install.packages('covr')"
```

## Expected Output

```
Coverage: 85.3%
scripts/validate_inputs.R: 92.1%
scripts/extract_traits.R: 88.5%
scripts/run_gwas_single_trait.R: 78.3%
scripts/collect_results.R: 91.7%

Uncovered lines:
scripts/run_gwas_single_trait.R: 45-48, 102, 156-158
scripts/validate_inputs.R: 23, 67
```

## Interpreting Results

- **90%+ coverage**: Excellent
- **80-90% coverage**: Good
- **Below 80%**: Consider adding more tests

Focus on:
1. Error handling paths (often uncovered)
2. Edge cases (boundary conditions)
3. Complex conditional logic

## Generating HTML Report

For interactive HTML coverage report:

```bash
Rscript -e "covr::report(covr::package_coverage(type = 'tests'))"
```

This opens an HTML report in your browser showing line-by-line coverage.

## CI Integration

Coverage analysis runs in GitHub Actions but doesn't fail builds. Use this locally to improve test coverage before committing.

## Related Commands

- `/test-r` - Run tests without coverage
- `/validate-r` - Validate syntax only