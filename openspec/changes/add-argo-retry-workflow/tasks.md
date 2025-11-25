## 1. Create High-Memory WorkflowTemplate

- [ ] 1.1 Copy `gapit3-single-trait-template.yaml` to `gapit3-single-trait-template-highmem.yaml`
- [ ] 1.2 Update template name to `gapit3-gwas-single-trait-highmem`
- [ ] 1.3 Update memory request from 64Gi to 96Gi
- [ ] 1.4 Update memory limit from 72Gi to 104Gi
- [ ] 1.5 Update CPU request from 12 to 16
- [ ] 1.6 Update CPU limit from 16 to 20
- [ ] 1.7 Update OPENBLAS_NUM_THREADS from 12 to 16
- [ ] 1.8 Update OMP_NUM_THREADS from 12 to 16
- [ ] 1.9 Add comment explaining this is for retry of OOM/timeout-failed traits
- [ ] 1.10 Apply template to cluster: `kubectl apply -f ... -n runai-talmo-lab`

## 2. Create Retry Script

- [ ] 2.1 Create `scripts/retry-argo-traits.sh` with argument parsing
- [ ] 2.2 Implement `--workflow` option to specify source workflow
- [ ] 2.3 Implement `--traits` option for manual trait list (e.g., `--traits 5,28,29,30,31`)
- [ ] 2.4 Implement `--namespace` option (default: runai-talmo-lab)
- [ ] 2.5 Implement `--highmem` flag to use high-memory template
- [ ] 2.6 Implement `--dry-run` flag to preview without submitting
- [ ] 2.7 Implement `--submit` flag to actually submit workflow
- [ ] 2.8 Implement `--output` option for generated YAML path
- [ ] 2.9 Add auto-detection of failed traits from workflow JSON
- [ ] 2.10 Add validation that argo CLI is available
- [ ] 2.11 Add validation that workflow exists
- [ ] 2.12 Generate retry workflow YAML with proper structure
- [ ] 2.13 Copy volume configuration from original workflow parameters
- [ ] 2.14 Add help text and usage examples

## 3. Implement Trait Detection (Output Directory Inspection)

- [ ] 3.1 Extract models parameter from workflow JSON (e.g., "BLINK,FarmCPU,MLM")
- [ ] 3.2 Extract output-hostpath and trait range from workflow parameters
- [ ] 3.3 Implement `--output-dir` option to specify local path to output directory
- [ ] 3.4 For each expected trait, check if output directory exists
- [ ] 3.5 For existing directories, check for GWAS_Results files for each expected model
- [ ] 3.6 Categorize traits as: complete, missing (no directory), or incomplete (missing models)
- [ ] 3.7 Display summary showing which traits need retry and which models are missing
- [ ] 3.8 Optionally cross-reference with Argo task status for failure reasons

## 4. Implement Workflow Generation

- [ ] 4.1 Generate workflow metadata (generateName, namespace, labels)
- [ ] 4.2 Generate arguments.parameters section from original workflow
- [ ] 4.3 Generate volumes section matching original workflow
- [ ] 4.4 Generate DAG tasks for each failed trait
- [ ] 4.5 Reference correct template (normal or highmem based on flag)
- [ ] 4.6 Set appropriate activeDeadlineSeconds (7 days)
- [ ] 4.7 Write generated YAML to file

## 5. Implement Submission and Monitoring

- [ ] 5.1 Submit workflow via `argo submit`
- [ ] 5.2 Display workflow name after submission
- [ ] 5.3 Optionally watch workflow with `--watch` flag
- [ ] 5.4 Return workflow name for scripting

## 6. Add Aggregation Integration

- [ ] 6.1 Add `--aggregate` flag to run aggregation after completion
- [ ] 6.2 Wait for workflow to complete before aggregating
- [ ] 6.3 Call `aggregate-runai-results.sh --force` with correct paths
- [ ] 6.4 Display aggregation results

## 7. Documentation

- [ ] 7.1 Add retry section to `cluster/argo/README.md`
- [ ] 7.2 Document high-memory template and when to use it
- [ ] 7.3 Add troubleshooting section for common retry scenarios
- [ ] 7.4 Update `docs/MANUAL_RUNAI_EXECUTION.md` with Argo retry info
- [ ] 7.5 Add script help text with examples

## 8. Testing

- [ ] 8.1 Test dry-run mode generates valid YAML
- [ ] 8.2 Test auto-detection of failed traits from real workflow
- [ ] 8.3 Test manual trait specification
- [ ] 8.4 Test high-memory template submission
- [ ] 8.5 Verify retry workflow completes successfully
- [ ] 8.6 Verify aggregation includes retry results
- [ ] 8.7 Test error handling for missing workflow
- [ ] 8.8 Test error handling for no failed traits

## 9. Cleanup

- [ ] 9.1 Archive this OpenSpec change after deployment
