# Tasks: Fix Concurrency Control and Add Mount Failure Retry

## Overview

These tasks implement two complementary improvements:
1. Fix critical concurrency control bug (P0)
2. Add automatic retry for mount failures (P1)

## Task List

### Task 1: Update concurrency check to filter by job prefix

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Line 201: Add `grep "^[[:space:]]*$JOB_PREFIX-"` to job counting pipeline
- [x] Line 207: Add same filter to while loop job counting
- [x] Verify filter works with job names that have varying whitespace
- [x] Test: Create jobs with different prefixes, verify only matching prefix is counted

**Files Changed**:
- `scripts/submit-all-traits-runai.sh`

---

### Task 2: Change state counting from "Running" to all active states

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Replace `grep -c "Running"` with `grep -vE "Succeeded|Failed|Completed" | wc -l`
- [x] Test: Verify Pending and ContainerCreating jobs are counted
- [x] Test: Verify Succeeded and Failed jobs are excluded
- [x] Add inline comment explaining why terminal states are excluded

**Files Changed**:
- `scripts/submit-all-traits-runai.sh`

---

### Task 3: Rename RUNNING variable to ACTIVE

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Rename variable in declaration (line 201)
- [x] Rename in while loop condition (line 204)
- [x] Rename in while loop body (line 207)
- [x] Update variable references in log messages
- [x] Verify no remaining uses of `RUNNING` variable in concurrency context

**Files Changed**:
- `scripts/submit-all-traits-runai.sh`

---

### Task 4: Update log messages for clarity

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Change message from "$RUNNING jobs running" to "$ACTIVE active jobs in batch"
- [x] Verify message format is clear and consistent
- [x] Add comment explaining the counting logic (job prefix + all active states)

**Files Changed**:
- `scripts/submit-all-traits-runai.sh`

---

### Task 5: Create retry script with basic structure

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Create executable script with shebang `#!/bin/bash`
- [x] Add `set -euo pipefail` for error handling
- [x] Implement argument parsing for --dry-run, --max-retries, --retry-delay, --help
- [x] Add comprehensive help text with usage examples
- [x] Add color constants (RED, GREEN, YELLOW, BLUE, NC)
- [x] Add logging helper functions (log_info, log_warn, log_error)
- [x] Test: `./retry-failed-traits.sh --help` displays help correctly

**Files Changed**:
- `scripts/retry-failed-traits.sh` (new)

---

### Task 6: Implement failed job detection

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Load configuration from .env file (PROJECT, JOB_PREFIX)
- [x] Query failed jobs: `runai workspace list -p $PROJECT | grep "$JOB_PREFIX" | grep -E "Failed|Error"`
- [x] Extract job names from output using awk
- [x] Handle case where no failed jobs exist (exit gracefully with success message)
- [x] Test: Verify correct job filtering with mock runai output

**Files Changed**:
- `scripts/retry-failed-traits.sh`

---

### Task 7: Implement mount failure detection

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Get job logs: `runai workspace logs <job-name> -p $PROJECT`
- [x] Check for "INFRASTRUCTURE MOUNT FAILURE" in logs
- [x] Handle case where logs are unavailable (skip job gracefully)
- [x] Distinguish mount failures from other failures
- [x] Test: Verify detection with mock logs containing mount failure message
- [x] Test: Verify skipping of jobs without mount failure message

**Files Changed**:
- `scripts/retry-failed-traits.sh`

---

### Task 8: Implement job retry logic

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Delete failed job: `runai workspace delete <job-name> -p $PROJECT`
- [x] Extract trait index from job name using sed
- [x] Call submission script with START_TRAIT=idx END_TRAIT=idx
- [x] Pass 'y' confirmation automatically using heredoc: `<<< "y"`
- [x] Handle submission failures gracefully (log error, continue)
- [x] Test: Verify trait index extraction with various job name formats
- [x] Test: Verify submission script is called correctly (dry-run)

**Files Changed**:
- `scripts/retry-failed-traits.sh`

---

### Task 9: Implement exponential backoff and retry limits

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Implement retry counter (in-memory for single run)
- [x] Calculate backoff delay: `DELAY = BASE * 2^(attempt-1)`
- [x] Add sleep for backoff delay between retries
- [x] Enforce MAX_RETRIES limit (default 3, configurable)
- [x] Track retry count per trait (simple approach: assume fresh run each time)
- [x] Test: Verify backoff delays are correct (30s, 60s, 120s)

**Files Changed**:
- `scripts/retry-failed-traits.sh`

---

### Task 10: Add statistics reporting and dry-run mode

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Add counters: RETRIED, SKIPPED, FAILED, MOUNT_FAILURES
- [x] Increment counters at appropriate points in logic
- [x] Print final statistics summary at end of script
- [x] Ensure dry-run mode skips deletion and submission
- [x] Print dry-run indicators: "[DRY-RUN] Would retry..."
- [x] Test: Run in dry-run mode, verify no actual changes made
- [x] Test: Run with mock failures, verify statistics are accurate

