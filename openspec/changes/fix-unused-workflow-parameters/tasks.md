## 1. Clean Up Parallel Pipeline Parameters

- [ ] 1.1 Remove `cpu-cores` parameter from gapit3-parallel-pipeline.yaml
- [ ] 1.2 Remove `memory-gb` parameter from gapit3-parallel-pipeline.yaml
- [ ] 1.3 Remove `max-parallelism` parameter from gapit3-parallel-pipeline.yaml
- [ ] 1.4 Add comment explaining resources are in WorkflowTemplate
- [ ] 1.5 Fix trait count comment (184 -> 186)

## 2. Clean Up Test Pipeline Parameters

- [ ] 2.1 Remove `cpu-cores` parameter from gapit3-test-pipeline.yaml
- [ ] 2.2 Remove `memory-gb` parameter from gapit3-test-pipeline.yaml
- [ ] 2.3 Add GENOTYPE_FILE env var to validate template
- [ ] 2.4 Add PHENOTYPE_FILE env var to validate template

## 3. Update WorkflowTemplate

- [ ] 3.1 Update default models from `BLINK,FarmCPU` to `BLINK,FarmCPU,MLM`
- [ ] 3.2 Remove CLI args (keep only command selector) - may be done in fix-duplicate-parameter-passing
- [ ] 3.3 Add comment explaining env-var-only pattern

## 4. Documentation

- [ ] 4.1 Add README section explaining parameter flow
- [ ] 4.2 Update any comments referencing unused parameters

## 5. Testing

- [ ] 5.1 Apply updated WorkflowTemplate to cluster
- [ ] 5.2 Submit test pipeline and verify correct behavior
- [ ] 5.3 Verify Argo UI shows only used parameters
- [ ] 5.4 Check logs confirm env vars are being used

## 6. Cleanup

- [ ] 6.1 Archive this OpenSpec change after deployment
