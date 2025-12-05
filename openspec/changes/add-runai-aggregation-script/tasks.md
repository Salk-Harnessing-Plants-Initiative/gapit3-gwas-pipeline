# Tasks: Add RunAI Aggregation Script

## Overview

Implement automatic results aggregation for manual RunAI execution workflow.

**Estimated Total Time**: 4-5 hours

---

## Task List

### 1. Create aggregate-runai-results.sh Script (2-3 hours)

**Description**: Implement main aggregation monitoring script

**Subtasks**:
- [x] Create `scripts/aggregate-runai-results.sh` file
- [ ] Add shebang and script header
- [ ] Implement argument parsing (optparse or getopt)
  - `--output-dir` (default: from env)
  - `--batch-id` (default: "runai-$(date)")
  - `--project` (default: "talmo-lab")
  - `--start-trait` (default: 2)
  - `--end-trait` (default: 187)
  - `--check-interval` (default: 30)
  - `--check-only` (flag)
  - `--force` (flag)
- [ ] Implement prerequisite checks
  - Check `runai` CLI available
  - Check `runai whoami` (authentication)
  - Check output directory exists
  - Check `scripts/collect_results.R` exists
- [ ] Implement job discovery
  - Query: `runai workspace list -p $PROJECT`
  - Parse output for `gapit3-trait-*` jobs
  - Extract trait indices from job names
  - Filter by trait range if specified
  - Count by status (Running, Succeeded, Failed, Pending)
- [ ] Implement monitoring loop
  - Display progress with counts
  - Show progress bar
  - Sleep $CHECK_INTERVAL seconds
  - Re-query and update
  - Exit when all complete
- [ ] Implement aggregation execution
  - Warn if many failures (>10)
  - Run `Rscript scripts/collect_results.R` with parameters
  - Check exit code
  - Display results location
- [ ] Implement error handling
  - RunAI CLI errors
  - No jobs found
  - Aggregation script failures
  - User interrupts (trap INT)
- [ ] Add colored output (GREEN, YELLOW, RED, NC)
- [ ] Make script executable: `chmod +x`

**Dependencies**: None

**Validation**:
```bash
# Test with no jobs
./scripts/aggregate-runai-results.sh --check-only

# Test with --help
./scripts/aggregate-runai-results.sh --help
```

---

### 2. Update submit-all-traits-runai.sh (15 minutes)

**Description**: Add reminder message about aggregation

**Changes**:
- [ ] Add "Next steps" section at end of script
- [ ] Display:
  1. Monitor command
  2. Aggregate command

**Example output**:
```bash
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Monitor progress:"
echo "   ./scripts/monitor-runai-jobs.sh --watch"
echo ""
echo "2. Aggregate results when complete:"
echo "   ./scripts/aggregate-runai-results.sh"
echo ""
```

**Dependencies**: Task 1 (script must exist)

**Validation**:
```bash
# Dry run submission script to see output
START_TRAIT=2 END_TRAIT=2 ./scripts/submit-all-traits-runai.sh
# (Cancel at confirmation prompt)
```

---

### 3. Update monitor-runai-jobs.sh (15 minutes)

**Description**: Add aggregation hint when all jobs complete

**Changes**:
- [ ] Check if all jobs complete: `SUCCEEDED + FAILED == expected_total`
- [ ] Display message suggesting aggregation

**Example**:
```bash
if [ $((SUCCEEDED + FAILED)) -ge 186 ]; then
    echo ""
    echo -e "${GREEN}All jobs complete!${NC}"
    echo "Run aggregation with:"
    echo "  ./scripts/aggregate-runai-results.sh"
fi
```

**Dependencies**: Task 1 (script must exist)

**Validation**:
```bash
# Run monitor to see message when jobs complete
./scripts/monitor-runai-jobs.sh
```

---

### 4. Update docs/MANUAL_RUNAI_EXECUTION.md (30 minutes)

**Description**: Add aggregation section to manual execution guide

