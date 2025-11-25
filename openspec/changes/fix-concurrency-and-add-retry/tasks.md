# Tasks: Fix Concurrency Control and Add Mount Failure Retry

## Overview

These tasks implement two complementary improvements:
1. Fix critical concurrency control bug (P0)
2. Add automatic retry for mount failures (P1)

Tasks are ordered to deliver user-visible progress incrementally. Concurrency fix tasks (1-4) should be completed first as they fix a critical bug. Retry logic tasks (5-10) can be done in parallel after task 4 or sequentially.

## Task List

### Task 1: Update concurrency check to filter by job prefix

**Dependencies**: None

**Description**: Modify the concurrency check in `submit-all-traits-runai.sh` (lines 201 and 207) to filter jobs by `$JOB_PREFIX` before counting.

**Acceptance Criteria**:
- [ ] Line 201: Add `grep "^[[:space:]]*$JOB_PREFIX-"` to job counting pipeline
- [ ] Line 207: Add same filter to while loop job counting
- [ ] Verify filter works with job names that have varying whitespace
- [ ] Test: Create jobs with different prefixes, verify only matching prefix is counted

**Files Changed**:
- `scripts/submit-all-traits-runai.sh`

**Estimated Time**: 30 minutes

**Verification**:
```bash
# Test command:
echo "  gapit3-trait-2    Running
other-job-1       Running
gapit3-trait-3    Pending" | grep "^[[:space:]]*gapit3-trait-" | wc -l
# Expected: 2
```

---

### Task 2: Change state counting from "Running" to all active states

**Dependencies**: Task 1

**Description**: Update job counting logic to count all non-terminal states (Running, Pending, ContainerCreating, Starting) instead of only "Running".

**Acceptance Criteria**:
- [ ] Replace `grep -c "Running"` with `grep -vE "Succeeded|Failed|Completed" | wc -l`
- [ ] Test: Verify Pending and ContainerCreating jobs are counted
- [ ] Test: Verify Succeeded and Failed jobs are excluded
- [ ] Add inline comment explaining why terminal states are excluded

**Files Changed**:
- `scripts/submit-all-traits-runai.sh`

**Estimated Time**: 15 minutes

**Verification**:
```bash
# Test command:
echo "job-1 Running
job-2 Pending
job-3 Succeeded
job-4 ContainerCreating
job-5 Failed" | grep -vE "Succeeded|Failed|Completed" | wc -l
# Expected: 3
```

---

### Task 3: Rename RUNNING variable to ACTIVE

**Dependencies**: Task 2

**Description**: Rename the `RUNNING` variable to `ACTIVE` throughout the concurrency check code to accurately reflect what is being counted.

**Acceptance Criteria**:
- [ ] Rename variable in declaration (line 201)
- [ ] Rename in while loop condition (line 204)
- [ ] Rename in while loop body (line 207)
- [ ] Update variable references in log messages
- [ ] Verify no remaining uses of `RUNNING` variable in concurrency context

**Files Changed**:
- `scripts/submit-all-traits-runai.sh`

**Estimated Time**: 10 minutes

---

### Task 4: Update log messages for clarity

**Dependencies**: Task 3

**Description**: Update wait loop log messages to say "active jobs in batch" instead of "jobs running" to reflect the new counting logic.

**Acceptance Criteria**:
- [ ] Change message from "$RUNNING jobs running" to "$ACTIVE active jobs in batch"
- [ ] Verify message format is clear and consistent
- [ ] Add comment explaining the counting logic (job prefix + all active states)

**Files Changed**:
- `scripts/submit-all-traits-runai.sh`

**Estimated Time**: 10 minutes

**Before**:
```bash
[WAIT] 51 jobs running (max: 50). Waiting 30s...
```

**After**:
```bash
[WAIT] 50 active jobs in batch (max: 50). Waiting 30s...
```

---

### Task 5: Create retry script with basic structure

**Dependencies**: None (can start after task 4)

**Description**: Create new file `scripts/retry-failed-traits.sh` with basic structure, argument parsing, and help text.

**Acceptance Criteria**:
- [ ] Create executable script with shebang `#!/bin/bash`
- [ ] Add `set -euo pipefail` for error handling
- [ ] Implement argument parsing for --dry-run, --max-retries, --retry-delay, --help
- [ ] Add comprehensive help text with usage examples
- [ ] Add color constants (RED, GREEN, YELLOW, BLUE, NC)
- [ ] Add logging helper functions (log_info, log_warn, log_error)
- [ ] Test: `./retry-failed-traits.sh --help` displays help correctly

**Files Changed**:
- `scripts/retry-failed-traits.sh` (new)

**Estimated Time**: 1 hour

---

### Task 6: Implement failed job detection

