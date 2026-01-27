## 1. Test Infrastructure (TDD - Write Tests First)

### 1.1 Create Multi-Workflow Test Fixtures
- [ ] 1.1.1 Create `tests/fixtures/aggregation/multi_workflow/` directory
- [ ] 1.1.2 Create `trait_from_workflow_a/` with metadata.json having workflow_uid "uid-workflow-a"
- [ ] 1.1.3 Create `trait_from_workflow_b/` with metadata.json having workflow_uid "uid-workflow-b"
- [ ] 1.1.4 Both traits should have valid Filter files with significant SNPs

### 1.2 Write Failing Tests
- [ ] 1.2.1 Test: `collect_workflow_stats()` returns per-workflow trait counts
- [ ] 1.2.2 Test: `collect_workflow_stats()` returns per-workflow compute time
- [ ] 1.2.3 Test: `detect_multi_workflow()` returns TRUE when >1 unique workflow UIDs
- [ ] 1.2.4 Test: Markdown summary includes "Source Workflows" section when multi-workflow
- [ ] 1.2.5 Test: Console output includes multi-workflow notice

## 2. Implementation

### 2.1 Data Collection
- [ ] 2.1.1 Add `collect_workflow_stats()` function to aggregation_utils.R
- [ ] 2.1.2 Track trait count per workflow UID during metadata scan
- [ ] 2.1.3 Track total duration per workflow UID
- [ ] 2.1.4 Collect workflow names (not just UIDs) from metadata

### 2.2 Detection and Notification
- [ ] 2.2.1 Add `is_multi_workflow` flag to stats when >1 source workflow
- [ ] 2.2.2 Print console notice when multi-workflow detected
- [ ] 2.2.3 Include workflow count in summary output

### 2.3 Markdown Report Updates
- [ ] 2.3.1 Update Executive Summary to show "Multiple Workflows (N)" when applicable
- [ ] 2.3.2 Add "Source Workflows" table to Reproducibility section
- [ ] 2.3.3 Include per-workflow: name, UID, trait count, compute hours

### 2.4 JSON Output Updates
- [ ] 2.4.1 Add `workflow_stats` object to summary_stats.json with per-workflow breakdown
- [ ] 2.4.2 Add `is_multi_workflow` boolean flag

## 3. Validation

### 3.1 Run Tests
- [ ] 3.1.1 Run new multi-workflow tests (should pass after implementation)
- [ ] 3.1.2 Run all existing aggregation tests (no regressions)
- [ ] 3.1.3 Run integration tests

### 3.2 Manual Verification
- [ ] 3.2.1 Re-run aggregation on 20260104 dataset to verify multi-workflow report
- [ ] 3.2.2 Verify single-workflow aggregation still works correctly
