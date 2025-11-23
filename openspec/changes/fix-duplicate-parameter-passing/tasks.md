## 1. Update WorkflowTemplate

- [ ] 1.1 Remove parameter CLI arguments from `gapit3-single-trait-template.yaml` container args
- [ ] 1.2 Keep only command selector (`run-single-trait`) in args
- [ ] 1.3 Add documentation comment explaining env-var-only pattern
- [ ] 1.4 Verify all required parameters are in env section

## 2. Update Workflow Files

- [ ] 2.1 Review `gapit3-parallel-pipeline.yaml` for consistency
- [ ] 2.2 Review `gapit3-test-pipeline.yaml` for consistency
- [ ] 2.3 Remove any CLI arg patterns from inline templates

## 3. Documentation

- [ ] 3.1 Update `.env.example` to clarify it's the authoritative parameter reference
- [ ] 3.2 Add section to cluster/argo/README.md explaining parameter passing

## 4. Testing

- [ ] 4.1 Apply updated WorkflowTemplate to cluster
- [ ] 4.2 Submit test workflow and verify parameters are correctly passed
- [ ] 4.3 Check logs to confirm env vars are used

## 5. Cleanup

- [ ] 5.1 Update CHANGELOG.md with the fix
- [ ] 5.2 Archive this OpenSpec change after deployment
