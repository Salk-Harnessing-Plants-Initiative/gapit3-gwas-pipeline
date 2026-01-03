# argo-workflow-configuration Specification Delta

## MODIFIED Requirements

### Requirement: Environment Variable Parameter Passing

The Argo WorkflowTemplate SHALL pass all runtime parameters to containers exclusively via environment variables, not CLI arguments.

#### Scenario: MODELS parameter passed correctly
- **WHEN** a workflow is submitted with `models: "BLINK,FarmCPU,MLM"` parameter
- **THEN** the container receives `MODELS=BLINK,FarmCPU,MLM` as an environment variable
- **AND** the entrypoint uses this value for GWAS analysis

#### Scenario: All GAPIT parameters passed via environment
- **GIVEN** gapit3-gwas-single-trait WorkflowTemplate
- **WHEN** the template is invoked with GAPIT parameters
- **THEN** inputs.parameters SHALL include:
  - `model` (default: empty, uses container default)
  - `pca-total` (default: empty)
  - `snp-maf` (default: empty)
  - `snp-fdr` (default: empty)
  - `kinship-algorithm` (default: empty)
  - `snp-effect` (default: empty)
  - `snp-impute` (default: empty)
- **AND** each parameter maps to corresponding env var (e.g., `MODEL`, `PCA_TOTAL`, `SNP_MAF`)
