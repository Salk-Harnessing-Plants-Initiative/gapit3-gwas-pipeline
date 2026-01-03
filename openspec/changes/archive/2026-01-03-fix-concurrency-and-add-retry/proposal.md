# Proposal: Fix Concurrency Control and Add Mount Failure Retry

## Problem Statement

The RunAI batch submission script (`submit-all-traits-runai.sh`) has a critical concurrency control bug that allows it to submit more jobs than the configured `MAX_CONCURRENT` limit. This happens because the script counts ALL jobs in the entire shared project, not just jobs from the current batch. Additionally, when jobs fail due to transient infrastructure issues (mount failures), there is no automatic retry mechanism, requiring manual intervention.

### Root Cause Analysis

**Bug #1: Project-Wide Job Counting**
```bash
# Current code (Line 201)
RUNNING=$(runai workspace list -p $PROJECT | grep -c "Running")
```

This counts:
- The user's current batch jobs (e.g., `eberrigan-gapit-gwas-*`)
- Other users' jobs in the shared `talmo-lab` project
- The user's other experiments with different prefixes
- Any leftover jobs from previous runs

**Result**: With `MAX_CONCURRENT=50`, the script saw "51 Running jobs" and started waiting, even though only ~18 were from the current batch. The script never actually limited its OWN concurrency.

**Bug #2: Only Counts "Running" State**

The script only counts jobs in "Running" state, ignoring:
- "Pending" (waiting for resources)
- "ContainerCreating" (pulling image, mounting volumes)
- "Starting" (initializing)

**Result**: The script can submit 50 jobs, all go to "Pending", then submit 50 more, leading to 100+ total active jobs overwhelming the cluster scheduler and causing mount table exhaustion on nodes.

### Real-World Impact

**Actual incident**:
1. User submitted 186 traits with `MAX_CONCURRENT=50`
2. Script counted 51 "Running" jobs in project (33 from other users + 18 from this batch)
3. Script submitted jobs 2-37 rapidly
4. Job 37 was scheduled to `gpu-node5`
5. By the time job 37 tried to mount volumes, `gpu-node5` had exhausted its mount table
6. Mount failed → job failed immediately with "files not found"
7. User had to manually investigate, identify mount failures, and retry

**Problems caused by these bugs:**
- **Resource waste**: Jobs fail due to node overload, wasting compute time
- **Unpredictable behavior**: `MAX_CONCURRENT` parameter doesn't work as expected
- **Manual intervention**: Failed jobs require manual identification and resubmission
- **Cluster interference**: User's batches interfere with each other and other users
- **Infrastructure stress**: Excessive concurrent jobs cause mount table exhaustion, NFS saturation

### Configuration Impact

With the current bugs:
```bash
# User sets in .env:
MAX_CONCURRENT=50

# What user expects:
# "No more than 50 of MY jobs will be active at once"

# What actually happens:
# "Wait until the ENTIRE PROJECT has fewer than 50 jobs in 'Running' state"
# Meanwhile, my batch can have 50 Running + 50 Pending + 50 more Pending = 150 active
```

## Proposed Solution

### Part 1: Fix Concurrency Control (Essential)

**Change 1: Add Job Prefix Filtering**

Filter to only count jobs from the current batch before counting states:

```bash
# Before (WRONG):
RUNNING=$(runai workspace list -p $PROJECT | grep -c "Running")

# After (CORRECT):
ACTIVE=$(runai workspace list -p $PROJECT | \
    grep "^[[:space:]]*$JOB_PREFIX-" | \
    grep -vE "Succeeded|Failed|Completed" | \
    wc -l)
```

**Change 2: Count All Active States**

Instead of only counting "Running", count all non-terminal states (Running + Pending + ContainerCreating + Starting):

```bash
# Count everything EXCEPT terminal states
grep -vE "Succeeded|Failed|Completed"
```

**Rationale**:
- When users set `MAX_CONCURRENT=50`, they mean "no more than 50 jobs in flight"
- Prevents queue saturation (50 running + 50 pending = 100 total)
- Better models actual cluster load
- Safer for mount table exhaustion

### Part 2: Add Mount Failure Retry (High Value)

**Problem**: Mount failures are transient infrastructure issues (node overload, NFS timeout, mount race conditions) but require manual retry.

