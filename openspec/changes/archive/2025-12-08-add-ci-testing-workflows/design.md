# Design: CI Testing Workflows

## Context
The GAPIT3 GWAS pipeline currently has basic Docker build CI but lacks automated testing for R scripts, unit tests, and devcontainer validation. This creates risk when making changes to core scripts or dependencies, as errors may not be caught until runtime on the cluster.

### Current State
- **Docker Build**: Builds container and runs basic smoke tests (R version, GAPIT load, entrypoint help)
- **No Unit Tests**: R scripts have no automated tests
- **No Devcontainer Validation**: Local development environment not validated in CI
- **Limited Functional Testing**: Only tests that scripts execute, not that they produce correct results

### Stakeholders
- **Developers**: Need fast feedback on code changes
- **Cluster Users**: Need confidence that container images work correctly
- **Maintainers**: Need comprehensive test coverage for safe refactoring

## Goals / Non-Goals

### Goals
- Automated unit tests for R script logic (validation, extraction, parsing)
- Devcontainer build verification in CI
- Functional tests with synthetic/mock data
- Fast test execution (<5 minutes for R tests, <10 minutes for devcontainer)
- Clear test failure messages for debugging
- Test framework extensible for future GWAS algorithm tests

### Non-Goals
- Full GWAS integration tests with real data (too slow/expensive for CI)
- Performance benchmarking (future work)
- Security scanning (separate concern)
- Cross-platform testing (Linux/amd64 only, matching cluster)

## Decisions

### Testing Framework: testthat
**Decision**: Use `testthat` R package for unit tests

**Why**:
- De facto standard for R package testing
- Good integration with RStudio/devcontainer
- Supports test fixtures, mocking, and coverage reports
- Already familiar to R developers

**Alternatives Considered**:
- `RUnit`: Older, less actively maintained
- Custom test scripts: Reinventing the wheel, no coverage tooling

### Workflow Structure: Three Separate Workflows
**Decision**: Create three distinct workflows instead of one monolithic workflow

1. `test-r-scripts.yml` - R unit tests (fast, runs on every PR)
2. `test-devcontainer.yml` - Devcontainer build validation (slower, runs on devcontainer changes)
3. `docker-build.yml` - Enhanced with functional tests (existing workflow)

**Why**:
- **Parallelism**: Tests run concurrently, faster overall feedback
- **Selective Triggers**: Devcontainer tests only run when `.devcontainer/` changes
- **Clear Failure Domains**: Easy to identify which component failed
- **Cost Optimization**: Skip expensive builds when only docs change

**Alternatives Considered**:
- Single monolithic workflow: Slower, less granular failure reporting
- Matrix strategy within one workflow: More complex, harder to configure triggers

### Test Data Strategy: Synthetic Fixtures
**Decision**: Create minimal synthetic datasets for testing, not real genomic data

**Why**:
- **Fast**: Small files (<1MB) download and process quickly
- **Reproducible**: No dependency on external data sources
- **Focused**: Test specific edge cases (missing data, malformed files)
- **Storage**: No large files in Git repo

**Structure**:
```
tests/fixtures/
├── genotype_mini.hmp.txt      # 10 SNPs, 5 samples
├── phenotype_mini.txt         # 5 samples, 3 traits
├── phenotype_malformed.txt    # Missing "Taxa" column
└── config_test.yaml           # Test configuration
```

**Alternatives Considered**:
- Real data subset: Licensing issues, large files, less control
- No test data: Can't do functional tests, only unit tests

### Devcontainer Testing: devcontainers/cli
**Decision**: Use official `@devcontainers/cli` for devcontainer validation

**Why**:
- Official tool from VS Code team
- Supports building and running commands inside devcontainer
- Can verify R/GAPIT installation matches production Dockerfile

**Workflow**:
1. Install `@devcontainers/cli` via npm
2. Build devcontainer: `devcontainer build --workspace-folder .`
3. Run tests: `devcontainer exec --workspace-folder . R --version`
4. Verify GAPIT: `devcontainer exec --workspace-folder . Rscript -e 'library(GAPIT)'`

**Alternatives Considered**:
- Manual docker-compose: More complex, less maintainable
- Skip devcontainer tests: Risks environment drift between dev and prod

### Trigger Strategy: Path-Based Filtering
**Decision**: Use GitHub Actions `paths` filters to skip unnecessary runs

**R Script Tests** - Run on:
- `scripts/**/*.R`
- `tests/**`
- `.github/workflows/test-r-scripts.yml`

