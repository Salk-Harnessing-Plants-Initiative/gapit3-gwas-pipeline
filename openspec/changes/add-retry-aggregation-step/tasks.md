## 1. Update collect_results.R for Duplicate Handling

- [x] 1.1 Add `select_best_trait_dirs()` helper function
- [x] 1.2 Extract trait index from directory names
- [x] 1.3 Count complete models per directory
- [x] 1.4 Select directory with most complete models (newest as tie-breaker)
- [x] 1.5 Log when duplicates are found and which directory was selected
- [x] 1.6 Add `--models` parameter to specify expected models (optional)
- [x] 1.7 Update main scanning logic to use deduplication

## 2. Update retry-argo-traits.sh for In-Cluster Aggregation

- [x] 2.1 Modify workflow generation to include `collect-results` task when `--aggregate` is set
- [x] 2.2 Build dependencies list from all retry-trait-* tasks
- [x] 2.3 Reference `gapit3-results-collector` template
- [x] 2.4 Pass image and batch-id parameters
- [x] 2.5 Remove local `aggregate-runai-results.sh` call
- [x] 2.6 Update help text to clarify aggregation runs in-cluster
- [x] 2.7 Log that aggregation will run after retries complete

## 2B. Add SNP FDR Parameter Propagation

- [x] 2B.1 Extract `snp-fdr` parameter from original workflow JSON (jq query)
- [x] 2B.2 Add `SNP_FDR` variable with extracted value (default: empty)
- [x] 2B.3 Add `snp-fdr` to workflow-level arguments.parameters section
- [x] 2B.4 Add `snp-fdr` parameter to each retry-trait-* task's templateRef arguments
- [x] 2B.5 Log the FDR threshold being used (if set)
- [x] 2B.6 Update help text to mention FDR propagation

## 3. Testing

- [x] 3.1 Test deduplication with multiple directories per trait (local R script)
- [x] 3.2 Test directory selection prioritizes completeness over recency
- [x] 3.3 Test tie-breaking selects newest when completeness is equal
- [ ] 3.4 Test retry workflow generation with `--aggregate` flag (dry-run)
- [ ] 3.5 Verify generated YAML includes collect-results task with correct dependencies
- [ ] 3.6 Test full retry + aggregation workflow on cluster
- [ ] 3.7 Test snp-fdr extraction from workflow with FDR parameter
- [ ] 3.8 Test snp-fdr defaults to empty when original workflow has no FDR
- [ ] 3.9 Verify generated retry YAML includes snp-fdr parameter in tasks

## 4. Docker Image Update

- [ ] 4.1 Rebuild Docker image with updated collect_results.R
- [ ] 4.2 Push new image tag
- [ ] 4.3 Update template defaults to use new image

## 5. Documentation

- [x] 5.1 Update README with aggregation behavior for retries
- [x] 5.2 Document duplicate handling logic
- [x] 5.3 Add examples of `--aggregate` flag usage

## 6. Cleanup

- [ ] 6.1 Archive this OpenSpec change after deployment
