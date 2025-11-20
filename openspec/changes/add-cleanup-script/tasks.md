# Tasks: Add Cleanup Helper Script

## Overview

Implement cleanup helper script for RunAI workspaces and output files.

**Estimated Total Time**: 2-3 hours

---

## Task List

### 1. Create cleanup-runai.sh Script (1.5-2 hours)

**Description**: Implement main cleanup script with all features

**Subtasks**:
- [ ] Create `scripts/cleanup-runai.sh` file
- [ ] Add shebang and script header with documentation
- [ ] Implement argument parsing
  - `--all` flag
  - `--start-trait` and `--end-trait`
  - `--workspaces-only` and `--outputs-only`
  - `--dry-run` flag
  - `--force` flag
  - `--help` flag
- [ ] Add argument validation
  - Mutually exclusive checks
  - Range validation
  - Bounds checking (2-187)
- [ ] Implement prerequisite checks
  - Check `runai` CLI available
  - Check `runai whoami` (authentication)
  - Validate output path exists (with warning)
- [ ] Implement resource discovery
  - List existing RunAI workspaces in range
  - List existing output directories in range
  - Check for aggregated_results directory
  - Display counts
- [ ] Implement confirmation logic
  - Display what will be deleted
  - Dry-run mode: show preview and exit
  - Interactive mode: prompt for "yes" confirmation
  - Force mode: skip confirmation
- [ ] Implement workspace deletion
  - Loop through trait range
  - Delete each workspace
  - Track: deleted, not-found, failed counts
  - Add 0.5s delay between deletions
- [ ] Implement output file deletion
  - Delete trait_* directories in range
  - Delete aggregated_results directory
  - Track deleted count
- [ ] Implement summary display
  - Show deletion statistics
  - Report errors if any
  - Suggest next steps
- [ ] Add colored output (GREEN, YELLOW, RED, BLUE, NC)
- [ ] Make script executable: `chmod +x`

**Dependencies**: None

**Validation**:
```bash
# Test help
./scripts/cleanup-runai.sh --help

# Test dry-run
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4 --dry-run

# Test with no resources (should handle gracefully)
./scripts/cleanup-runai.sh --start-trait 999 --end-trait 999
```

---

### 2. Update MANUAL_RUNAI_EXECUTION.md (20 minutes)

**Description**: Add cleanup section to manual execution guide

**Changes**:
- [ ] Add new section: "Cleaning Up Before New Runs"
- [ ] Include basic usage examples
- [ ] Include advanced usage (ranges, modes)
- [ ] Document common scenarios (fresh start, rerun failed, cleanup test)
- [ ] Add to table of contents

**Example content**:
````markdown
### Cleaning Up Before New Runs

Before starting a fresh pipeline run or rerunning failed traits, clean up old resources:

#### Clean Everything (Fresh Start)

```bash
# Preview what will be deleted
./scripts/cleanup-runai.sh --all --dry-run

# Delete all RunAI workspaces and output files
./scripts/cleanup-runai.sh --all
```

#### Clean Specific Traits

```bash
# Clean up test run (traits 2-4)
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4

# Clean up single failed trait
./scripts/cleanup-runai.sh --start-trait 42 --end-trait 42
```

#### Selective Cleanup

```bash
# Only delete RunAI workspaces (keep outputs for analysis)
./scripts/cleanup-runai.sh --all --workspaces-only

# Only delete output files (keep workspaces)
./scripts/cleanup-runai.sh --all --outputs-only
```

#### Automation-Friendly

```bash
# Skip confirmation prompts (for scripts)
./scripts/cleanup-runai.sh --all --force
```
````

**Dependencies**: Task 1 (script must exist)

**Validation**:
- [ ] Review updated docs
- [ ] Verify all examples are accurate
- [ ] Check markdown renders correctly

---

### 3. Update RUNAI_QUICK_REFERENCE.md (10 minutes)

**Description**: Add cleanup commands to quick reference

