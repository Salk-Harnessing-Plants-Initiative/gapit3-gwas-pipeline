# Design: Fix Concurrency Control and Add Mount Failure Retry

## Architecture Overview

This change fixes a critical bug in the RunAI submission system and adds resilience through automatic retry. The solution has two independent but complementary parts:

1. **Concurrency Control Fix**: Modify `submit-all-traits-runai.sh` to correctly count only the current batch's jobs
2. **Mount Failure Retry**: Create new `retry-failed-traits.sh` script to automatically recover from transient infrastructure failures

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Workflow                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. submit-all-traits-runai.sh (FIXED)                          │
│     - Validates .env configuration                               │
│     - Counts ONLY batch jobs (job prefix filter)                │
│     - Counts ALL active states (not just "Running")             │
│     - Respects MAX_CONCURRENT properly                          │
│     - Submits jobs with exponential spacing                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  RunAI Cluster                                                   │
│  - Schedules jobs to nodes                                       │
│  - Pulls container image                                         │
│  - Mounts hostPath volumes (/data, /outputs)                    │
│  - Starts container                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
         ┌──────────▼───────┐  ┌───────▼──────────┐
         │  Success         │  │  Mount Failure   │
         │  (exit code 0)   │  │  (exit code 2)   │
         └──────────────────┘  └──────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. retry-failed-traits.sh (NEW)                                │
│     - Detects failed jobs                                        │
│     - Checks exit codes (only retry code 2)                     │
│     - Deletes failed job                                         │
│     - Resubmits with exponential backoff                        │
│     - Limits to 3 retry attempts                                │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### Part 1: Concurrency Control Fix

#### Current Implementation (Buggy)

```bash
# Line 201: Check number of running jobs
RUNNING=$(runai workspace list -p $PROJECT 2>/dev/null | grep -c "Running" || echo 0)

# Line 204: Wait if at max concurrency
while [ $RUNNING -ge $MAX_CONCURRENT ]; do
    echo -e "${YELLOW}[WAIT]${NC} $RUNNING jobs running (max: $MAX_CONCURRENT). Waiting 30s..."
    sleep 30
    RUNNING=$(runai workspace list -p $PROJECT 2>/dev/null | grep -c "Running" || echo 0)
done
```

**Problems**:
1. `grep -c "Running"` counts ALL jobs in project, not just batch jobs
2. Only counts "Running" state, ignores "Pending", "ContainerCreating", etc.
3. Variable name `RUNNING` is misleading (not all active jobs are "Running")

#### New Implementation (Fixed)

```bash
# Check number of active jobs (Running, Pending, ContainerCreating, etc.)
# Only count jobs from this batch (matching JOB_PREFIX)
ACTIVE=$(runai workspace list -p $PROJECT 2>/dev/null | \
    grep "^[[:space:]]*$JOB_PREFIX-" | \
    grep -vE "Succeeded|Failed|Completed" | \
    wc -l || echo 0)

# Wait if at max concurrency
while [ $ACTIVE -ge $MAX_CONCURRENT ]; do
    echo -e "${YELLOW}[WAIT]${NC} $ACTIVE active jobs in batch (max: $MAX_CONCURRENT). Waiting 30s..."
    sleep 30
    ACTIVE=$(runai workspace list -p $PROJECT 2>/dev/null | \
        grep "^[[:space:]]*$JOB_PREFIX-" | \
        grep -vE "Succeeded|Failed|Completed" | \
        wc -l || echo 0)
done
```

**Fixes**:
1. `grep "^[[:space:]]*$JOB_PREFIX-"` filters to ONLY jobs matching the prefix (e.g., "eberrigan-gapit-gwas-*")
2. `grep -vE "Succeeded|Failed|Completed"` counts ALL non-terminal states (Running + Pending + ContainerCreating + Starting)
3. Variable renamed to `ACTIVE` to reflect actual semantics
4. Log message updated to say "active jobs in batch"

#### Design Rationale

**Why filter by job prefix?**
- Multiple users share the "talmo-lab" project
- Same user may have multiple experiments running
- Need isolation between batches