**Solution**: Create a companion script `retry-failed-traits.sh` that:

1. **Identifies failed jobs** with mount errors (exit code 2 from entrypoint.sh)
2. **Deletes failed job** from RunAI
3. **Resubmits the trait** using the same submission logic
4. **Limits retries** to 3 attempts with exponential backoff
5. **Reports results** (succeeded, failed, skipped)

**Why a separate script?**
- **Separation of concerns**: Submission and retry are distinct operations
- **Simpler to test**: Can test retry logic independently
- **User control**: User decides when to retry (immediate vs wait for batch completion)
- **Lower risk**: Doesn't modify the core submission script
- **Easier to maintain**: Clear boundaries between features

## Benefits

### Immediate Benefits (Part 1)

1. **Correctness**: `MAX_CONCURRENT` now means what users expect
2. **Isolation**: User's batches don't interfere with each other or other users
3. **Predictability**: Job submission rate is consistent and controllable
4. **Better node distribution**: Slower submission gives scheduler time to spread jobs
5. **Reduced mount pressure**: Fewer concurrent mounts per node on average

### User Experience Benefits (Part 2)

1. **Automatic recovery**: Transient mount failures are retried without user intervention
2. **Reduced manual work**: No need to identify and manually resubmit failed jobs
3. **Better reliability**: Batch completions are more likely with automatic retry
4. **Clear visibility**: User sees which jobs were retried and why

### Infrastructure Benefits (Both Parts)

1. **Lower cluster load**: Proper concurrency prevents scheduler overload
2. **Better resource utilization**: Jobs spread more evenly across nodes
3. **Fewer mount failures**: Reduced concurrent mounts per node
4. **Easier capacity planning**: Predictable load from batch submissions

## Scope

### In Scope

**Part 1: Concurrency Control Fix**
- ✅ Fix job counting in `submit-all-traits-runai.sh` (lines 201, 207)
- ✅ Update wait loop messages to reflect new behavior
- ✅ Add comments explaining counting logic
- ✅ Update variable names (`RUNNING` → `ACTIVE`)

**Part 2: Mount Failure Retry**
- ✅ Create new script: `scripts/retry-failed-traits.sh`
- ✅ Implement mount failure detection (check for exit code 2)
- ✅ Add retry logic with configurable max retries (default: 3)
- ✅ Add exponential backoff between retries (30s, 60s, 120s)
- ✅ Add dry-run mode for safe testing
- ✅ Add detailed logging and statistics

### Out of Scope

- ❌ Inline retry logic in submission script (too complex, mixing concerns)
- ❌ Retry for non-mount failures (configuration errors should not be retried)
- ❌ Node affinity rules (infrastructure-level change, separate concern)
- ❌ Mount optimization (architectural change, requires cluster admin)
- ❌ Automatic concurrency tuning (future enhancement)

## Implementation Strategy

### Phase 1: Fix Concurrency Control (Week 1)

**Priority**: P0 (Critical Bug Fix)

**Changes**:
1. Update `scripts/submit-all-traits-runai.sh` lines 200-208
2. Change variable name from `RUNNING` to `ACTIVE`
3. Add job prefix filter: `grep "^[[:space:]]*$JOB_PREFIX-"`
4. Change state counting: `grep -vE "Succeeded|Failed|Completed"`
5. Update log messages
6. Add inline comments

**Testing**:
- Unit test: Verify job prefix filtering works
- Integration test: Submit 10 jobs, verify max 5 concurrent (if `MAX_CONCURRENT=5`)
- Regression test: Ensure existing batches still work

**Risk**: Low (simple grep change)
**Time**: 2-4 hours

### Phase 2: Add Retry Script (Week 1-2)

**Priority**: P1 (High Value)

**Changes**:
1. Create `scripts/retry-failed-traits.sh` (new file)
2. Implement failed job detection
3. Implement exit code checking
4. Implement retry logic with exponential backoff
5. Add dry-run mode
6. Add help text and usage examples

**Testing**:
- Unit test: Mock failed jobs and verify retry logic
- Integration test: Submit job designed to fail, verify retry works
- End-to-end test: Run full batch, intentionally fail some jobs, run retry script

**Risk**: Medium (new feature, needs careful testing)
**Time**: 6-8 hours