**Changes**:
- [ ] Add "Step 4: Aggregate Results" section after "Step 3: Run Multiple Traits"
- [ ] Include basic usage example
- [ ] Include advanced usage (custom paths, trait ranges)
- [ ] Document output files created
- [ ] Add to table of contents

**Example content**:
````markdown
### Step 4: Aggregate Results

After all traits complete, aggregate results into summary reports:

```bash
# Wait for all jobs to complete and auto-aggregate
./scripts/aggregate-runai-results.sh

# Or force aggregation immediately (if jobs already done)
./scripts/aggregate-runai-results.sh --force

# Check status without waiting
./scripts/aggregate-runai-results.sh --check-only
```

**What this creates**:
- `aggregated_results/summary_table.csv` - Summary of all traits
- `aggregated_results/significant_snps.csv` - SNPs with p < 5e-8
- `aggregated_results/summary_stats.json` - Overall statistics

**Advanced usage**:
```bash
# Custom output path and batch ID
./scripts/aggregate-runai-results.sh \
  --output-dir /custom/path \
  --batch-id "batch-20251107"

# Specific trait range
./scripts/aggregate-runai-results.sh --start-trait 2 --end-trait 50
```
````

**Dependencies**: Task 1 (script must exist for examples to work)

**Validation**:
- [ ] Review updated docs
- [ ] Verify all links work
- [ ] Check markdown renders correctly

---

### 5. Update docs/RUNAI_QUICK_REFERENCE.md (15 minutes)

**Description**: Add aggregation command to quick reference

