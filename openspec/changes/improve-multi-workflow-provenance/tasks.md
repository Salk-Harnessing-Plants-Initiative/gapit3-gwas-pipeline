## 1. Test Infrastructure (TDD - Write Tests First)

### 1.1 Create Multi-Workflow Test Fixtures
- [x] 1.1.1 Create `tests/fixtures/aggregation/multi_workflow/` directory
- [x] 1.1.2 Create `trait_from_workflow_a/` with metadata.json having workflow_uid "uid-workflow-a"
- [x] 1.1.3 Create `trait_from_workflow_b/` with metadata.json having workflow_uid "uid-workflow-b"
- [x] 1.1.4 Both traits should have valid Filter files with significant SNPs

### 1.2 Write Failing Tests
- [x] 1.2.1 Test: `collect_workflow_stats()` returns per-workflow trait counts
- [x] 1.2.2 Test: `collect_workflow_stats()` returns per-workflow compute time
- [x] 1.2.3 Test: `is_multi_workflow()` returns TRUE when >1 unique workflow UIDs
- [x] 1.2.4 Test: Multi-workflow traits can be combined with bind_rows
- [x] 1.2.5 Test: Single workflow returns is_multi_workflow FALSE

## 2. Implementation

### 2.1 Data Collection
- [x] 2.1.1 Add `collect_workflow_stats()` function to aggregation_utils.R
- [x] 2.1.2 Track trait count per workflow UID during metadata scan
- [x] 2.1.3 Track total duration per workflow UID
- [x] 2.1.4 Collect workflow names (not just UIDs) from metadata

### 2.2 Detection and Notification
- [x] 2.2.1 Add `is_multi_workflow` flag to stats when >1 source workflow
- [x] 2.2.2 Print console notice when multi-workflow detected
- [x] 2.2.3 Include workflow count in summary output

### 2.3 Markdown Report Updates
- [x] 2.3.1 Update Executive Summary to show "Source Workflows: N" when applicable
- [x] 2.3.2 Add "Source Workflows" table to Reproducibility section
- [x] 2.3.3 Include per-workflow: name, UID (truncated), trait count, compute hours
- [x] 2.3.4 Add `format_workflow_stats_table()` helper function

### 2.4 JSON Output Updates
- [x] 2.4.1 Add `workflow_stats` object to summary_stats.json with per-workflow breakdown
- [x] 2.4.2 Add `is_multi_workflow` boolean flag

## 3. Validation

### 3.1 Run Tests
- [x] 3.1.1 Run new multi-workflow tests (all pass - 466 total)
- [x] 3.1.2 Run all existing aggregation tests (no regressions)
- [ ] 3.1.3 Run integration tests (pre-existing P.value sorting issue - unrelated)

### 3.2 Manual Verification
- [ ] 3.2.1 Re-run aggregation on 20260104 dataset to verify multi-workflow report
- [ ] 3.2.2 Verify single-workflow aggregation still works correctly