### Phase 3: Documentation (Week 2)

**Priority**: P2 (Documentation)

**Changes**:
1. Update `docs/RUNAI_QUICK_REFERENCE.md` with concurrency explanation
2. Update `docs/DEPLOYMENT_TESTING.md` with retry workflow
3. Add troubleshooting section for mount failures
4. Update script help text

**Time**: 2-3 hours

## Success Criteria

### Part 1: Concurrency Control

**Functional**:
- [ ] Script only counts jobs with matching `$JOB_PREFIX`
- [ ] Script counts all active states (not just "Running")
- [ ] `MAX_CONCURRENT=5` actually limits batch to 5 active jobs
- [ ] Waits correctly when at limit
- [ ] Resumes submission when jobs complete

**Performance**:
- [ ] No measurable performance regression
- [ ] Submission rate is smooth and predictable

**User Experience**:
- [ ] Log messages clearly indicate "active jobs in batch"
- [ ] No confusing behavior when other users have jobs running

### Part 2: Mount Failure Retry

**Functional**:
- [ ] Detects mount failures (exit code 2) correctly
- [ ] Skips non-mount failures (exit code 1)
- [ ] Retries up to 3 times with exponential backoff
- [ ] Dry-run mode shows what would be retried without actually retrying
- [ ] Reports statistics (retried, succeeded, failed)

**Reliability**:
- [ ] Handles edge cases (no failed jobs, all jobs failed, script interruption)
- [ ] Doesn't retry indefinitely
- [ ] Doesn't retry configuration errors

**User Experience**:
- [ ] Clear logging of retry attempts
- [ ] Easy to understand output
- [ ] Help text is comprehensive

## Risks and Mitigation

### Risk 1: Concurrency Fix Too Conservative

**Risk**: Counting all active states might prevent submission when cluster could handle more.

**Mitigation**:
- This is the correct behavior - users want `MAX_CONCURRENT` to mean total active work
- Users can increase `MAX_CONCURRENT` if they want more aggressive submission
- Document the new semantics clearly

**Likelihood**: Low
**Impact**: Low (user can adjust `MAX_CONCURRENT`)

### Risk 2: Retry Script Causes Infinite Loops

**Risk**: Bug in retry logic causes jobs to retry forever.

**Mitigation**:
- Hard-coded max retry limit (3)
- Exit codes distinguish retryable (2) from non-retryable (1) failures
- Dry-run mode for safe testing
- Clear logging of retry attempts

**Likelihood**: Low
**Impact**: Medium (would waste resources)

### Risk 3: Race Conditions in Job State Detection

**Risk**: Job state changes between detection and action.

**Mitigation**:
- Check job state again before retrying
- Handle "job not found" gracefully
- Use exponential backoff to reduce race window

**Likelihood**: Low
**Impact**: Low (graceful degradation)

## Alternative Approaches Considered

### Alternative 1: Inline Retry in Submission Script

**Pros**: All logic in one place
**Cons**:
- Mixes concerns (submission + retry)
- Harder to test
- More complex error handling
- Can't retry after batch completes

**Decision**: Rejected in favor of separate script

### Alternative 2: Only Count "Running" + "ContainerCreating"

**Pros**: Less conservative than counting all active
**Cons**: Still allows unlimited "Pending" jobs, doesn't fully solve problem

**Decision**: Rejected - count all non-terminal states for completeness

### Alternative 3: Automatic Retry in Entrypoint

**Pros**: Jobs retry themselves
**Cons**:
- Can't distinguish first attempt from retry
- No global retry limit
- Complex state management in container
- Hard to debug

**Decision**: Rejected - retry at orchestration layer is cleaner

## Related Work

### Prerequisites
- ✅ `scripts/entrypoint.sh` already distinguishes mount failures (exit code 2) - **Completed**
- ✅ `scripts/validate-env.sh` validates configuration pre-flight - **Completed**

### Follow-up Work (Future)
- Node affinity rules to distribute jobs evenly
- Mount optimization (shared mounts vs per-job hostPath)
- Automatic concurrency tuning based on cluster health
- Integration with monitoring/alerting

## References

- Issue: Job 37 mount failure investigation
- Planning analysis: Plan agent comprehensive report (this session)
- Related changes: `add-env-validation-and-dry-run` (validation infrastructure)
