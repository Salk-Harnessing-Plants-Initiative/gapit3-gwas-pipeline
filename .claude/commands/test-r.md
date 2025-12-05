# Run R Unit Tests

Run R unit tests using the testthat framework.

## Command

```bash
Rscript tests/testthat.R
```

## Description

This command executes all R unit tests in the `tests/testthat/` directory. The test suite includes:

- Input validation tests
- Configuration parsing tests
- Trait extraction logic tests
- Aggregation function tests

## Expected Output

```
Loading required package: testthat
✔ | F W S  OK | Context
✔ |         4 | test-validation [0.2s]
✔ |         6 | test-config [0.1s]
✔ |         8 | test-trait-extraction [0.3s]
✔ |         5 | test-aggregation [0.2s]

══ Results ═══════════════════════════════════════════════════════════
Duration: 0.8 s

[ FAIL 0 | WARN 0 | SKIP 0 | PASS 23 ]
```

## Fixtures

Tests use synthetic data fixtures located in `tests/fixtures/`:
- `test_genotype.hmp.txt` - 10 SNPs, 5 samples
- `test_phenotype.txt` - 5 samples, 3 traits
- `test_config.yaml` - Test configuration

## Troubleshooting

### Missing testthat package
```bash
Rscript -e "install.packages('testthat')"
```

### Test failures
Check the specific test file for expected vs actual output and review recent code changes.

## CI Integration

Tests run automatically in GitHub Actions via `.github/workflows/test-r-scripts.yml` on:
- Changes to `scripts/**/*.R`
- Changes to `tests/**`

## Related Commands

- `/test-r-coverage` - Run tests with coverage analysis
- `/validate-r` - Validate R syntax without running tests
