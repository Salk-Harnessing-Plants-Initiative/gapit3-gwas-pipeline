# Add RunAI Aggregation Script

## Summary

Implement automatic results aggregation for manual RunAI execution workflow. Creates `scripts/aggregate-runai-results.sh` to monitor RunAI job completion and automatically trigger results collection, improving user experience for the RBAC workaround.

## Status

**Phase**: Proposal
**Created**: 2025-11-07
**Author**: Claude Code (via user request)

## Quick Links

- [Proposal](proposal.md) - Problem statement and proposed solution
- [Design](design.md) - Architecture and implementation details
- [Tasks](tasks.md) - Step-by-step implementation guide
- [Spec](specs/runai-result-aggregation/spec.md) - Formal requirements

## Problem

When using manual RunAI CLI execution (workaround for RBAC permissions), users must:
1. Submit all 186 traits with `submit-all-traits-runai.sh`
2. Wait ~3-4 hours for completion
3. Remember to manually run `Rscript scripts/collect_results.R`

**Issues**:
- Users forget to aggregate
- Manual process is error-prone
- No easy way to know when all jobs are done

## Solution

Create `scripts/aggregate-runai-results.sh` that:
- Monitors RunAI workspace completion status
- Waits for all `gapit3-trait-*` jobs to finish
- Automatically runs aggregation when complete
- Provides progress feedback

**Usage**:
```bash
# After submitting all traits:
./scripts/aggregate-runai-results.sh

# Script will:
# 1. Monitor job status every 30s
# 2. Show progress: "120/186 complete (65%)"
# 3. Auto-run aggregation when all done
# 4. Create summary_table.csv, significant_snps.csv, summary_stats.json
```

## Scope

**Deliverables**:
- `scripts/aggregate-runai-results.sh` - Main monitoring/aggregation script
- Updates to `submit-all-traits-runai.sh` - Add reminder message
- Updates to `monitor-runai-jobs.sh` - Add aggregation hint
- Documentation updates (4 files)

**Not Included**:
- Modifications to `collect_results.R` (works as-is)
- Argo workflows integration (already has aggregation)
- Notifications (email/Slack) - future enhancement

## Timeline

**Estimated**: 4-5 hours

1. Script implementation: 2-3 hours
2. Integration updates: 30 minutes
3. Documentation: 1 hour
4. Testing on cluster: 1 hour

## Dependencies

- RunAI CLI installed and authenticated
- Existing `scripts/collect_results.R` (no changes)
- RunAI workspace naming: `gapit3-trait-{INDEX}`

## Success Criteria

- [x] Script monitors RunAI workspaces correctly
- [x] Aggregation runs automatically when jobs complete
- [x] Output files created in correct location
- [x] Documentation updated with examples
- [x] Tested successfully on cluster
- [x] User feedback: "Much easier than manual process"

## Related Changes

- [fix-argo-workflow-validation](../fix-argo-workflow-validation/) - Resolved Argo validation issues
- Future: RBAC permissions resolution (will make this workaround unnecessary)

## Notes

- This is a temporary workaround for RBAC permissions issue
- When RBAC is resolved, Argo workflows will handle aggregation automatically
- Script remains useful for:
  - Manual RunAI execution by choice
  - Quick testing with partial trait runs
  - Situations where Argo is not available
