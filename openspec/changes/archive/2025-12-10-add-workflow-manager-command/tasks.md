## 1. Create Slash Command File

- [x] 1.1 Create `.claude/commands/manage-workflow.md` with command description
- [x] 1.2 Document usage modes (interactive, automated, dry-run)
- [x] 1.3 Document required arguments (workflow name)
- [x] 1.4 Document optional flags (--auto, --dry-run, --skip-cleanup, --skip-retry)
- [x] 1.5 Add examples for common scenarios

## 2. Implement Assessment Phase

- [x] 2.1 Document how to fetch workflow status with `argo get <workflow> -n runai-talmo-lab`
- [x] 2.2 Document how to identify OOMKilled failures (exit code 137, "OOMKilled" message)
- [x] 2.3 Document how to identify stuck pods (PodInitializing state > 10 minutes)
- [x] 2.4 Document how to identify timeout failures
- [x] 2.5 Document how to extract trait indices from task names (e.g., `run-all-traits(3:5)` → trait 5)
- [x] 2.6 Document how to generate assessment summary report

## 3. Implement Cleanup Phase

- [x] 3.1 Document how to stop stalled workflows with `argo stop <workflow>`
- [x] 3.2 Document how to identify incomplete output directories
- [x] 3.3 Document cleanup confirmation flow (show what will be deleted, require confirmation)
- [x] 3.4 Document dry-run behavior for cleanup
- [x] 3.5 Document how to verify cleanup success

## 4. Implement Retry Phase

- [x] 4.1 Document how to use `retry-argo-traits.sh` with correct parameters
- [x] 4.2 Document `--highmem` flag usage for OOMKilled traits
- [x] 4.3 Document `--aggregate` flag to include aggregation step
- [x] 4.4 Document `--traits` parameter construction from failed trait list
- [x] 4.5 Document how to capture submitted workflow name
- [x] 4.6 Document dry-run behavior for retry (use `--dry-run` flag)

## 5. Implement Monitoring Phase

- [x] 5.1 Document how to monitor retry workflow progress with `argo get`
- [x] 5.2 Document progress reporting format (X/Y tasks complete)
- [x] 5.3 Document completion detection (workflow status == Succeeded)
- [x] 5.4 Document failure detection during retry (new failures)
- [x] 5.5 Document aggregation step verification

## 6. Document Decision Tree

- [x] 6.1 Document when to use high-memory template (OOMKilled)
- [x] 6.2 Document when to skip cleanup (no stuck pods, no incomplete dirs)
- [x] 6.3 Document when to skip retry (all traits complete)
- [x] 6.4 Document when to recommend manual intervention (repeated failures)

## 7. Integration with Existing Commands

- [x] 7.1 Reference `/monitor-jobs` for additional monitoring options
- [x] 7.2 Reference `/cleanup-jobs` for manual cleanup operations
- [x] 7.3 Reference `/aggregate-results` for standalone aggregation
- [x] 7.4 Add cross-references in related commands

## 8. Testing

- [x] 8.1 Test with workflow that has OOMKilled failures
- [x] 8.2 Test with workflow that has stuck pods
- [x] 8.3 Test with workflow that is fully complete (no retry needed)
- [x] 8.4 Test dry-run mode
- [x] 8.5 Test automated mode

## 9. Documentation

- [x] 9.1 Update cluster/argo/README.md with manage-workflow command
- [x] 9.2 Add troubleshooting section for common issues
- [x] 9.3 Document WSL command invocation pattern for Windows users
- [x] 9.4 Document path mapping (Windows → WSL → Cluster)
- [x] 9.5 Document KUBECONFIG setup and verification
- [x] 9.6 Document WorkflowTemplate installation commands
- [x] 9.7 Document RBAC limitations and workarounds

## 10. Cleanup

- [x] 10.1 Archive this OpenSpec change after deployment
