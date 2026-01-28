## 1. Test Infrastructure Fixes (Commit A)

### 1.1 TDD: Write Failing Tests
- [ ] 1.1.1 Test that `with_env_vars` actually sets the named variable (not literal "name")
- [ ] 1.1.2 Test that `with_env_vars` restores original values after execution

### 1.2 Fix with_env_vars
- [ ] 1.2.1 Replace `Sys.setenv(name = vars[[name]])` with `do.call(Sys.setenv, setNames(list(vars[[name]]), name))`

### 1.3 Fix Function Extraction
- [ ] 1.3.1 Move `check_trait_completeness` and `read_filter_file` to `scripts/lib/aggregation_utils.R`
- [ ] 1.3.2 Update test-aggregation.R to source functions directly instead of brace-counting extraction

## 2. R Pure Function Fixes (Commit B)

### 2.1 TDD: Write Failing Tests
- [ ] 2.1.1 Test `format_duration(NaN)` returns "N/A"
- [ ] 2.1.2 Test `format_duration(NA)` returns "N/A"
- [ ] 2.1.3 Test `format_pvalue(c(NA, 1e-5))` returns vector without error
- [ ] 2.1.4 Test `format_number(c(NA, 42))` returns vector without error
- [ ] 2.1.5 Test `get_env_or_null` trims whitespace from env var value

### 2.2 Implementation
- [ ] 2.2.1 Add NaN/NA/NULL guard to `format_duration()` returning "N/A"
- [ ] 2.2.2 Add length>1 guard with `vapply` fallback to `format_pvalue()` and `format_number()`
- [ ] 2.2.3 Add `trimws()` to `get_env_or_null()`

## 3. Closure Scoping & Pipe Fix (Commit C)

### 3.1 TDD: Write Failing Tests
- [ ] 3.1.1 Test `collect_workflow_stats` with corrupted metadata.json populates "unknown" bucket
- [ ] 3.1.2 Test `select_best_trait_dirs` works without magrittr loaded

### 3.2 Implementation
- [ ] 3.2.1 Change `<-` to `<<-` in `collect_workflow_stats` tryCatch error handler
- [ ] 3.2.2 Replace `%>%` pipe in `select_best_trait_dirs` with nested `dplyr::` calls

## 4. collect_results.R Bug Fixes (Commit D)

### 4.1 TDD: Write Failing Tests
- [ ] 4.1.1 Test executive summary with `total_duration_hours=1.0` shows "1.0 hours" not "60.0 hours"
- [ ] 4.1.2 Test NA MAF in top SNPs table renders as "N/A" not sprintf crash
- [ ] 4.1.3 Test zero-SNPs scenario creates CSV file (even if empty)

### 4.2 Implementation
- [ ] 4.2.1 Fix `format_duration` call sites: pass minutes directly, not `hours*60`
- [ ] 4.2.2 Guard `sprintf("%.3f", row$MAF)` with `is.na()` check
- [ ] 4.2.3 Replace O(n^2) rbind loop with `lapply` + `do.call(rbind, ...)`
- [ ] 4.2.4 Extract duplicate SNP overlap calculation to helper, compute once
- [ ] 4.2.5 Always create CSV even with 0 rows (write header-only file)
- [ ] 4.2.6 Add `save="no"` to `quit()` calls (lines 793, 914)
- [ ] 4.2.7 Standardize trait directory regex to `^trait_\\d+`
- [ ] 4.2.8 Guard `as.Date(NULL)` with null check

## 5. entrypoint.sh Fixes (Commit E)

- [ ] 5.1 Convert `exec $cmd` to bash array `cmd_array=(...)` + `exec "${cmd_array[@]}"`
- [ ] 5.2 Wrap ANSI colors in `if [ -t 1 ]; then ... fi`
- [ ] 5.3 Tighten threshold regex to `^[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$`
- [ ] 5.4 Capture `validate_paths` `$?` and propagate exit code 2
- [ ] 5.5 Replace `xargs` trim with `${var##...}` parameter expansion

## 6. Shell Script Security (Commit F)

- [ ] 6.1 Sanitize `$DATASET_NAME` with `tr -cd '[:alnum:]._-/'` in autonomous-pipeline-monitor.sh
- [ ] 6.2 Validate `--expected-traits` etc with `[[ =~ ^[0-9]+$ ]]`
- [ ] 6.3 Guard `EXPECTED_TRAITS -eq 0` division by zero
- [ ] 6.4 Wrap Phase 4 in `if [[ $exit_code -eq 0 ]]` after Phase 1 failure
- [ ] 6.5 Quote/escape variables before YAML interpolation in retry-argo-traits.sh
- [ ] 6.6 Add `trap 'rm -f "$TEMP_YAML"' EXIT INT TERM` for temp file cleanup

## 7. Integration Test Fixes (Commit G)

- [ ] 7.1 Fix fallback test else branch to increment `TESTS_FAILED`
- [ ] 7.2 Fix markdown test else branch to increment `TESTS_FAILED`
- [ ] 7.3 Replace first/last P.value sort check with `!is.unsorted(d$P.value)`
- [ ] 7.4 Fix column match to use regex `(^|,)"?col"?(,|$)` instead of substring
- [ ] 7.5 Change log functions from `$1` to `$*`
- [ ] 7.6 Replace `date +%s.%N` with `date +%s` for portability
- [ ] 7.7 Remove `bc` dependency, use bash arithmetic

## 8. R Test Quality (Commit H)

- [ ] 8.1 Remove flaky `expect_lt(elapsed, 0.1)` timing assertion, keep behavioral assertion
- [ ] 8.2 Rename misleading test to "detects incomplete traits"
- [ ] 8.3 Append "(integration)" to disambiguate duplicate test name
- [ ] 8.4 Remove `skip_if_not` guards that hide test gaps, source functions properly

## 9. CI Workflow Hardening (Commit I)

- [ ] 9.1 Pin all GitHub Actions to SHA hashes with version comments
- [ ] 9.2 Create `.github/dependabot.yml` for github-actions ecosystem
- [ ] 9.3 Replace `${{ }}` in `run:` blocks with `env:` block to prevent script injection
- [ ] 9.4 Replace `|| true` with captured exit codes and warnings
- [ ] 9.5 Add `hashFiles('.github/workflows/test-r-scripts.yml')` to cache key
- [ ] 9.6 Extend bash validation glob to include `tests/integration/*.sh`

## 10. Validation

- [ ] 10.1 Run `Rscript -e "testthat::test_dir('tests/testthat')"` — all tests pass (466+)
- [ ] 10.2 Run `bash tests/integration/test-aggregation.sh` — all integration tests pass
- [ ] 10.3 Run `shellcheck scripts/*.sh` — no errors/warnings
- [ ] 10.4 Push and confirm CI green on all checks
