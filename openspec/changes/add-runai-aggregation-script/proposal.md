# Proposal: Add RunAI Aggregation Script

## Problem Statement

When running GAPIT3 GWAS analysis via manual RunAI CLI execution (the current workaround for RBAC permissions), users must run all 186 traits individually using `scripts/submit-all-traits-runai.sh`. Each trait produces results in isolated directories (`trait_002_*/`, `trait_003_*/`, etc.), but there is **no automatic aggregation** of results.

In contrast, the Argo Workflows approach automatically runs a `collect-results` step after all traits complete, which:
- Creates `aggregated_results/summary_table.csv` - Summary of all traits
- Creates `aggregated_results/significant_snps.csv` - SNPs with p < 5e-8
- Creates `aggregated_results/summary_stats.json` - Overall statistics

**Current Workaround**: Users must manually run `Rscript scripts/collect_results.R` after all jobs complete, which requires:
1. Monitoring when all 186 RunAI jobs finish
2. Remembering to run the aggregation command
3. Specifying correct parameters (output directory, batch ID)

**Impact**:
- Users may forget to aggregate results
- No easy way to track overall pipeline completion
- Manual process is error-prone
- Documentation mentions aggregation but doesn't provide convenient tooling

## Proposed Solution

Create a new script `scripts/aggregate-runai-results.sh` that:

1. **Monitors RunAI job completion** - Waits for all `gapit3-trait-*` jobs to finish (Succeeded or Failed status)
2. **Automatically triggers aggregation** - Runs `collect_results.R` when all jobs complete
3. **Provides progress feedback** - Shows live status of pending jobs
4. **Handles edge cases**:
   - Some traits failed (still aggregates successful ones)
   - Jobs already completed when script starts (runs immediately)
   - User interrupt (allows graceful exit)

### User Experience

**Simple invocation**:
```bash
# After submitting all traits via submit-all-traits-runai.sh:
./scripts/aggregate-runai-results.sh
```

**What it does**:
1. Detects all `gapit3-trait-*` jobs in RunAI project
2. Shows progress: "152 completed, 34 running, 0 failed"
3. Waits until all jobs finish
4. Automatically runs `Rscript scripts/collect_results.R`
5. Reports aggregation completion

**Advanced usage**:
```bash
# Specify custom output path and batch ID
./scripts/aggregate-runai-results.sh \
  --output-dir /custom/path/outputs \
  --batch-id "manual-runai-20251107"

# Check status only (no waiting)
./scripts/aggregate-runai-results.sh --check-only

# Run aggregation immediately (skip waiting)
./scripts/aggregate-runai-results.sh --force
```

## Scope

**In Scope**:
- New bash script: `scripts/aggregate-runai-results.sh`
- Integration with existing `collect_results.R` (no changes needed)
- Documentation updates:
  - `docs/MANUAL_RUNAI_EXECUTION.md` - Add aggregation section
  - `docs/RUNAI_QUICK_REFERENCE.md` - Add command reference
  - `scripts/submit-all-traits-runai.sh` output - Add reminder message
- Testing: Manual validation on cluster

**Out of Scope**:
- Modifications to `collect_results.R` (works as-is)
- Automatic submission + aggregation in one command (separate concern)
- Email/Slack notifications (future enhancement)
- Integration with Argo workflows (already has aggregation)

## Alternatives Considered

### Alternative 1: Manual Instructions Only
**Approach**: Just document that users should run `Rscript scripts/collect_results.R` manually

**Pros**:
- No new code
- Maximum flexibility

**Cons**:
- Easy to forget
- Requires manual monitoring
- Error-prone parameter specification
- Poor user experience

**Decision**: Rejected - tooling significantly improves UX

### Alternative 2: Add Aggregation Flag to submit-all-traits-runai.sh
**Approach**: Add `--aggregate` flag to submission script that blocks until completion then aggregates

**Pros**:
- Single command for submit + aggregate
- Simpler for users

**Cons**:
- Long-running process (hours)
- Terminal must stay open
- Mixing submission and post-processing concerns
- Less flexible (can't aggregate existing runs)

**Decision**: Rejected - separate scripts follow Unix philosophy (do one thing well)

### Alternative 3: Periodic Check Cron Job
**Approach**: Cron job that periodically checks for completed runs and aggregates automatically

**Pros**:
- Fully automatic
- No user action needed

**Cons**:
- Requires cluster/server access to setup cron
- Hidden behavior (users don't know when aggregation runs)
- Complex deployment
- Overlapping executions possible

**Decision**: Rejected - too complex for current needs

## Dependencies

- Existing: `scripts/collect_results.R` (no changes)
- Existing: `runai` CLI installed and authenticated
- Existing: RunAI workspace naming convention: `gapit3-trait-{INDEX}`

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| RunAI CLI output format changes | Low | Medium | Use stable `runai workspace list` output, test with version detection |
| Long wait times frustrate users | Medium | Low | Provide `--check-only` flag, show progress every 30s |
| Script doesn't detect all jobs | Low | High | Pattern match `gapit3-trait-*`, count against expected 186 |
| Jobs stuck in "Running" forever | Medium | Medium | Add `--force` flag to skip waiting |

## Success Criteria

1. ✅ Script successfully waits for all 186 jobs to complete
2. ✅ Script runs `collect_results.R` automatically after completion
3. ✅ Aggregated results created in correct location
4. ✅ Works with partial runs (e.g., only traits 2-50)
5. ✅ Documentation updated with examples
6. ✅ User feedback: "Makes aggregation much easier"

## Timeline Estimate

- Script implementation: 2-3 hours
- Testing on cluster: 1 hour (submit small trait batch)
- Documentation updates: 1 hour
- **Total**: ~4-5 hours

## Open Questions

1. **Should we support filtering by trait range?**
   - Example: `--start 2 --end 50` to only aggregate traits 2-50
   - **Decision**: Yes, add `--start-trait` and `--end-trait` flags

2. **What if some jobs failed?**
   - Should we still aggregate successful ones?
   - **Decision**: Yes, `collect_results.R` already handles this (skips failed traits)

3. **Should we clean up completed RunAI workspaces after aggregation?**
   - Pros: Cluster hygiene
   - Cons: Users may want to inspect logs
   - **Decision**: No - provide separate cleanup script reference

4. **Should the script send notifications when complete?**
   - Email, Slack, etc.
   - **Decision**: Out of scope for initial version - add in future if requested
