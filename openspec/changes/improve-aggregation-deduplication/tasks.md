## 1. Implementation

- [ ] 1.1 Add `--workflow-id` CLI parameter to `collect_results.R`
- [ ] 1.2 Create `filter_by_workflow_id()` function to read `metadata.json` and filter directories
- [ ] 1.3 Refactor `select_best_trait_dirs()` to use Filter-first deduplication logic
- [ ] 1.4 Add source manifest output (`aggregated_results/source_directories.txt`)
- [ ] 1.5 Improve deduplication logging to show Filter file status

## 2. Testing

- [ ] 2.1 Add test for Filter-first deduplication (incomplete vs complete directories)
- [ ] 2.2 Add test for `--workflow-id` single workflow filter
- [ ] 2.3 Add test for `--workflow-id` multi-workflow filter (comma-separated)
- [ ] 2.4 Add test for source manifest generation
- [ ] 2.5 Add test for backward compatibility (no `--workflow-id` = aggregate all)

## 3. Documentation

- [ ] 3.1 Update `collect_results.R` header comments with new parameters
- [ ] 3.2 Update `--help` output with `--workflow-id` usage examples

## 4. Validation

- [ ] 4.1 Run `openspec validate improve-aggregation-deduplication --strict`
