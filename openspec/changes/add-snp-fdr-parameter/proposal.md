## Why

Collaborators require FDR (Benjamini-Hochberg) controlled significance thresholds for reporting statistically significant SNPs in GWAS results. Currently the pipeline only supports fixed p-value thresholds (SNP_THRESHOLD), but GAPIT3 natively supports `SNP.FDR` for FDR-controlled analysis. This is needed for the iron traits project meeting on December 10th.

## What Changes

### Phase 1: Core Implementation (COMPLETE)
- Add `SNP_FDR` environment variable to `entrypoint.sh` (default: empty/disabled)
- Add `--snp-fdr` command-line argument to `run_gwas_single_trait.R`
- Pass `SNP.FDR` parameter to GAPIT() call when specified
- Update `.env.example` with documentation for `SNP_FDR`
- Log FDR threshold in runtime configuration output

### Phase 2: Orchestration Integration (IN PROGRESS)
- Add `snp-fdr` parameter to Argo WorkflowTemplate (`gapit3-single-trait-template.yaml`)
- Add `SNP_FDR` environment variable to WorkflowTemplate
- Add `snp-fdr` workflow parameter to parallel and test pipelines
- Update `submit-all-traits-runai.sh` to load and pass `SNP_FDR`
- Update `cluster/runai-job-template.yaml` with `SNP_FDR` env var

### Phase 3: Documentation
- Update `docs/MANUAL_RUNAI_EXECUTION.md` with FDR examples
- Update `QUICKSTART.md` with FDR configuration

## Default Value

**Default: Empty string (disabled)**

When `SNP_FDR` is empty or not set:
- GAPIT uses only the fixed p-value threshold (`SNP_THRESHOLD`)
- No FDR correction is applied
- Backward compatible with existing pipelines

When `SNP_FDR` is set (e.g., `0.05`):
- GAPIT applies Benjamini-Hochberg FDR correction
- SNPs are filtered at the specified false discovery rate
- Common values: `0.05` (5% FDR), `0.1` (10% FDR)

## Impact

- Affected specs: `runtime-configuration`, `argo-workflow-configuration`
- Affected code:
  - `scripts/entrypoint.sh` (add env var, pass to R script) ✓
  - `scripts/run_gwas_single_trait.R` (add argument, pass to GAPIT) ✓
  - `.env.example` (documentation) ✓
  - `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`
  - `cluster/argo/workflows/gapit3-parallel-pipeline.yaml`
  - `cluster/argo/workflows/gapit3-test-pipeline.yaml`
  - `scripts/submit-all-traits-runai.sh`
  - `cluster/runai-job-template.yaml`
  - `docs/MANUAL_RUNAI_EXECUTION.md`
  - `QUICKSTART.md`
- Backward compatible: Empty/unset `SNP_FDR` maintains current behavior
