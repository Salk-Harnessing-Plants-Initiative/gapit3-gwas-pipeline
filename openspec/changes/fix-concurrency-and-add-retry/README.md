# Change: Fix Concurrency Control and Add Mount Failure Retry

**Status**: Proposed
**Type**: Bug Fix + Feature Addition
**Priority**: P0 (Critical Bug) + P1 (High Value)

## Quick Summary

This change fixes a critical bug where the RunAI submission script counted ALL jobs in the shared project instead of only the current batch's jobs, causing `MAX_CONCURRENT` to not work as expected. It also adds automatic retry logic for transient infrastructure mount failures.

## Problem

The concurrency control bug allowed:
- User's batches to interfere with each other
- Exceeding intended concurrency limits (52 jobs when MAX_CONCURRENT=50)
- Unpredictable behavior based on other users' activity
- Node overload leading to mount failures

Mount failures required manual intervention:
- User had to identify which jobs failed
- Manually resubmit each failed job
- No protection against repeated failures

## Solution

**Part 1**: Fix concurrency control by:
- Filtering jobs by `JOB_PREFIX` before counting
- Counting all active states (not just "Running")
- Clear logging of batch-specific counts

**Part 2**: Add `retry-failed-traits.sh` script that:
- Automatically detects mount failures (exit code 2)
- Retries up to 3 times with exponential backoff
- Skips configuration errors (exit code 1)
- Provides detailed statistics

## Impact

- **User Experience**: MAX_CONCURRENT works as expected, automatic recovery from mount failures
- **Cluster Health**: Better job distribution, reduced node overload
- **Reliability**: Higher batch completion rate with automatic retry

## Files

- **proposal.md**: Detailed problem statement and proposed solution
- **design.md**: Architecture, component design, testing strategy
- **tasks.md**: Ordered implementation tasks with time estimates
- **specs/concurrency-control/spec.md**: Requirements for concurrency fix
- **specs/mount-failure-retry/spec.md**: Requirements for retry script

## Implementation

**Part 1** (2-3 hours): Modify `scripts/submit-all-traits-runai.sh`
- Add job prefix filtering
- Count all active states
- Update variable names and log messages

**Part 2** (6-7 hours): Create `scripts/retry-failed-traits.sh`
- Implement mount failure detection
- Add retry logic with exponential backoff
- Add dry-run mode and statistics

**Part 2.5** (30 min): Create `scripts/bulk-resubmit-traits.sh`
- Manual bulk delete/resubmit for failed traits
- Handles cases where mount detection doesn't trigger

**Part 3** (3 hours): Add CI testing
- Create unit test script: `tests/unit/test-retry-script.sh`
- Create GitHub Actions workflow: `.github/workflows/test-bash-scripts.yml`
- Validate syntax and logic on every push/PR

**Total Effort**: ~15 hours (2 days)

## Testing

**Automated CI Tests** (runs on every push/PR):
- Bash script syntax validation (`bash -n`)
- Unit tests for retry script logic (trait extraction, mount detection, filtering)
- Exponential backoff calculation validation
- Command-line flag parsing tests

**Manual Integration Tests**:
- Unit tests for job filtering and state counting
- Integration tests for concurrency limits
- End-to-end tests for retry logic with real RunAI cluster

**Documentation**:
- Usage guides and troubleshooting
- Inline code comments

## Related Work

**Prerequisites** (already completed):
- `scripts/entrypoint.sh` distinguishes mount failures (exit code 2)
- `scripts/validate-env.sh` validates configuration pre-flight

**Future Work**:
- Node affinity rules for better job distribution
- Mount optimization (shared mounts vs per-job hostPath)
- Automatic concurrency tuning based on cluster health

## Questions?

See individual documents for detailed information:
- Problem details → [proposal.md](proposal.md)
- Technical design → [design.md](design.md)
- Implementation tasks → [tasks.md](tasks.md)
- Requirements → [specs/concurrency-control/spec.md](specs/concurrency-control/spec.md) and [specs/mount-failure-retry/spec.md](specs/mount-failure-retry/spec.md)