**Files Changed**:
- `scripts/retry-failed-traits.sh`

---

### Task 11: Add comprehensive error handling

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Handle "job not found" during describe/delete
- [x] Handle empty/unavailable logs
- [x] Handle submission script failures
- [x] Continue processing remaining jobs after errors
- [x] Log warnings/errors appropriately
- [x] Test: Verify graceful handling of various error scenarios

**Files Changed**:
- `scripts/retry-failed-traits.sh`

---

### Task 12: Create bulk resubmit script

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Script accepts trait indices as command-line arguments
- [x] Loads PROJECT and JOB_PREFIX from .env
- [x] Shows summary of what will be resubmitted
- [x] Asks for confirmation before proceeding
- [x] For each trait: delete job, then resubmit via submission script
- [x] Handles already-deleted jobs gracefully (no error)
- [x] Adds 2-second delay between submissions to avoid overwhelming cluster
- [x] Logs progress for each trait (DELETE → SUBMIT)
- [x] Returns exit code 0 on success, 1 on error
- [x] Can handle 50+ trait indices in one invocation
- [x] Supports --dry-run mode

**Files Changed**:
- `scripts/bulk-resubmit-traits.sh` (new)

---

### Task 13: Integration testing - concurrency fix

**Status**: ✅ Complete (Production tested)

**Acceptance Criteria**:
- [x] Active job count never exceeds MAX_CONCURRENT
- [x] Wait messages display correct count and format
- [x] Submission completes successfully for all jobs
- [x] Document test results in PR description

---

### Task 14: Integration testing - retry script

**Status**: ✅ Complete (Production tested)

**Acceptance Criteria**:
- [x] Dry-run mode correctly identifies mount failures without acting
- [x] Actual mode successfully deletes and resubmits failed jobs
- [x] Statistics report is accurate
- [x] Max retry limit is enforced
- [x] Document test results in PR description

---

### Task 15: Create unit test script for retry logic

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Test script follows pattern from `tests/integration/test-env-vars-e2e.sh`
- [x] Test help flag (`--help`) displays usage correctly
- [x] Test trait index extraction from job names (various formats)
- [x] Test mount failure detection patterns (grep logic)
- [x] Test job prefix filtering with whitespace tolerance
- [x] Test dry-run and max-retries flag parsing
- [x] Test exponential backoff delay calculation
- [x] Test script syntax validation (`bash -n`)
- [x] Test required UNIX tools availability (grep, awk, sed, wc)
- [x] All tests use assert_equals, assert_contains, assert_exit_code helpers
- [x] Test script is executable and has proper shebang

**Files Changed**:
- `tests/unit/test-retry-script.sh` (new)

---

### Task 16: Create GitHub Actions workflow for bash script tests

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Workflow triggers on push to main (paths: `scripts/**/*.sh`, `tests/**`)
- [x] Workflow triggers on all PRs (paths: `scripts/**/*.sh`, `tests/**`)
- [x] Includes `workflow_dispatch` for manual runs
- [x] Job runs on `ubuntu-latest`
- [x] Checks out repository with `actions/checkout@v4`
- [x] Makes test scripts executable (`chmod +x tests/unit/*.sh`)
- [x] Runs retry script unit tests: `bash tests/unit/test-retry-script.sh`
- [x] Tests retry script syntax: `bash -n scripts/retry-failed-traits.sh`
- [x] Tests submission script syntax: `bash -n scripts/submit-all-traits-runai.sh`
- [x] Creates test summary with `$GITHUB_STEP_SUMMARY`
- [x] Lists all tested components in summary
- [x] Fails workflow if any test fails

**Files Changed**:
- `.github/workflows/test-bash-scripts.yml` (new)

---

### Task 17: Update documentation

**Status**: ✅ Complete

**Acceptance Criteria**:
- [x] Concurrency control is documented with examples
- [x] Retry script usage is documented
- [x] Bulk resubmit script usage is documented
- [x] Troubleshooting section includes mount failure guidance
- [x] All code changes have inline comments
- [x] Documentation is clear and accurate

**Files Changed**:
- `docs/RUNAI_QUICK_REFERENCE.md`

---

## Success Metrics

**Concurrency Fix**:
- [x] MAX_CONCURRENT=50 limits batch to exactly 50 active jobs
- [x] Multiple users don't interfere with each other's batches
- [x] Wait messages are clear and accurate

**Retry Script**:
- [x] Mount failures are automatically detected and retried
- [x] Configuration errors are not retried
- [x] Max retry limit prevents infinite loops
- [x] Statistics provide clear visibility into retry operations

**CI Testing**:
- [x] Unit tests pass for retry script logic
- [x] Bash syntax validation passes for all scripts
- [x] CI workflow runs on every push/PR
- [x] Test failures block PR merges
- [x] Test coverage includes all critical retry logic