**Changes**:
- [ ] Add to "Common Workflows" section
- [ ] Include basic and advanced examples
- [ ] Keep concise (it's a quick reference)

**Example**:
````markdown
### Aggregate Results After Parallel Execution

```bash
# Wait for all jobs to complete, then aggregate
./scripts/aggregate-runai-results.sh

# Custom output path and batch ID
./scripts/aggregate-runai-results.sh \
  --output-dir /custom/path \
  --batch-id "my-batch-id"

# Specific trait range
./scripts/aggregate-runai-results.sh --start-trait 2 --end-trait 50

# Check status only (no waiting)
./scripts/aggregate-runai-results.sh --check-only

# Force immediate aggregation
./scripts/aggregate-runai-results.sh --force
```
````

**Dependencies**: Task 1

**Validation**:
- [ ] Verify examples are accurate
- [ ] Check formatting

---

### 6. Update README.md (10 minutes)

**Description**: Add aggregation script to features list

**Changes**:
- [ ] Update "Current workarounds available" section
- [ ] Add bullet: `✅ **Aggregation script** - scripts/aggregate-runai-results.sh`

**Example**:
```markdown
**Current workarounds available:**
- ✅ **Manual RunAI CLI** - Working now (see [Manual RunAI Execution Guide](docs/MANUAL_RUNAI_EXECUTION.md))
- ✅ **Batch submission script** - [scripts/submit-all-traits-runai.sh](scripts/submit-all-traits-runai.sh)
- ✅ **Aggregation script** - [scripts/aggregate-runai-results.sh](scripts/aggregate-runai-results.sh)
- ✅ **Monitoring dashboard** - [scripts/monitor-runai-jobs.sh](scripts/monitor-runai-jobs.sh)
- ⏳ **Argo Workflows** - Waiting for RBAC fix (see [RBAC Issue](docs/RBAC_PERMISSIONS_ISSUE.md))
```

**Dependencies**: Task 1

**Validation**:
- [ ] Verify link works
- [ ] Check placement in documentation structure

---

### 7. Update CHANGELOG.md (10 minutes)

**Description**: Document new feature in changelog

**Changes**:
- [ ] Add to `[Unreleased]` section under `### Added`
- [ ] Include brief description and link

**Example**:
```markdown
## [Unreleased]

### Added
- Automatic results aggregation script for RunAI execution
  - `scripts/aggregate-runai-results.sh` - Monitors job completion and triggers aggregation
  - Waits for all `gapit3-trait-*` jobs to finish
  - Automatically runs `collect_results.R` when complete
  - Supports custom output paths, batch IDs, and trait ranges
```

**Dependencies**: Task 1

**Validation**:
- [ ] Follows Keep a Changelog format
- [ ] Accurate description

---

### 8. Test on Cluster (1 hour)

**Description**: Validate script works end-to-end on cluster

**Test Cases**:

#### Test 1: Small batch with waiting
```bash
# 1. Submit 3 traits
START_TRAIT=2 END_TRAIT=4 ./scripts/submit-all-traits-runai.sh

# 2. Run aggregation (should wait ~45 min)
./scripts/aggregate-runai-results.sh \
  --start-trait 2 \
  --end-trait 4

# 3. Verify outputs
ls -la /hpi/hpi_dev/users/eberrigan/.../outputs/aggregated_results/
# Should contain: summary_table.csv, significant_snps.csv, summary_stats.json

# 4. Check summary_table.csv has 3 rows (traits 2, 3, 4)
head /outputs/aggregated_results/summary_table.csv
```

#### Test 2: Check-only mode
```bash
# While jobs are running:
./scripts/aggregate-runai-results.sh --check-only

# Should show counts and exit immediately
```

#### Test 3: Force mode
```bash
# After jobs complete:
./scripts/aggregate-runai-results.sh --force

# Should run aggregation immediately without waiting
```

#### Test 4: No jobs scenario
```bash
# Clean project (no gapit3-trait-* jobs):
./scripts/aggregate-runai-results.sh --check-only

# Should report "No jobs found"
```

#### Test 5: User interrupt
```bash
# Start monitoring:
./scripts/aggregate-runai-results.sh

# Press Ctrl+C during wait
# Should exit gracefully with message
```

**Validation Checklist**:
- [ ] Script waits correctly for job completion
- [ ] Progress updates display correctly
- [ ] Aggregation runs automatically when complete
- [ ] Output files created in correct location
- [ ] Error messages are helpful
- [ ] `--help` shows usage
- [ ] `--check-only` exits immediately
- [ ] `--force` skips waiting
- [ ] Handles no jobs gracefully
- [ ] User interrupt works (Ctrl+C)

**Dependencies**: Tasks 1-7 (all previous tasks)

---

## Parallel Work Opportunities

Tasks can be parallelized:

**Group A** (Core Implementation):
- Task 1: Create script (blocks all others)

**Group B** (Documentation - can work in parallel after Task 1):
- Task 4: Update MANUAL_RUNAI_EXECUTION.md
- Task 5: Update RUNAI_QUICK_REFERENCE.md
- Task 6: Update README.md
- Task 7: Update CHANGELOG.md

**Group C** (Script Integration - requires Task 1):
- Task 2: Update submit-all-traits-runai.sh
- Task 3: Update monitor-runai-jobs.sh

**Group D** (Testing - requires all previous):
- Task 8: Test on cluster

---

## Rollout Plan

### Phase 1: Development (Local)
1. Implement script (Task 1)
2. Test basic functionality locally (mock runai output)

### Phase 2: Integration
1. Update other scripts (Tasks 2-3)
2. Update documentation (Tasks 4-7)
3. Commit and push changes

### Phase 3: Cluster Testing
1. Test on cluster with small batch (Task 8)
2. Fix any issues discovered
3. Test with full 186-trait run (optional, if cluster time available)

### Phase 4: User Communication
1. Merge PR
2. Update any active user documentation
3. Notify users of new capability

---

## Success Metrics

- [ ] Script successfully monitors and aggregates results
- [ ] All documentation updated and accurate
- [ ] Tested on cluster with real RunAI jobs
- [ ] Zero user-reported issues in first week
- [ ] User feedback: "Much easier than manual aggregation"

---

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| RunAI CLI format changes | Parse output defensively, test with version check |
| Long wait times | Provide `--force` and `--check-only` flags |
| Jobs stuck indefinitely | Allow user interrupt, document timeout strategies |
| Script bugs on cluster | Test with small batches first, have rollback plan |