**Dependencies**: Task 5

**Description**: Add logic to query RunAI for failed jobs matching the job prefix.

**Acceptance Criteria**:
- [ ] Load configuration from .env file (PROJECT, JOB_PREFIX)
- [ ] Query failed jobs: `runai workspace list -p $PROJECT | grep "$JOB_PREFIX" | grep -E "Failed|Error"`
- [ ] Extract job names from output using awk
- [ ] Handle case where no failed jobs exist (exit gracefully with success message)
- [ ] Test: Verify correct job filtering with mock runai output

**Files Changed**:
- `scripts/retry-failed-traits.sh`

**Estimated Time**: 30 minutes

---

### Task 7: Implement mount failure detection

**Dependencies**: Task 6

**Description**: Add logic to check job logs for mount failure indicators and exit code 2.

**Acceptance Criteria**:
- [ ] Get job logs: `runai workspace logs <job-name> -p $PROJECT`
- [ ] Check for "INFRASTRUCTURE MOUNT FAILURE" in logs
- [ ] Handle case where logs are unavailable (skip job gracefully)
- [ ] Distinguish mount failures from other failures
- [ ] Test: Verify detection with mock logs containing mount failure message
- [ ] Test: Verify skipping of jobs without mount failure message

**Files Changed**:
- `scripts/retry-failed-traits.sh`

**Estimated Time**: 45 minutes

---

### Task 8: Implement job retry logic

**Dependencies**: Task 7

**Description**: Add core retry logic: delete failed job, extract trait index, resubmit single trait.

**Acceptance Criteria**:
- [ ] Delete failed job: `runai workspace delete <job-name> -p $PROJECT`
- [ ] Extract trait index from job name using sed
- [ ] Call submission script with START_TRAIT=idx END_TRAIT=idx
- [ ] Pass 'y' confirmation automatically using heredoc: `<<< "y"`
- [ ] Handle submission failures gracefully (log error, continue)
- [ ] Test: Verify trait index extraction with various job name formats
- [ ] Test: Verify submission script is called correctly (dry-run)

**Files Changed**:
- `scripts/retry-failed-traits.sh`

**Estimated Time**: 1 hour

---

### Task 9: Implement exponential backoff and retry limits

**Dependencies**: Task 8

**Description**: Add exponential backoff delays between retry attempts and enforce maximum retry limits.

**Acceptance Criteria**:
- [ ] Implement retry counter (in-memory for single run)
- [ ] Calculate backoff delay: `DELAY = BASE * 2^(attempt-1)`
- [ ] Add sleep for backoff delay between retries
- [ ] Enforce MAX_RETRIES limit (default 3, configurable)
- [ ] Track retry count per trait (simple approach: assume fresh run each time)
- [ ] Test: Verify backoff delays are correct (30s, 60s, 120s)

**Files Changed**:
- `scripts/retry-failed-traits.sh`

**Estimated Time**: 30 minutes

---

### Task 10: Add statistics reporting and dry-run mode

**Dependencies**: Task 9

**Description**: Implement final statistics reporting and ensure dry-run mode works correctly throughout.

**Acceptance Criteria**:
- [ ] Add counters: RETRIED, SKIPPED, FAILED, MOUNT_FAILURES
- [ ] Increment counters at appropriate points in logic
- [ ] Print final statistics summary at end of script
- [ ] Ensure dry-run mode skips deletion and submission
- [ ] Print dry-run indicators: "[DRY-RUN] Would retry..."
- [ ] Test: Run in dry-run mode, verify no actual changes made
- [ ] Test: Run with mock failures, verify statistics are accurate

**Files Changed**:
- `scripts/retry-failed-traits.sh`

**Estimated Time**: 45 minutes

---

### Task 11: Add comprehensive error handling

**Dependencies**: Task 10

**Description**: Add error handling for edge cases (job not found, logs unavailable, submission failures, etc.).

**Acceptance Criteria**:
- [ ] Handle "job not found" during describe/delete
- [ ] Handle empty/unavailable logs
- [ ] Handle submission script failures
- [ ] Continue processing remaining jobs after errors
- [ ] Log warnings/errors appropriately
- [ ] Test: Verify graceful handling of various error scenarios

**Files Changed**:
- `scripts/retry-failed-traits.sh`

**Estimated Time**: 30 minutes

---

### Task 12: Create bulk resubmit script

**Dependencies**: Task 4 (needs submission script working)

