# Proposal: Add Cleanup Helper Script

## Problem Statement

When running the GAPIT3 GWAS pipeline via manual RunAI execution, users need to manage workspace and output file cleanup manually. This is tedious, error-prone, and lacks safety checks.

### Current Pain Points

1. **Starting fresh runs**: Users must manually delete 186 RunAI workspaces one-by-one or write ad-hoc scripts
2. **Rerunning failed traits**: No easy way to clean up only specific failed traits
3. **Testing workflow**: After testing with 3 traits, users must remember to clean up before production run
4. **Risk of accidents**: No confirmation prompts or dry-run mode for manual deletion commands
5. **Incomplete cleanup**: Easy to forget output files or aggregated results

### Real-World Scenario

```bash
# User wants to test pipeline
START_TRAIT=2 END_TRAIT=4 ./scripts/submit-all-traits-runai.sh
# ... wait for completion, verify results ...

# Now wants to run full dataset, but needs to clean up test run
# Current process (manual and error-prone):
runai workspace delete gapit3-trait-2 -p talmo-lab
runai workspace delete gapit3-trait-3 -p talmo-lab
runai workspace delete gapit3-trait-4 -p talmo-lab
rm -rf /hpi/hpi_dev/users/eberrigan/.../outputs/trait_2
rm -rf /hpi/hpi_dev/users/eberrigan/.../outputs/trait_3
rm -rf /hpi/hpi_dev/users/eberrigan/.../outputs/trait_4
rm -rf /hpi/hpi_dev/users/eberrigan/.../outputs/aggregated_results

# What if user forgets a step? Or types wrong trait number?
```

## Proposed Solution

Add `scripts/cleanup-runai.sh` - a safe, interactive helper script for cleaning up RunAI workspaces and output files.

### Key Features

1. **Multiple cleanup modes:**
   - Full cleanup (all traits 2-187)
   - Range cleanup (specific traits)
   - Workspace-only (keep output files)
   - Output-only (keep workspaces)

2. **Safety mechanisms:**
   - Interactive confirmation prompts
   - Dry-run mode to preview changes
   - Force flag for automated workflows
   - Clear summary of what will be deleted

3. **User-friendly:**
   - Colored output (warnings in red/yellow)
   - Progress indicators
   - Summary statistics after completion

### Example Usage

```bash
# Full cleanup with confirmation
$ ./scripts/cleanup-runai.sh --all
WARNING: This will delete ALL RunAI workspaces and output files for traits 2-187
  - 186 RunAI workspaces (if they exist)
  - All files in /outputs/trait_*/
  - All files in /outputs/aggregated_results/

Are you sure? Type 'yes' to confirm: yes

Deleting RunAI workspaces...
  [✓] Deleted gapit3-trait-2
  [✓] Deleted gapit3-trait-3
  ...
  [✓] 156 workspaces deleted, 30 not found

Deleting output files...
  [✓] Deleted /outputs/trait_2/
  [✓] Deleted /outputs/trait_3/
  ...
  [✓] 156 trait directories deleted
  [✓] Deleted /outputs/aggregated_results/

Cleanup complete!

# Dry run to preview
$ ./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4 --dry-run
[DRY RUN] Would delete:
  - RunAI workspaces: gapit3-trait-2, gapit3-trait-3, gapit3-trait-4
  - Output directories: /outputs/trait_2/, /outputs/trait_3/, /outputs/trait_4/
  - Aggregated results: /outputs/aggregated_results/ (if exists)

# Workspaces only (keep outputs for later analysis)
$ ./scripts/cleanup-runai.sh --all --workspaces-only --force
Deleting 186 RunAI workspaces...
Done. Output files preserved.
```

## Alternatives Considered

### Alternative 1: Manual Documentation Only
**Approach**: Document the manual cleanup commands in README

**Pros:**
- No code to maintain
- Users have full control

**Cons:**
- Error-prone (easy to make typos)
- No safety checks
- Tedious for 186 traits
- Users will write their own scripts anyway (inconsistent)

**Decision**: ❌ Rejected - Poor user experience

### Alternative 2: Extend submit-all-traits-runai.sh
**Approach**: Add `--cleanup` flag to submission script

**Pros:**
- Single script to maintain
- Integrated workflow

**Cons:**
- Violates single responsibility principle
- Cleanup is a separate concern from submission
- Makes submission script more complex
- Can't clean up without submitting

**Decision**: ❌ Rejected - Better as separate script

### Alternative 3: Add to aggregate-runai-results.sh
**Approach**: Add `--cleanup-before` flag to aggregation script

**Pros:**
- Cleanup happens before aggregation

**Cons:**
- Cleanup is needed before submission, not just aggregation
- Wrong place in workflow
- Limited use case

**Decision**: ❌ Rejected - Wrong workflow phase

### Alternative 4: Standalone Cleanup Script (CHOSEN)
**Approach**: Dedicated `scripts/cleanup-runai.sh` script

**Pros:**
- ✅ Single responsibility
- ✅ Can be used independently
- ✅ Reusable across different workflows
- ✅ Easy to test and maintain
- ✅ Clear purpose and naming

**Cons:**
- One more script to maintain

**Decision**: ✅ **Selected** - Best separation of concerns

## Implementation Strategy

### Phase 1: Core Functionality
- Implement workspace deletion
- Implement output file deletion
- Add confirmation prompts

### Phase 2: Safety Features
- Add dry-run mode
- Add force flag
- Add progress indicators

### Phase 3: Documentation
- Update MANUAL_RUNAI_EXECUTION.md
- Update RUNAI_QUICK_REFERENCE.md
- Add usage examples

### Phase 4: Testing
- Test with small range (traits 2-4)
- Test dry-run mode
- Test workspace-only and output-only modes
- Test confirmation prompts

## Risks and Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Accidental deletion of all workspaces | High | Require typed confirmation ("yes"), add --force for automation |
| Deleting wrong trait range | Medium | Show preview in dry-run, confirm trait range before deletion |
| Script fails mid-deletion | Low | Make operations idempotent, continue on errors |
| Output path typo leads to wrong deletion | High | Validate path exists, show full paths in confirmation |

## Success Metrics

- Script successfully deletes workspaces and files
- Zero accidental deletions reported
- Users report improved workflow efficiency
- Reduced support questions about "how to clean up"

## Open Questions

1. Should we support trash/recycle bin instead of permanent deletion for output files?
   - **Answer**: Future enhancement, start with direct deletion

2. Should we backup output files before deletion?
   - **Answer**: No, users should backup manually if needed

3. Should we clean up old test workspaces automatically?
   - **Answer**: No, explicit user action is safer

## References

- Similar cleanup patterns in other projects:
  - Kubernetes: `kubectl delete all --all`
  - Docker: `docker system prune`
  - Git: `git clean -fd`
- All provide dry-run modes and confirmation prompts
