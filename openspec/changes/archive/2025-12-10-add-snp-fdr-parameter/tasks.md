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

## 6. Testing (COMPLETE)

- [x] 6.1 Add unit tests for SNP_FDR parameter parsing (`tests/testthat/test-snp-fdr.R`)
- [x] 6.2 Add unit tests for SNP_FDR in metadata tracking
- [x] 6.3 Add test fixtures for different FDR configurations (`tests/fixtures/snp_fdr/`)
- [x] 6.4 Add integration tests for SNP_FDR workflow propagation (`tests/integration/test-snp-fdr-e2e.sh`)
- [x] 6.5 Add tests for SNP_FDR in markdown report generation (`tests/testthat/test-pipeline-summary.R`)
- [x] 6.6 Update helper.R to include SNP_FDR in cleanup_env_vars()

## 7. Bug Fixes (COMPLETE)

- [x] 7.1 Fix MAF_FILTER bug - now passed to GAPIT as MAF.Threshold (`scripts/run_gwas_single_trait.R`)
- [x] 7.2 Add SNP FDR to pipeline summary markdown report (`scripts/collect_results.R`)