**Description**: Create `scripts/bulk-resubmit-traits.sh` that takes a list of trait indices and deletes/resubmits them in batch. This handles cases where multiple traits need to be retried (e.g., mount failures that don't trigger exit code 2).

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

**Files Changed**:
- `scripts/bulk-resubmit-traits.sh` (new)

**Estimated Time**: 30 minutes

**Usage Example**:
```bash
# Resubmit specific failed traits
bash scripts/bulk-resubmit-traits.sh 37 50 61 66 70 76

# Or use command substitution to get list from runai
failed_traits=$(runai workspace list -p talmo-lab | grep "eberrigan-gapit-gwas" | grep Failed | awk '{print $1}' | sed 's/eberrigan-gapit-gwas-//')
bash scripts/bulk-resubmit-traits.sh $failed_traits
```

**Implementation Details**:
```bash
#!/bin/bash
set -euo pipefail

# Load .env for PROJECT and JOB_PREFIX
source .env

TRAITS=("$@")

# Show summary and confirm
echo "Will resubmit ${#TRAITS[@]} traits: ${TRAITS[*]}"
read -p "Continue? (y/n) " -n 1 -r
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

# Delete and resubmit each
for trait in "${TRAITS[@]}"; do
    runai workspace delete "${JOB_PREFIX}-${trait}" -p "$PROJECT" 2>/dev/null || true
    export START_TRAIT=$trait END_TRAIT=$trait
    bash scripts/submit-all-traits-runai.sh <<< "y"
    sleep 2
done
```

---

### Task 13: Integration testing - concurrency fix

**Dependencies**: Task 4

**Description**: Test the concurrency control fix end-to-end with real or simulated RunAI cluster.

**Test Plan**:
1. Set MAX_CONCURRENT=5 in .env
2. Submit 10 jobs
3. Monitor active job count: `watch -n 2 'runai workspace list | grep $JOB_PREFIX | grep -vE "Succeeded|Failed|Completed" | wc -l'`
4. Verify count never exceeds 5
5. Verify wait messages appear correctly
6. Verify submission resumes when jobs complete

**Acceptance Criteria**:
- [ ] Active job count never exceeds MAX_CONCURRENT
- [ ] Wait messages display correct count and format
- [ ] Submission completes successfully for all jobs
- [ ] Document test results in PR description

**Estimated Time**: 30 minutes

---

### Task 14: Integration testing - retry script

**Dependencies**: Task 11

**Description**: Test the retry script end-to-end with real or simulated job failures.

**Test Plan**:
1. Submit batch of jobs
2. Manually fail a job (or wait for natural mount failure)
3. Run retry script in dry-run mode, verify detection
4. Run retry script (actual), verify job is deleted and resubmitted
5. Verify statistics are accurate
6. Test max retries by forcing multiple failures

**Acceptance Criteria**:
- [ ] Dry-run mode correctly identifies mount failures without acting
- [ ] Actual mode successfully deletes and resubmits failed jobs
- [ ] Statistics report is accurate
- [ ] Max retry limit is enforced
- [ ] Document test results in PR description

**Estimated Time**: 1 hour

---

### Task 15: Create unit test script for retry logic

**Dependencies**: Task 11

**Description**: Create a unit test script (`tests/unit/test-retry-script.sh`) that validates retry script logic without requiring RunAI cluster access.

**Acceptance Criteria**:
- [ ] Test script follows pattern from `tests/integration/test-env-vars-e2e.sh`
- [ ] Test help flag (`--help`) displays usage correctly
- [ ] Test trait index extraction from job names (various formats)
- [ ] Test mount failure detection patterns (grep logic)
- [ ] Test job prefix filtering with whitespace tolerance
- [ ] Test dry-run and max-retries flag parsing
- [ ] Test exponential backoff delay calculation
- [ ] Test script syntax validation (`bash -n`)
- [ ] Test required UNIX tools availability (grep, awk, sed, wc)
- [ ] All tests use assert_equals, assert_contains, assert_exit_code helpers
- [ ] Test script is executable and has proper shebang

**Files Changed**:
- `tests/unit/test-retry-script.sh` (new)

**Estimated Time**: 2 hours

**Example Tests**:
```bash
# Trait extraction test
job_name="eberrigan-gapit-gwas-42"
trait_idx=$(echo "$job_name" | sed "s/^eberrigan-gapit-gwas-//")
assert_equals "$trait_idx" "42" "Extract index from job name"

# Mount failure detection test
logs="[ERROR] INFRASTRUCTURE MOUNT FAILURE"
echo "$logs" | grep -qi "INFRASTRUCTURE MOUNT FAILURE"
assert_exit_code "$?" 0 "Detect mount failure in logs"
```

---

### Task 16: Create GitHub Actions workflow for bash script tests

**Dependencies**: Task 15

**Description**: Create `.github/workflows/test-bash-scripts.yml` workflow that runs unit tests for bash scripts on every push/PR.

**Acceptance Criteria**:
- [ ] Workflow triggers on push to main (paths: `scripts/**/*.sh`, `tests/**`)
- [ ] Workflow triggers on all PRs (paths: `scripts/**/*.sh`, `tests/**`)
- [ ] Includes `workflow_dispatch` for manual runs
- [ ] Job runs on `ubuntu-latest`
- [ ] Checks out repository with `actions/checkout@v5`
- [ ] Makes test scripts executable (`chmod +x tests/unit/*.sh`)
- [ ] Runs retry script unit tests: `bash tests/unit/test-retry-script.sh`
- [ ] Tests retry script syntax: `bash -n scripts/retry-failed-traits.sh`
- [ ] Tests submission script syntax: `bash -n scripts/submit-all-traits-runai.sh`
- [ ] Creates test summary with `$GITHUB_STEP_SUMMARY`
- [ ] Lists all tested components in summary
- [ ] Fails workflow if any test fails

**Files Changed**:
- `.github/workflows/test-bash-scripts.yml` (new)

**Estimated Time**: 1 hour

**Workflow Structure**:
```yaml
name: Bash Script Tests
on:
  push:
    branches: [main]
    paths: ['scripts/**/*.sh', 'tests/**', '.github/workflows/test-bash-scripts.yml']
  pull_request:
    paths: ['scripts/**/*.sh', 'tests/**']
  workflow_dispatch:

jobs:
  test-bash-scripts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Run retry script unit tests
      - name: Test bash syntax validation
      - name: Test summary
```

---

### Task 17: Update documentation

**Dependencies**: Tasks 13, 14, 16

**Description**: Update project documentation to reflect new behavior, usage, and testing.

**Files to Update**:
- `docs/RUNAI_QUICK_REFERENCE.md`: Add concurrency control explanation
- `docs/DEPLOYMENT_TESTING.md`: Add retry workflow section
- `README.md`: Update usage examples if needed
- `scripts/submit-all-traits-runai.sh`: Add comment block explaining concurrency logic

**Acceptance Criteria**:
- [ ] Concurrency control is documented with examples
- [ ] Retry script usage is documented
- [ ] Troubleshooting section includes mount failure guidance
- [ ] All code changes have inline comments
- [ ] Documentation is clear and accurate
- [ ] CI testing is mentioned in documentation

**Estimated Time**: 1.5 hours

---

## Parallelization Opportunities

**Can be done in parallel**:
- Tasks 5-11 (retry script) can start after Task 4 completes
- Task 12 (bulk resubmit) can be done after Task 4 completes
- Tasks 13 and 14 (integration tests) can be done in parallel if resources allow
- Task 15 (unit tests) can be done alongside Task 14 (integration tests)
- Task 16 (CI workflow) can start as soon as Task 15 completes
- Task 17 can be partially done alongside testing (draft docs, finalize after tests pass)

**Must be sequential**:
- Tasks 1-4 must be done in order (each builds on previous)
- Tasks 5-11 should be done in order for retry script (each builds on previous)
- Task 12 must wait for Task 4 (needs submission script)
- Task 15 must wait for Task 11 (needs retry script complete)
- Task 16 must wait for Task 15 (needs test script)
- Task 17 must wait for Tasks 13, 14, 16 to complete (need test results for documentation)

## Total Estimated Time

**Part 1 (Concurrency Fix)**: Tasks 1-4, 13 = 3 hours
**Part 2 (Retry + Bulk Resubmit)**: Tasks 5-12, 14 = 7.5 hours
**Part 3 (CI Testing)**: Tasks 15-16 = 3 hours
**Documentation**: Task 17 = 1.5 hours

**Total**: ~15 hours (approximately 2 days)

## Success Metrics

**Concurrency Fix**:
- [ ] MAX_CONCURRENT=50 limits batch to exactly 50 active jobs
- [ ] Multiple users don't interfere with each other's batches
- [ ] Wait messages are clear and accurate

**Retry Script**:
- [ ] Mount failures are automatically detected and retried
- [ ] Configuration errors are not retried
- [ ] Max retry limit prevents infinite loops
- [ ] Statistics provide clear visibility into retry operations

**CI Testing**:
- [ ] Unit tests pass for retry script logic
- [ ] Bash syntax validation passes for all scripts
- [ ] CI workflow runs on every push/PR
- [ ] Test failures block PR merges
- [ ] Test coverage includes all critical retry logic (trait extraction, mount detection, filtering)

## Risk Mitigation

**If concurrency fix breaks something**:
- Revert is easy (single commit, minimal changes)
- Rollback plan: `git revert <commit-hash>`

**If retry script has bugs**:
- Script is new file, can be removed without affecting other functionality
- Dry-run mode allows safe testing before actual retries
- Max retry limit prevents runaway resource consumption