**Devcontainer Tests** - Run on:
- `.devcontainer/**`
- `Dockerfile` (shared with devcontainer)
- `.github/workflows/test-devcontainer.yml`

**Docker Build** - Run on (existing):
- `Dockerfile`
- `scripts/**`
- `config/**`
- `.github/workflows/docker-build.yml`

**Why**:
- Reduces CI cost by skipping irrelevant builds
- Faster feedback for documentation-only changes
- Still runs on `pull_request` to main for safety

## Risks / Trade-offs

### Risk: Test Maintenance Burden
**Concern**: Tests can become outdated and fail to catch bugs

**Mitigation**:
- Start with high-value tests (validation, extraction logic)
- Use synthetic fixtures that are easy to update
- Document test expectations clearly
- Review test failures before merging, don't ignore

### Risk: CI Runtime Cost
**Concern**: Multiple workflows may increase GitHub Actions minutes usage

**Mitigation**:
- Use path filters to skip unnecessary runs
- Keep R tests fast (<5 min) with minimal fixtures
- Cache R packages in CI (using `r-lib/actions/setup-r`)
- Devcontainer tests only on relevant changes

**Estimated Monthly Cost** (for active development):
- R tests: ~50 runs/month × 5 min = 250 minutes
- Devcontainer: ~5 runs/month × 10 min = 50 minutes
- Docker build: ~30 runs/month × 8 min = 240 minutes
- **Total**: ~540 minutes/month (well within free tier: 2000 min/month)

### Risk: False Positives from Mock Data
**Concern**: Tests pass with synthetic data but fail with real genomic data

**Mitigation**:
- Document that CI tests are smoke tests, not full validation
- Maintain cluster-based integration tests separately (in `docs/TESTING.md`)
- Use realistic synthetic data formats (valid HapMap structure)
- Encourage manual testing with real data before production deployment

### Trade-off: Speed vs Coverage
**Decision**: Prioritize fast tests over comprehensive coverage

**Rationale**:
- CI should give quick feedback (5-10 minutes total)
- Full GWAS runs take 15-45 minutes per trait (too slow for CI)
- Focus on logic correctness (validation, parsing) not statistical correctness

**Acceptance**:
- Unit tests verify script logic
- Functional tests verify integration
- Manual cluster tests verify full pipeline (documented in workflow)

## Migration Plan

### Phase 1: Test Framework (Week 1)
1. Add testthat to Dockerfile
2. Create `tests/` directory structure
3. Create minimal synthetic fixtures
4. Write first test (validation logic)

### Phase 2: R Script Tests (Week 1)
1. Create `test-r-scripts.yml` workflow
2. Add tests for validation and extraction scripts
3. Verify workflow runs successfully
4. Add status badge to README

### Phase 3: Devcontainer Tests (Week 2)
1. Create `test-devcontainer.yml` workflow
2. Configure devcontainer CLI installation
3. Add smoke tests for R/GAPIT inside devcontainer
4. Document devcontainer testing in TESTING.md

### Phase 4: Enhanced Docker Tests (Week 2)
1. Create synthetic test dataset in `tests/fixtures/`
2. Add functional test for `validate` command
3. Add functional test for `extract-traits` command
4. Add minimal `run-single-trait` test (if feasible)
5. Update docker-build.yml with new tests

### Rollback Plan
If tests cause issues:
- Tests are non-blocking by default (failures don't prevent merges initially)
- Can disable workflows by commenting out trigger conditions
- Can revert PR that added workflows
- No changes to production code, only test additions

## Open Questions

### Q1: Should we test GAPIT statistical outputs?
**Status**: Deferred

**Discussion**: Testing that GAPIT produces correct p-values would require:
- Known test datasets with expected results
- Statistical validation logic
- Tolerance for floating-point differences

**Decision**: Start with I/O and integration tests. Statistical correctness is validated by GAPIT3 package maintainers and manual verification on cluster.

### Q2: Should we add test coverage reporting?
**Status**: Future work

**Options**:
- Use `covr` R package to generate coverage reports
- Upload to Codecov or similar service
- Add coverage badge to README

**Decision**: Add basic tests first, then evaluate if coverage metrics are valuable. Coverage reporting adds complexity and may not be meaningful for script-based pipelines.

### Q3: Should devcontainer tests run on every PR?
**Status**: Decided - Only on devcontainer changes

**Rationale**: Devcontainer build is slow (~10 min) and changes infrequently. Use path filters to run only when `.devcontainer/` or `Dockerfile` changes. This balances coverage with CI cost.
