## 1. Test Infrastructure Fixes (Commit A)

### 1.1 TDD: Write Failing Tests
- [x] 1.1.1 Test that `with_env_vars` actually sets the named variable (not literal "name")
- [x] 1.1.2 Test that `with_env_vars` restores original values after execution

### 1.2 Fix with_env_vars
- [x] 1.2.1 Replace `Sys.setenv(name = vars[[name]])` with `do.call(Sys.setenv, setNames(list(vars[[name]]), name))`

### 1.3 Fix Function Extraction
- [x] 1.3.1 Move `check_trait_completeness` and `read_filter_file` to `scripts/lib/aggregation_utils.R`
- [x] 1.3.2 Update test-aggregation.R to source functions directly instead of brace-counting extraction

## 2. R Pure Function Fixes (Commit B)

### 2.1 TDD: Write Failing Tests
- [x] 2.1.1 Test `format_duration(NaN)` returns "N/A"
- [x] 2.1.2 Test `format_duration(NA)` returns "N/A"
- [x] 2.1.3 Test `format_pvalue(c(NA, 1e-5))` returns vector without error
- [x] 2.1.4 Test `format_number(c(NA, 42))` returns vector without error
- [x] 2.1.5 Test `get_env_or_null` trims whitespace from env var value

### 2.2 Implementation
- [x] 2.2.1 Add NaN/NA/NULL guard to `format_duration()` returning "N/A"
- [x] 2.2.2 Add length>1 guard with `vapply` fallback to `format_pvalue()` and `format_number()`
- [x] 2.2.3 Add `trimws()` to `get_env_or_null()`

## 3. Closure Scoping & Pipe Fix (Commit C)

### 3.1 TDD: Write Failing Tests
- [x] 3.1.1 Test `collect_workflow_stats` with corrupted metadata.json populates "unknown" bucket
- [x] 3.1.2 Test `select_best_trait_dirs` works without magrittr loaded

### 3.2 Implementation
- [x] 3.2.1 Change `<-` to `<<-` in `collect_workflow_stats` tryCatch error handler
- [x] 3.2.2 Replace `%>%` pipe in `select_best_trait_dirs` with nested `dplyr::` calls

## 4. collect_results.R Bug Fixes (Commit D)

### 4.1 TDD: Write Failing Tests
- [x] 4.1.1 Test executive summary with `total_duration_hours=1.0` shows "1.0 hours" not "60.0 hours"
- [x] 4.1.2 Test NA MAF in top SNPs table renders as "N/A" not sprintf crash
- [x] 4.1.3 Test zero-SNPs scenario creates CSV file (even if empty)

### 4.2 Implementation
- [x] 4.2.1 Fix `format_duration` call sites: pass minutes directly, not `hours*60`
- [x] 4.2.2 Guard `sprintf("%.3f", row$MAF)` with `is.na()` check
- [x] 4.2.3 Replace O(n^2) rbind loop with `lapply` + `do.call(rbind, ...)`
- [x] 4.2.4 Extract duplicate SNP overlap calculation to helper, compute once
- [x] 4.2.5 Always create CSV even with 0 rows (write header-only file)
- [x] 4.2.6 Add `save="no"` to `quit()` calls (lines 793, 914)
- [x] 4.2.7 Standardize trait directory regex to `^trait_\\d+`
- [x] 4.2.8 Guard `as.Date(NULL)` with null check

## 5. entrypoint.sh Fixes (Commit E)

- [x] 5.1 Convert `exec $cmd` to bash array `cmd_array=(...)` + `exec "${cmd_array[@]}"`
- [x] 5.2 Wrap ANSI colors in `if [ -t 1 ]; then ... fi`
- [x] 5.3 Tighten threshold regex to `^[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$`
- [x] 5.4 Capture `validate_paths` `$?` and propagate exit code 2
- [x] 5.5 Replace `xargs` trim with `${var##...}` parameter expansion

## 6. Shell Script Security (Commit F)

- [x] 6.1 Sanitize `$DATASET_NAME` with `tr -cd '[:alnum:]._-/'` in autonomous-pipeline-monitor.sh
- [x] 6.2 Validate `--expected-traits` etc with `[[ =~ ^[0-9]+$ ]]`
- [x] 6.3 Guard `EXPECTED_TRAITS -eq 0` division by zero
- [x] 6.4 Wrap Phase 4 in `if [[ $exit_code -eq 0 ]]` after Phase 1 failure
- [x] 6.5 Quote/escape variables before YAML interpolation in retry-argo-traits.sh
- [x] 6.6 Add `trap 'rm -f "$TEMP_YAML"' EXIT INT TERM` for temp file cleanup

## 7. Integration Test Fixes (Commit G)

- [x] 7.1 Fix fallback test else branch to increment `TESTS_FAILED`
- [x] 7.2 Fix markdown test else branch to increment `TESTS_FAILED`
- [x] 7.3 Replace first/last P.value sort check with `!is.unsorted(d$P.value)`
- [x] 7.4 Fix column match to use regex `(^|,)"?col"?(,|$)` instead of substring
- [x] 7.5 Change log functions from `$1` to `$*`
- [x] 7.6 Replace `date +%s.%N` with `date +%s` for portability
- [x] 7.7 Remove `bc` dependency, use bash arithmetic

## 8. R Test Quality (Commit H)

- [x] 8.1 Remove flaky `expect_lt(elapsed, 0.1)` timing assertion, keep behavioral assertion
- [x] 8.2 Rename misleading test to "detects incomplete traits"
- [x] 8.3 Append "(integration)" to disambiguate duplicate test name
- [x] 8.4 Remove `skip_if_not` guards that hide test gaps, source functions properly

## 9. CI Workflow Hardening (Commit I)

- [x] 9.1 Pin all GitHub Actions to SHA hashes with version comments (via dependabot)
- [x] 9.2 Create `.github/dependabot.yml` for github-actions ecosystem
- [x] 9.3 Replace `${{ }}` in `run:` blocks with `env:` block to prevent script injection
- [x] 9.4 Replace `|| true` with captured exit codes and warnings
- [x] 9.5 Add `hashFiles('.github/workflows/test-r-scripts.yml')` to cache key
- [x] 9.6 Extend bash validation glob to include `tests/integration/*.sh`

## 10. Validation

- [x] 10.1 Run `Rscript -e "testthat::test_dir('tests/testthat')"` — all tests pass (490 pass, 2 skip)
- [x] 10.2 Run `bash tests/integration/test-aggregation.sh` — all integration tests pass
- [x] 10.3 Run `shellcheck scripts/*.sh` — no errors/warnings
- [x] 10.4 Push and confirm CI green on all checks (all 4 workflows passed)
