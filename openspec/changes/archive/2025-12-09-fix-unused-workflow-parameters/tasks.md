## 1. Clean Up Parallel Pipeline Parameters

- [x] 1.1 Remove `cpu-cores` parameter from gapit3-parallel-pipeline.yaml
- [x] 1.2 Remove `memory-gb` parameter from gapit3-parallel-pipeline.yaml
- [x] 1.3 Remove `max-parallelism` parameter from gapit3-parallel-pipeline.yaml
- [x] 1.4 Add comment explaining resources are configured in WorkflowTemplate
- [x] 1.5 Fix trait count comment (184 -> 186)
- [x] 1.6 Add `ACCESSION_IDS_FILE` env var to validate template

## 2. Clean Up Test Pipeline Parameters

- [x] 2.1 Remove `cpu-cores` parameter from gapit3-test-pipeline.yaml
- [x] 2.2 Remove `memory-gb` parameter from gapit3-test-pipeline.yaml
- [x] 2.3 Fix trait count comment in header (184 -> 186)

## 3. Update WorkflowTemplate

- [x] 3.1 Update default models from `BLINK,FarmCPU` to `BLINK,FarmCPU,MLM`

## 4. Clean Up submit_workflow.sh Script

- [x] 4.1 Remove `--cpu` flag and `cpu_cores` variable
- [x] 4.2 Remove `--memory` flag and `memory_gb` variable
- [x] 4.3 Remove `--parameter cpu-cores=` from ARGO_CMD
- [x] 4.4 Remove `--parameter memory-gb=` from ARGO_CMD
- [x] 4.5 Update help text to explain resources are in WorkflowTemplate
- [x] 4.6 Remove "Resources per job" section from submission output

## 5. Update README.md Documentation

- [x] 5.1 Remove `max-parallelism` from configurable parameters list
- [x] 5.2 Remove `--cpu` and `--memory` from script usage examples
- [x] 5.3 Add note explaining resources are configured in WorkflowTemplate
- [x] 5.4 Update `models` default from `BLINK,FarmCPU` to `BLINK,FarmCPU,MLM`

## 6. Testing

- [x] 6.1 Apply updated WorkflowTemplate to cluster
- [x] 6.2 Submit test pipeline and verify correct behavior
- [x] 6.3 Verify Argo UI shows only used parameters
- [x] 6.4 Check logs confirm env vars are being used

## 7. Cleanup

- [ ] 7.1 Archive this OpenSpec change after deployment
