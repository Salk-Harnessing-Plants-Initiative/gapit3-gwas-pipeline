## Why

PR #10 code review identified 43 issues across R scripts, shell scripts, tests, and CI workflows. These span correctness bugs (wrong duration units, NA handling), security vulnerabilities (command injection, YAML injection, unquoted exec), test infrastructure defects (with_env_vars broken, tautological assertions), and CI hardening gaps (unpinned actions, script injection). Left unaddressed, these undermine the pipeline's reliability, reproducibility, and security posture.

## What Changes

### R Script Correctness (Issues 1-13)
- Fix `format_duration()` NaN/NA crash and wrong-unit bug at call sites
- Make `format_pvalue()`/`format_number()` vector-safe
- Add `trimws()` to `get_env_or_null()` for whitespace in env vars
- Fix closure scoping (`<-` to `<<-`) in `collect_workflow_stats` tryCatch
- Replace `%>%` pipe with explicit `dplyr::` calls (no magrittr dependency)
- Fix O(n^2) rbind loop, duplicate SNP overlap calc, NA MAF sprintf crash
- Always create CSV even with zero SNPs (fixes markdown-only mode)
- Add `save="no"` to `quit()` calls
- Standardize trait directory regex patterns

### Shell Script Security (Issues 14-24)
- Convert `exec $cmd` to array-based `exec "${cmd_array[@]}"`
- Conditional ANSI colors (only when terminal attached)
- Tighten threshold regex validation
- Propagate `validate_paths` exit code 2
- Sanitize inputs to prevent command injection and YAML injection
- Add numeric validation and division-by-zero guards
- Add temp file cleanup traps

### Test Infrastructure (Issues 25-37)
- Fix `with_env_vars()` which sets literal `"name"` instead of variable name
- Fix tautological integration test assertions (else branches that always pass)
- Fix P.value sort check to validate full ordering
- Fix column match to prevent substring false positives
- Remove flaky timing assertions
- Rename misleading test names
- Remove skip guards that hide test gaps

### CI Workflow Hardening (Issues 38-43)
- Pin all GitHub Actions to SHA hashes
- Add dependabot.yml for automated action updates
- Replace `${{ }}` in `run:` blocks with `env:` blocks to prevent script injection
- Replace `|| true` with captured exit codes
- Add file hash to cache keys
- Extend bash validation to include integration test scripts

## Impact
- Affected specs: `results-aggregation`, `ci-testing`, `runtime-configuration`
- Affected code: `scripts/lib/aggregation_utils.R`, `scripts/collect_results.R`, `scripts/entrypoint.sh`, `scripts/autonomous-pipeline-monitor.sh`, `scripts/retry-argo-traits.sh`, `tests/testthat/helper.R`, `tests/testthat/test-aggregation.R`, `tests/testthat/test-pipeline-summary.R`, `tests/integration/test-aggregation.sh`, `.github/workflows/*.yml`
- No breaking changes to external interfaces
- All changes preserve existing output formats and behavior; fixes restore intended behavior