**Why count all active states?**
- When user sets `MAX_CONCURRENT=50`, they mean "no more than 50 jobs in flight"
- Jobs in "Pending" state still consume scheduler resources
- Jobs in "ContainerCreating" are already assigned to nodes and pulling images
- Counting only "Running" allows unlimited queueing

**Why use negative grep (`-vE "Succeeded|Failed|Completed"`) instead of positive (`-E "Running|Pending|ContainerCreating"`)?**
- Resilient to RunAI version changes (new states automatically included)
- Matches user intent (count everything that's "not done")
- Simpler to understand conceptually

### Part 2: Mount Failure Retry

#### Design Principles

1. **Separate concerns**: Retry logic in separate script, not inline in submission script
2. **Fail-safe**: Only retry infrastructure failures (exit code 2), never configuration errors (exit code 1)
3. **Bounded retries**: Hard limit of 3 attempts to prevent infinite loops
4. **Exponential backoff**: Wait 30s, 60s, 120s between retries to reduce node pressure
5. **User control**: Dry-run mode for safe testing, explicit execution for actual retry

#### Script Architecture

```bash
#!/bin/bash
# retry-failed-traits.sh

# Configuration
MAX_RETRIES=3              # Maximum retry attempts per job
RETRY_DELAY_BASE=30        # Base delay in seconds (exponential: 30s, 60s, 120s)

# Algorithm:
# 1. Get list of failed jobs: runai workspace list | grep Failed
# 2. For each failed job:
#    a. Get job logs: runai workspace logs <job>
#    b. Check for mount failure indicator: "INFRASTRUCTURE MOUNT FAILURE"
#    c. If mount failure:
#       - Delete failed job: runai workspace delete <job>
#       - Extract trait index from job name
#       - Resubmit: call submit-all-traits-runai.sh with START_TRAIT=idx END_TRAIT=idx
#       - Wait with exponential backoff
#    d. If not mount failure:
#       - Skip (log as "different error, manual investigation needed")
# 3. Report statistics: retried, succeeded, skipped, failed
```

#### Exit Code Contract

This design depends on the exit code contract established by `scripts/entrypoint.sh`:

- **Exit code 0**: Success - job completed normally
- **Exit code 1**: Configuration error - do NOT retry (user must fix config)
- **Exit code 2**: Infrastructure failure - SHOULD retry (transient issue)

**Mount failure detection in entrypoint.sh** (already implemented):
```bash
validate_paths() {
    # Check if mount points are actually mounted
    if ! mountpoint -q "$DATA_PATH" 2>/dev/null; then
        log_error "INFRASTRUCTURE MOUNT FAILURE: $DATA_PATH is not a mount point"
        return 2  # Exit code 2 = infrastructure failure (retryable)
    fi

    # ... file existence checks ...

    if [ ${#missing_paths[@]} -gt 0 ]; then
        log_error "Missing required files or directories:"
        return 1  # Exit code 1 = configuration error (not retryable)
    fi
}
```

#### Retry Logic State Machine

```
                    ┌─────────────────┐
                    │  Detect Failed  │
                    │  Jobs in RunAI  │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Get Job Logs   │
                    └────────┬────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
    ┌────────────────────┐    ┌─────────────────────┐
    │ Mount Failure      │    │ Other Failure       │
    │ (exit code 2)      │    │ (exit code 1)       │
    └──────────┬─────────┘    └──────────┬──────────┘
               │                          │
               ▼                          ▼
    ┌────────────────────┐    ┌─────────────────────┐
    │ Delete Failed Job  │    │ Skip - Report to    │
    └──────────┬─────────┘    │ User for Manual     │
               │               │ Investigation       │
               ▼               └─────────────────────┘
    ┌────────────────────┐
    │ Extract Trait ID   │
    └──────────┬─────────┘
               │
               ▼
    ┌────────────────────┐
    │ Resubmit Trait     │
    │ (START=idx,        │
    │  END=idx)          │
    └──────────┬─────────┘
               │
               ▼
    ┌────────────────────┐       ┌──────────────┐
    │ Wait Exponential   │──────>│ Retry Count  │
    │ Backoff (30s, 60s, │       │ < MAX_RETRIES│
    │ 120s)              │<──────│ ?            │
    └────────────────────┘       └──────────────┘
                                         │
                                         │ No (≥3)
                                         ▼
                                ┌─────────────────┐
                                │ Report Final    │
                                │ Failure         │
                                └─────────────────┘
```

#### Data Flow

**Input**:
- RunAI job list (from `runai workspace list -p $PROJECT`)
- Job logs (from `runai workspace logs <job-name> -p $PROJECT`)
- Configuration from `.env` (PROJECT, JOB_PREFIX, GENOTYPE_FILE, etc.)

**Processing**:
1. Filter jobs: `grep "$JOB_PREFIX" | grep -E "Failed|Error"`
2. Extract job name: `awk '{print $1}'`
3. Get logs: `runai workspace logs <job-name> -p $PROJECT`
4. Detect mount failure: `grep -qi "INFRASTRUCTURE MOUNT FAILURE"`
5. Extract trait index: `echo "$job_name" | sed "s/^${JOB_PREFIX}-//"`

**Output**:
- Console logging with color codes (GREEN/YELLOW/RED/BLUE)
- Statistics summary
- Dry-run report (if `--dry-run` flag)

#### Error Handling

**Scenario 1: Job already deleted**
```bash
if ! runai workspace describe "$job_name" -p "$PROJECT" >/dev/null 2>&1; then
    log_warn "Job $job_name no longer exists, skipping"
    SKIPPED=$((SKIPPED + 1))
    continue
fi
```

**Scenario 2: Logs not available**
```bash
JOB_LOGS=$(runai workspace logs "$job_name" -p "$PROJECT" 2>/dev/null || echo "")
if [ -z "$JOB_LOGS" ]; then
    log_warn "Could not retrieve logs for $job_name, skipping"
    SKIPPED=$((SKIPPED + 1))
    continue
fi
```

**Scenario 3: Submission fails**
```bash
if ! (export START_TRAIT="$TRAIT_IDX" END_TRAIT="$TRAIT_IDX"; bash "$SCRIPT_DIR/submit-all-traits-runai.sh" <<< "y"); then
    log_error "Resubmission failed for trait $TRAIT_IDX"
    FAILED=$((FAILED + 1))
    continue
fi
```

**Scenario 4: Max retries exceeded**
```bash
# Track retry count per trait (in-memory map or job labels)
# If retry count ≥ MAX_RETRIES:
log_warn "Trait $TRAIT_IDX has failed $MAX_RETRIES times, not retrying again"
SKIPPED=$((SKIPPED + 1))
```

### Part 3: Bulk Resubmit Script

#### Purpose

Provide a simple way to delete and resubmit multiple traits at once when:
1. **Mount failures don't trigger exit code 2** - The `mountpoint` check in entrypoint.sh doesn't catch all mount issues
2. **Manual intervention is needed** - User identifies failed jobs that should be retried
3. **Quick recovery is needed** - Bypass retry script's mount detection logic

#### Architecture

```
┌──────────────────┐
│ User Input:      │
│ Trait Indices    │
│ (37 50 61...)    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Load .env        │
│ (PROJECT,        │
│  JOB_PREFIX)     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Show Summary     │
│ & Confirm        │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────┐
│ For each trait:                  │
│   1. Delete job (ignore errors)  │
│   2. Set START_TRAIT=END_TRAIT   │
│   3. Call submission script      │
│   4. Sleep 2s                    │
└──────────────────────────────────┘
```

#### Implementation

**File**: `scripts/bulk-resubmit-traits.sh`

**Input**:
- Command-line arguments: list of trait indices (e.g., `37 50 61`)
- Configuration from `.env`: PROJECT, JOB_PREFIX

**Process**:
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

TRAITS=("$@")

# Validate input
if [ ${#TRAITS[@]} -eq 0 ]; then
    echo "Usage: $0 <trait1> <trait2> ..."
    exit 1
fi

# Show summary
echo "Will resubmit ${#TRAITS[@]} traits:"
echo "  Project: $PROJECT"
echo "  Job Prefix: $JOB_PREFIX"
echo "  Traits: ${TRAITS[*]}"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

# Delete and resubmit each trait
for trait in "${TRAITS[@]}"; do
    job_name="${JOB_PREFIX}-${trait}"

    echo "[DELETE] $job_name"
    runai workspace delete "$job_name" -p "$PROJECT" 2>/dev/null || echo "  (already deleted or not found)"

    echo "[SUBMIT] Trait $trait"
    (
        export START_TRAIT=$trait
        export END_TRAIT=$trait
        bash "$SCRIPT_DIR/submit-all-traits-runai.sh" <<< "y"
    )

    sleep 2  # Avoid overwhelming cluster
done

echo "Done! Resubmitted ${#TRAITS[@]} traits"
```

**Output**:
- Console logging for each trait (DELETE → SUBMIT)
- Exit code 0 on success, 1 on error

#### Design Rationale

**Why a separate script instead of fixing retry script?**
- Retry script is for **automatic** detection - requires reliable mount detection
- Bulk resubmit is for **manual** intervention - user explicitly lists failed traits
- Separation of concerns: automatic vs manual recovery

**Why delete before resubmit?**
- RunAI doesn't allow duplicate job names
- Delete ensures clean slate (no stuck jobs)
- `2>/dev/null || true` makes it safe if job already deleted

**Why sleep 2 seconds between submissions?**
- Avoids overwhelming RunAI scheduler
- Prevents race conditions in job creation
- Gives each job time to be scheduled before next submission

**Why use submission script instead of direct runai commands?**
- Reuses existing, tested submission logic
- Inherits all configuration and validation
- Ensures consistency with normal batch submissions

#### Usage Examples

**Example 1: Resubmit specific traits**
```bash
bash scripts/bulk-resubmit-traits.sh 37 50 61 66 70 76
```

**Example 2: Get failed traits from runai and resubmit**
```bash
# Get list of failed trait indices
failed_traits=$(runai workspace list -p talmo-lab | \
    grep "eberrigan-gapit-gwas" | \
    grep Failed | \
    awk '{print $1}' | \
    sed 's/eberrigan-gapit-gwas-//')

# Resubmit them
bash scripts/bulk-resubmit-traits.sh $failed_traits
```

**Example 3: Dry-run (show what would be resubmitted)**
```bash
# Not implemented in script, but user can preview by checking:
runai workspace list -p talmo-lab | grep "eberrigan-gapit-gwas" | grep Failed
```

## Technology Choices

### Why Bash Instead of Python/R?

**Decision**: Implement retry script in Bash

**Rationale**:
- Consistency with existing scripts (`submit-all-traits-runai.sh`, `monitor-runai-jobs.sh`)
- Direct access to `runai` CLI without subprocess overhead
- No additional dependencies (Python/R not needed in local environment)
- Simpler deployment (just copy script)

**Trade-offs**:
- More verbose error handling
- Less robust parsing (regex instead of proper JSON parsing)
- Harder to unit test

**Mitigation**: Keep logic simple, use clear variable names, extensive comments

### Why Separate Script Instead of Inline Retry?

**Decision**: Create `retry-failed-traits.sh` instead of adding retry logic to `submit-all-traits-runai.sh`

**Rationale**:
- **Separation of concerns**: Submission and retry are distinct operations
- **Testing**: Easier to test retry independently
- **User control**: User can run retry at any time, not just during submission
- **Simplicity**: Submission script remains focused on initial submission
- **Risk reduction**: Changes are additive, not modifying critical path

**Trade-offs**:
- User must run two commands for full workflow
- Slight code duplication (both scripts call `runai workspace submit`)

**Mitigation**: Document workflow clearly, provide examples in help text

### Why Exponential Backoff?

**Decision**: Use exponential backoff (30s, 60s, 120s) between retry attempts

**Rationale**:
- **Reduces node pressure**: Gives infrastructure time to recover
- **Industry standard**: Well-established pattern for retry logic
- **Prevents thundering herd**: Multiple retries don't all hit cluster at once

**Alternative considered**: Fixed 30s delay
**Rejected because**: Doesn't give infrastructure time to recover if problem is persistent

## Performance Considerations

### Concurrency Control Fix Impact

**Before fix**:
- Submission rate: ~2 seconds between jobs (36 jobs in ~72 seconds)
- First WAIT occurs after job 37
- Jobs can exceed MAX_CONCURRENT during state transitions

**After fix**:
- Submission rate: Same (~2 seconds between jobs)
- First WAIT occurs when actual batch jobs hit MAX_CONCURRENT
- No overshoot beyond MAX_CONCURRENT

**Performance impact**: Negligible (extra grep operation adds <10ms)

**Cluster impact**: Positive (better distribution, less node overload)

### Retry Script Performance

**Per-job overhead**:
- List jobs: ~500ms
- Get logs: ~1-2 seconds
- Delete job: ~500ms
- Resubmit job: ~2-3 seconds
- **Total per retry: ~5-10 seconds**

**For 10 failed jobs**:
- Sequential retry: ~50-100 seconds + backoff delays
- With 3 retries max: ~3-5 minutes total

**Optimization opportunity** (future): Parallel retry of multiple jobs

## Security Considerations

### Access Control

**Assumption**: User has RunAI project access (`talmo-lab`)

**Required permissions**:
- `runai workspace list` (read access)
- `runai workspace logs` (read access)
- `runai workspace delete` (write access)
- `runai workspace submit` (write access)

**Risk**: User could delete other users' jobs if job name collision

**Mitigation**: Job prefix filtering ensures only batch jobs are affected

### Input Validation

**User-controlled inputs**:
- `$PROJECT` (from .env)
- `$JOB_PREFIX` (from .env)
- `$MAX_RETRIES` (command-line flag)

**Validation**:
```bash
# Validate MAX_RETRIES is numeric
if ! [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]]; then
    echo "Error: --max-retries must be a number"
    exit 2
fi

# Validate MAX_RETRIES is reasonable (1-10)
if [ "$MAX_RETRIES" -lt 1 ] || [ "$MAX_RETRIES" -gt 10 ]; then
    echo "Error: --max-retries must be between 1 and 10"
    exit 2
fi
```

## Testing Strategy

### Unit Testing (Concurrency Fix)

**Test 1: Job Prefix Filtering**
```bash
# Mock runai output with mixed job names
echo "
gapit3-trait-2    Running   ...
gapit3-trait-3    Pending   ...
other-job-1       Running   ...
gapit3-trait-4    Running   ...
" | grep "^[[:space:]]*gapit3-trait-" | wc -l
# Expected: 3
```

**Test 2: Active State Counting**
```bash
# Mock runai output with various states
echo "
gapit3-trait-2    Running      ...
gapit3-trait-3    Pending      ...
gapit3-trait-4    Succeeded    ...
gapit3-trait-5    Failed       ...
gapit3-trait-6    ContainerCreating ...
" | grep "^[[:space:]]*gapit3-trait-" | grep -vE "Succeeded|Failed|Completed" | wc -l
# Expected: 3 (Running, Pending, ContainerCreating)
```

### Integration Testing (Retry Script)

**Test 1: Detect Mount Failures**
```bash
# Submit a job designed to fail with mount error
# (modify hostpath to non-existent directory)
runai workspace submit test-mount-fail --host-path path=/nonexistent,mount=/data ...

# Wait for failure
sleep 60

# Run retry script in dry-run mode
./scripts/retry-failed-traits.sh --dry-run

# Verify: Script identifies the job as mount failure
# Expected output: "Would retry test-mount-fail (mount failure detected)"
```

**Test 2: Skip Configuration Errors**
```bash
# Submit a job designed to fail with configuration error
# (set PHENOTYPE_FILE to non-existent file)
runai workspace submit test-config-fail --environment PHENOTYPE_FILE=/invalid ...

# Run retry script in dry-run mode
./scripts/retry-failed-traits.sh --dry-run

# Verify: Script skips the job
# Expected output: "Skipping test-config-fail (not a mount failure)"
```

**Test 3: Actual Retry**
```bash
# Submit job with mount failure
# Run retry script (not dry-run)
./scripts/retry-failed-traits.sh

# Verify:
# 1. Old job deleted
# 2. New job submitted
# 3. New job succeeds (hopefully on different node)
```

### End-to-End Testing

**Scenario**: Submit 20 jobs, intentionally cause 5 mount failures, verify retry recovers all

```bash
# 1. Set MAX_CONCURRENT=10 in .env
# 2. Submit 20 traits
./scripts/submit-all-traits-runai.sh

# 3. Monitor - should see exactly 10 active at a time (fixed concurrency bug)
watch -n 5 'runai workspace list | grep gapit3-trait | grep -vE "Succeeded|Failed" | wc -l'

# 4. Simulate mount failures (kill 5 random jobs mid-execution)
for i in 5 8 12 15 18; do
    runai workspace delete gapit3-trait-$i -p talmo-lab
done

# 5. Run retry script
./scripts/retry-failed-traits.sh

# 6. Verify all 20 jobs eventually succeed
runai workspace list | grep gapit3-trait | grep Succeeded | wc -l
# Expected: 20
```

### Automated CI Testing

**Objective**: Validate bash script logic on every push/PR without requiring RunAI cluster access.

#### Unit Test Script: `tests/unit/test-retry-script.sh`

**Pattern**: Follows same structure as existing `tests/integration/test-env-vars-e2e.sh`

**Test Coverage**:
1. **Syntax Validation**: `bash -n scripts/retry-failed-traits.sh`
2. **Help Flag**: `--help` displays usage correctly
3. **Trait Index Extraction**:
   ```bash
   job_name="eberrigan-gapit-gwas-42"
   trait_idx=$(echo "$job_name" | sed "s/^eberrigan-gapit-gwas-//")
   assert_equals "$trait_idx" "42"
   ```
4. **Mount Failure Detection Pattern**:
   ```bash
   logs="[ERROR] INFRASTRUCTURE MOUNT FAILURE"
   echo "$logs" | grep -qi "INFRASTRUCTURE MOUNT FAILURE"
   assert_exit_code "$?" 0 "Detect mount failure"
   ```
5. **Job Prefix Filtering**:
   ```bash
   job_list="  gapit3-trait-2    Running
   other-job-1       Running
   gapit3-trait-3    Pending"
   count=$(echo "$job_list" | grep "^[[:space:]]*gapit3-trait-" | wc -l)
   assert_equals "$count" "2"
   ```
6. **Exponential Backoff Calculation**:
   ```bash
   delay=$((30 * 2**1))  # 60s for 2nd retry
   assert_equals "$delay" "60"
   ```
7. **Flag Parsing**: `--dry-run`, `--max-retries N`, `--retry-delay N`
8. **Required Tools**: Verify `grep`, `awk`, `sed`, `wc` available

**Test Helpers** (reuse pattern from integration tests):
```bash
assert_equals()     # Compare exact string values
assert_contains()   # Check if output contains string
assert_exit_code()  # Verify exit codes
log_info/warn/error # Colored logging
```

#### GitHub Actions Workflow: `.github/workflows/test-bash-scripts.yml`

**Triggers**:
- Push to `main` branch (paths: `scripts/**/*.sh`, `tests/**`)
- All pull requests (paths: `scripts/**/*.sh`, `tests/**`)
- Manual dispatch (`workflow_dispatch`)

**Jobs**:
```yaml
jobs:
  test-bash-scripts:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Make test scripts executable
        run: chmod +x tests/unit/*.sh

      - name: Run retry script unit tests
        run: bash tests/unit/test-retry-script.sh

      - name: Test retry script syntax
        run: bash -n scripts/retry-failed-traits.sh

      - name: Test submission script syntax
        run: bash -n scripts/submit-all-traits-runai.sh

      - name: Test summary
        if: always()
        run: |
          echo "### Bash Script Tests :shell:" >> $GITHUB_STEP_SUMMARY
          echo "**Status:** ${{ job.status }}" >> $GITHUB_STEP_SUMMARY
          echo "**Tested Components:**" >> $GITHUB_STEP_SUMMARY
          echo "- Retry script syntax validation" >> $GITHUB_STEP_SUMMARY
          echo "- Trait index extraction logic" >> $GITHUB_STEP_SUMMARY
          echo "- Mount failure detection patterns" >> $GITHUB_STEP_SUMMARY
          echo "- Job prefix filtering" >> $GITHUB_STEP_SUMMARY
          echo "- Exponential backoff calculation" >> $GITHUB_STEP_SUMMARY
          echo "- Command-line flag parsing" >> $GITHUB_STEP_SUMMARY
```

**Integration with Existing Workflows**:
- Runs in parallel with `test-r-scripts.yml` and `test-devcontainer.yml`
- Uses same versioned actions (`actions/checkout@v5`)
- Follows same summary reporting pattern (`$GITHUB_STEP_SUMMARY`)
- PR checks require all workflows to pass before merge

**Benefits**:
- Catches syntax errors before deployment
- Validates logic changes don't break regex patterns
- No RunAI cluster required for testing
- Fast feedback (<1 minute runtime)
- Prevents regressions in critical retry logic

## Deployment Plan

### Phase 1: Concurrency Fix (Week 1, Day 1-2)

**Steps**:
1. Create feature branch: `fix/concurrency-control`
2. Update `scripts/submit-all-traits-runai.sh`
3. Run unit tests locally
4. Test with small batch (5 jobs, MAX_CONCURRENT=2)
5. Create PR, get review
6. Merge to main
7. Tag version: `v1.2.0-concurrency-fix`

**Rollback plan**: Revert commit if issues found

### Phase 2: Retry Script (Week 1, Day 3-5)

**Steps**:
1. Create feature branch: `feat/mount-failure-retry`
2. Create `scripts/retry-failed-traits.sh`
3. Test in dry-run mode
4. Test actual retry with mock failures
5. Create PR, get review
6. Merge to main
7. Tag version: `v1.3.0-retry-logic`

**Rollback plan**: Delete script if issues found (no impact on existing functionality)

### Phase 3: Documentation (Week 2)

**Steps**:
1. Update `docs/RUNAI_QUICK_REFERENCE.md`
2. Update `docs/DEPLOYMENT_TESTING.md`
3. Add troubleshooting section
4. Update README with retry workflow

## Monitoring and Observability

### Metrics to Track

**Concurrency Control**:
- Average active jobs during submission
- Max active jobs observed
- Time spent in WAIT state
- Submission completion time

**Retry Logic**:
- Number of mount failures per batch
- Retry success rate (% of retries that succeed)
- Average retries per failed job
- Time to recovery (failure → successful retry)

### Logging

**Concurrency Control**:
```bash
[WAIT] 50 active jobs in batch (max: 50). Waiting 30s...
```

**Retry Script**:
```bash
[INFO] Found 5 failed jobs
[INFO] Analyzing: gapit3-trait-37
  → Mount failure detected
[INFO] Deleting failed job...
[INFO] Resubmitting trait 37 (attempt 1/3)...
[SUCCESS] Trait 37 resubmitted successfully
```

## Future Enhancements

### Short-term (Next Quarter)

1. **Retry count persistence**: Store retry count in job labels or external file
2. **Parallel retry**: Retry multiple jobs concurrently (respecting MAX_CONCURRENT)
3. **Retry statistics**: Collect metrics on retry patterns for capacity planning

### Long-term (Future Releases)

1. **Automatic concurrency tuning**: Adjust MAX_CONCURRENT based on cluster health
2. **Node affinity rules**: Distribute jobs to avoid node overload
3. **Mount optimization**: Use shared mounts instead of per-job hostPath
4. **Intelligent retry backoff**: Adjust delays based on cluster load
