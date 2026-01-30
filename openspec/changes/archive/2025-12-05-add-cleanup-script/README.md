# Add Cleanup Helper Script

## Summary

Add a helper script to clean up RunAI workspaces and output files, making it easy to reset the pipeline for fresh runs with new data or to rerun failed traits.

## Status

**Phase**: Proposal
**Created**: 2025-11-08
**Author**: Claude Code (via user request)

## Quick Links

- [Proposal](proposal.md) - Problem statement and proposed solution
- [Design](design.md) - Architecture and implementation details
- [Tasks](tasks.md) - Step-by-step implementation guide
- [Spec](specs/cleanup-helper/spec.md) - Formal requirements

## Problem

Users need an easy way to:
1. **Start fresh** - Delete all RunAI workspaces and output files before a new run
2. **Rerun specific traits** - Clean up only failed traits to retry them
3. **Clean up after testing** - Remove test runs (e.g., traits 2-4) before production run

**Current workflow is error-prone:**
```bash
# Manual deletion - tedious and easy to miss items
for i in {2..187}; do
    runai workspace delete gapit3-trait-$i -p talmo-lab
done
rm -rf /path/to/outputs/trait_*
rm -rf /path/to/outputs/aggregated_results
```

## Solution

Create `scripts/cleanup-runai.sh` that provides:
- **Full cleanup** - Delete all workspaces and outputs
- **Selective cleanup** - Delete specific trait ranges
- **Workspace-only cleanup** - Keep output files, only delete RunAI workspaces
- **Output-only cleanup** - Keep workspaces, only delete output files
- **Dry-run mode** - Preview what would be deleted

**Usage examples:**
```bash
# Clean everything (interactive confirmation)
./scripts/cleanup-runai.sh --all

# Clean specific trait range
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4

# Clean only workspaces (keep output files)
./scripts/cleanup-runai.sh --all --workspaces-only

# Dry run to see what would be deleted
./scripts/cleanup-runai.sh --all --dry-run

# Force (no confirmation prompt)
./scripts/cleanup-runai.sh --all --force
```

## Scope

**Deliverables:**
- `scripts/cleanup-runai.sh` - Main cleanup script
- Update to `docs/MANUAL_RUNAI_EXECUTION.md` - Add cleanup section
- Update to `docs/RUNAI_QUICK_REFERENCE.md` - Add cleanup commands
- Update to `README.md` - Add to scripts list

**Not Included:**
- Cleanup for Argo Workflows artifacts (different mechanism)
- Backup/restore functionality (future enhancement)

## Timeline

**Estimated**: 2-3 hours

1. Script implementation: 1-2 hours
2. Documentation updates: 30 minutes
3. Testing: 30 minutes

## Dependencies

- RunAI CLI installed and authenticated
- Existing workspace naming convention: `gapit3-trait-{INDEX}`
- Output directory structure: `$OUTPUT_PATH/trait_{INDEX}/`

## Success Criteria

- [x] Script deletes RunAI workspaces correctly
- [x] Script deletes output files correctly
- [x] Confirmation prompt prevents accidental deletion
- [x] Dry-run mode shows accurate preview
- [x] Documentation updated with examples
- [x] Tested successfully on cluster

## Related Changes

- [add-runai-aggregation-script](../add-runai-aggregation-script/) - Complements the execution workflow
- [fix-argo-workflow-validation](../fix-argo-workflow-validation/) - Argo cleanup would be different

## Notes

- This is a convenience script, not required for pipeline functionality
- Users can still manually delete workspaces if preferred
- Workspace deletion is irreversible - hence confirmation prompts
- Output file deletion moves to trash if available (future enhancement)
