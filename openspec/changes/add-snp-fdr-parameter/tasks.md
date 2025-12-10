## 1. Core Implementation (COMPLETE)

- [x] 1.1 Add `SNP_FDR` environment variable to `scripts/entrypoint.sh` with empty default
- [x] 1.2 Add `--snp-fdr` argument to R script option parser in `scripts/run_gwas_single_trait.R`
- [x] 1.3 Pass `SNP.FDR` parameter to GAPIT() call when value is provided
- [x] 1.4 Add FDR threshold to runtime configuration logging in entrypoint.sh
- [x] 1.5 Add FDR threshold to R script runtime logging
- [x] 1.6 Add metadata tracking for FDR parameter

## 2. Core Documentation (COMPLETE)

- [x] 2.1 Update `.env.example` with `SNP_FDR` documentation
- [x] 2.2 Update help text in entrypoint.sh

## 3. Argo Workflow Integration (COMPLETE)

- [x] 3.1 Add `snp-fdr` parameter to WorkflowTemplate arguments (default: empty)
- [x] 3.2 Add `snp-fdr` to WorkflowTemplate inputs.parameters
- [x] 3.3 Add `SNP_FDR` environment variable to WorkflowTemplate container env
- [x] 3.4 Add `snp-fdr` workflow parameter to `gapit3-parallel-pipeline.yaml`
- [x] 3.5 Pass `snp-fdr` to templateRef arguments in parallel pipeline
- [x] 3.6 Add `snp-fdr` workflow parameter to `gapit3-test-pipeline.yaml`
- [x] 3.7 Pass `snp-fdr` to templateRef arguments in test pipeline
- [x] 3.8 Apply updated WorkflowTemplate to cluster

## 4. Batch Submission Integration (COMPLETE)

- [x] 4.1 Add `SNP_FDR` to configuration variables in `submit-all-traits-runai.sh`
- [x] 4.2 Add `SNP_FDR` to submission output display
- [x] 4.3 Add `--environment SNP_FDR` to RunAI submission command (when set)
- [x] 4.4 Update `cluster/runai-job-template.yaml` with `SNP_FDR` env var

## 5. Documentation Updates (COMPLETE)

- [x] 5.1 Update `docs/MANUAL_RUNAI_EXECUTION.md` with SNP_FDR examples
- [x] 5.2 Update `QUICKSTART.md` with FDR configuration section
- [x] 5.3 Update `cluster/argo/README.md` configurable parameters list

## 6. Testing

- [ ] 6.1 Test Argo pipeline with snp-fdr=0.05
- [ ] 6.2 Test Argo pipeline without snp-fdr (backward compatibility)
- [ ] 6.3 Verify pod environment variables include SNP_FDR
- [ ] 6.4 Test RunAI batch submission with SNP_FDR
- [ ] 6.5 Verify GAPIT output includes FDR-filtered results