**Changes**:
- [ ] Add new section: "Cleanup Commands"
- [ ] Include most common use cases
- [ ] Keep examples concise (it's a quick reference)

**Example**:
````markdown
### Cleanup Commands

```bash
# Clean all traits (with confirmation)
./scripts/cleanup-runai.sh --all

# Clean specific range
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 50

# Preview without deleting (dry-run)
./scripts/cleanup-runai.sh --all --dry-run

# Only delete workspaces
./scripts/cleanup-runai.sh --all --workspaces-only

# Force (no confirmation)
./scripts/cleanup-runai.sh --all --force
```
````

**Dependencies**: Task 1

**Validation**:
- [ ] Verify examples match script API
- [ ] Check formatting

---

### 4. Update README.md (5 minutes)

**Description**: Add cleanup script to available scripts list

**Changes**:
- [ ] Add to "Current workarounds available" or "Available Scripts" section
- [ ] Brief description with link

**Example**:
```markdown
**Current workarounds available:**
- ✅ **Manual RunAI CLI** - Working now
- ✅ **Batch submission** - scripts/submit-all-traits-runai.sh
- ✅ **Monitoring dashboard** - scripts/monitor-runai-jobs.sh
- ✅ **Aggregation script** - scripts/aggregate-runai-results.sh
- ✅ **Cleanup helper** - scripts/cleanup-runai.sh (NEW)
- ⏳ **Argo Workflows** - Waiting for RBAC fix
```

**Dependencies**: Task 1

**Validation**:
- [ ] Verify link works
- [ ] Check placement in documentation structure

---

### 5. Update CHANGELOG.md (5 minutes)

**Description**: Document new feature in changelog

**Changes**:
- [ ] Add to `[Unreleased]` section under `### Added`
- [ ] Include brief description

**Example**:
```markdown
## [Unreleased]

### Added
- Cleanup helper script for RunAI execution
  - `scripts/cleanup-runai.sh` - Delete workspaces and output files
  - Supports dry-run mode, selective deletion, trait ranges
  - Interactive confirmation prompts for safety
```

**Dependencies**: Task 1

**Validation**:
- [ ] Follows Keep a Changelog format
- [ ] Accurate description

---

### 6. Test on Cluster (30 minutes)

**Description**: Validate script works end-to-end on cluster

**Test Cases**:

#### Test 1: Dry-run mode
```bash
# Should show preview without deleting anything
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4 --dry-run
```

**Expected**: Shows what would be deleted, exits without changes

#### Test 2: Clean specific range (interactive)
```bash
# Create test workspaces first
START_TRAIT=2 END_TRAIT=4 ./scripts/submit-all-traits-runai.sh

# Wait for them to start or complete

# Clean up (will prompt for confirmation)
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4
```

**Expected**:
- Shows confirmation prompt
- Deletes 3 workspaces after typing "yes"
- Deletes 3 output directories
- Shows summary statistics

#### Test 3: Workspaces-only mode
```bash
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4 --workspaces-only
```

**Expected**:
- Only deletes RunAI workspaces
- Leaves output directories intact

#### Test 4: Outputs-only mode
```bash
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4 --outputs-only
```

**Expected**:
- Only deletes output directories
- Leaves RunAI workspaces running

#### Test 5: Force mode (no confirmation)
```bash
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4 --force
```

**Expected**:
- No confirmation prompt
- Deletes immediately

#### Test 6: Clean non-existent traits
```bash
./scripts/cleanup-runai.sh --start-trait 999 --end-trait 999
```

**Expected**:
- Reports 0 workspaces found
- Reports 0 output directories found
- Completes successfully

#### Test 7: User cancellation
```bash
./scripts/cleanup-runai.sh --all
# Type "no" or just press Enter
```

**Expected**:
- Exits without deleting anything
- Shows "Cancelled" message

**Validation Checklist**:
- [ ] Dry-run shows accurate preview
- [ ] Interactive confirmation works
- [ ] Workspaces deleted correctly
- [ ] Output files deleted correctly
- [ ] Workspaces-only mode works
- [ ] Outputs-only mode works
- [ ] Force mode works
- [ ] Handles non-existent resources gracefully
- [ ] User can cancel operation
- [ ] Summary statistics are accurate

**Dependencies**: Tasks 1-5 (all previous tasks)

---

## Parallel Work Opportunities

Tasks can be parallelized:

**Group A** (Core Implementation):
- Task 1: Create script (blocks all others)

**Group B** (Documentation - can work in parallel after Task 1):
- Task 2: Update MANUAL_RUNAI_EXECUTION.md
- Task 3: Update RUNAI_QUICK_REFERENCE.md
- Task 4: Update README.md
- Task 5: Update CHANGELOG.md

**Group C** (Testing - requires all previous):
- Task 6: Test on cluster

---

## Rollout Plan

### Phase 1: Development (Local)
1. Implement script (Task 1)
2. Test basic functionality locally (mock runai output if needed)

### Phase 2: Documentation
1. Update all documentation (Tasks 2-5)
2. Commit and push changes

### Phase 3: Cluster Testing
1. Test on cluster with real workspaces (Task 6)
2. Fix any issues discovered
3. Retest until all test cases pass

### Phase 4: User Communication
1. Merge PR
2. Notify users of new cleanup capability
3. Update any training materials

---

## Success Metrics

- [ ] Script successfully deletes workspaces and files
- [ ] All test cases pass
- [ ] Documentation is complete and accurate
- [ ] Zero user-reported issues in first week
- [ ] Users report improved cleanup workflow

---

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| Accidental deletion of all workspaces | Require typed "yes" confirmation, provide dry-run |
| Deleting wrong trait range | Show preview, confirm range before deletion |
| Script fails mid-deletion | Continue on errors, report at end |
| RunAI API rate limiting | Add delays between deletions |
| Output path typo | Validate path exists, show full paths in confirmation |
