## 1. Create High-Memory WorkflowTemplate

- [x] 1.1 Copy `gapit3-single-trait-template.yaml` to `gapit3-single-trait-template-highmem.yaml`
- [x] 1.2 Update template name to `gapit3-gwas-single-trait-highmem`
- [x] 1.3 Update memory request from 64Gi to 96Gi
- [x] 1.4 Update memory limit from 72Gi to 104Gi
- [x] 1.5 Update CPU request from 12 to 16
- [x] 1.6 Update CPU limit from 16 to 20
- [x] 1.7 Update OPENBLAS_NUM_THREADS from 12 to 16
- [x] 1.8 Update OMP_NUM_THREADS from 12 to 16
- [x] 1.9 Add comment explaining this is for retry of OOM/timeout-failed traits
- [x] 1.10 Apply template to cluster: `kubectl apply -f ... -n runai-talmo-lab`

## 2. Create Retry Script

- [x] 2.1 Create `scripts/retry-argo-traits.sh` with argument parsing
- [x] 2.2 Implement `--workflow` option to specify source workflow
- [x] 2.3 Implement `--traits` option for manual trait list (e.g., `--traits 5,28,29,30,31`)
- [x] 2.4 Implement `--namespace` option (default: runai-talmo-lab)
- [x] 2.5 Implement `--highmem` flag to use high-memory template
- [x] 2.6 Implement `--dry-run` flag to preview without submitting
- [x] 2.7 Implement `--submit` flag to actually submit workflow
- [x] 2.8 Implement `--output` option for generated YAML path
- [x] 2.9 Add auto-detection of failed traits from workflow JSON
- [x] 2.10 Add validation that argo CLI is available
- [x] 2.11 Add validation that workflow exists
- [x] 2.12 Generate retry workflow YAML with proper structure
- [x] 2.13 Copy volume configuration from original workflow parameters
- [x] 2.14 Add help text and usage examples

## 3. Implement Trait Detection (Output Directory Inspection)

- [x] 3.1 Extract models parameter from workflow JSON (e.g., "BLINK,FarmCPU,MLM")
- [x] 3.2 Extract output-hostpath and trait range from workflow parameters
- [x] 3.3 Implement `--output-dir` option to specify local path to output directory
- [x] 3.4 For each expected trait, check if output directory exists
- [x] 3.5 For existing directories, check for GWAS_Results files for each expected model
- [x] 3.6 Categorize traits as: complete, missing (no directory), or incomplete (missing models)
- [x] 3.7 Display summary showing which traits need retry and which models are missing
- [x] 3.8 Optionally cross-reference with Argo task status for failure reasons

## 4. Implement Workflow Generation

- [x] 4.1 Generate workflow metadata (generateName, namespace, labels)
- [x] 4.2 Generate arguments.parameters section from original workflow
- [x] 4.3 Generate volumes section matching original workflow
- [x] 4.4 Generate DAG tasks for each failed trait
- [x] 4.5 Reference correct template (normal or highmem based on flag)
- [x] 4.6 Set appropriate activeDeadlineSeconds (7 days)
- [x] 4.7 Write generated YAML to file

## 5. Implement Submission and Monitoring

- [x] 5.1 Submit workflow via `argo submit`
- [x] 5.2 Display workflow name after submission
- [x] 5.3 Optionally watch workflow with `--watch` flag
- [x] 5.4 Return workflow name for scripting

## 6. Add Aggregation Integration

- [x] 6.1 Add `--aggregate` flag to run aggregation after completion
- [x] 6.2 Wait for workflow to complete before aggregating
- [x] 6.3 Call `aggregate-runai-results.sh --force` with correct paths
- [x] 6.4 Display aggregation results

## 7. Documentation

- [x] 7.1 Add retry section to `cluster/argo/README.md`
- [x] 7.2 Document high-memory template and when to use it
- [x] 7.3 Add troubleshooting section for common retry scenarios
- [x] 7.4 Update `docs/MANUAL_RUNAI_EXECUTION.md` with Argo retry info
- [x] 7.5 Add script help text with examples

## 8. Testing

- [x] 8.1 Test dry-run mode generates valid YAML
- [x] 8.2 Test auto-detection of failed traits from real workflow
- [x] 8.3 Test manual trait specification
- [x] 8.4 Test high-memory template submission
- [x] 8.5 Verify retry workflow completes successfully
- [x] 8.6 Verify aggregation includes retry results
- [x] 8.7 Test error handling for missing workflow
- [x] 8.8 Test error handling for no failed traits

## 9. Cleanup

- [x] 9.1 Archive this OpenSpec change after deployment
