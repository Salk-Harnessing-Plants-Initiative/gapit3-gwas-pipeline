# runtime-configuration Specification

## Purpose
TBD - created by archiving change add-dotenv-configuration. Update Purpose after archive.
## Requirements
### Requirement: Container MUST accept runtime configuration via environment variables

The container MUST accept all analysis parameters through environment variables, eliminating the need for image rebuilds when changing configuration.

#### Scenario: Run with default configuration
- Given a Docker container with no environment variables set
- When the container starts with `run-single-trait` command
- Then it should use default values for all parameters (MODELS=BLINK,FarmCPU, PCA_COMPONENTS=3, etc.)
- And run GWAS analysis successfully

#### Scenario: Run with custom models
- Given environment variable `MODELS=BLINK`
- When the container runs
- Then it should only run the BLINK model
- And not run FarmCPU or other models

#### Scenario: Run with custom PCA components
- Given environment variable `PCA_COMPONENTS=5`
- When the container runs
- Then it should use 5 PCA components for population structure correction

### Requirement: Entrypoint MUST validate configuration before execution

The container entrypoint MUST validate all configuration values before starting R scripts, failing fast with clear error messages.

#### Scenario: Invalid model name rejected
- Given environment variable `MODELS=INVALID`
- When the container starts
- Then it should exit with error code 1
- And display error message listing valid models (BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM)

#### Scenario: PCA components out of range rejected
- Given environment variable `PCA_COMPONENTS=100`
- When the container starts
- Then it should exit with error code 1
- And indicate the valid range is 0-20

#### Scenario: Missing required paths detected
- Given `DATA_PATH` points to non-existent directory
- When the container starts
- Then it should exit with error code 1
- And list the missing paths clearly

### Requirement: Shell scripts MUST load configuration from .env file

All RunAI helper scripts MUST load configuration from `.env` file if present, with proper precedence.

#### Scenario: Script loads .env file
- Given a `.env` file exists in project root with `PROJECT=talmo-lab`
- When `submit-all-traits-runai.sh` runs
- Then it should read PROJECT value from `.env`
- And use that value for job submission

#### Scenario: Script works without .env file
- Given no `.env` file exists
- When `submit-all-traits-runai.sh` runs
- Then it should use default values
- And complete successfully

#### Scenario: Environment variables override .env file
- Given `.env` file has `MODELS=BLINK`
- And environment variable `MODELS=FarmCPU` is set
- When the script runs
- Then it should use `FarmCPU` (env var takes precedence)

### Requirement: Documentation MUST provide comprehensive .env.example

The repository MUST include a well-documented `.env.example` file.

#### Scenario: .env.example documents all configurable variables
- Given the `.env.example` file
- Then it should list all environment variables: TRAIT_INDEX, MODELS, PCA_COMPONENTS, SNP_THRESHOLD, MAF_FILTER, etc.
- And provide descriptions and valid ranges for each
- And include usage examples for Docker, RunAI, and Argo

#### Scenario: .env.example clarifies non-configurable options
- Given the `.env.example` file
- Then it should clearly indicate which options are NOT configurable via environment variables
- And explain how to change those (modify R scripts directly)

### Requirement: Pipeline MUST NOT depend on config.yaml file

All pipeline components MUST configure via environment variables only, with no dependency on config.yaml files.

#### Scenario: Argo templates use only environment variables
- Given the Argo workflow templates
- Then they should not pass `--config` arguments
- And should configure the container only via `env:` section

#### Scenario: RunAI template has no config infrastructure
- Given the RunAI job template
- Then it should not have ConfigMap definitions for config.yaml
- And should not mount config volumes
- And should not pass `--config` arguments

#### Scenario: validate_inputs.R uses environment variables
- Given the validate_inputs.R script
- Then it should read configuration from environment variables
- And should not require yaml library
- And should not attempt to read config.yaml file

### Requirement: FDR-Controlled Significance Threshold

The system SHALL support False Discovery Rate (FDR) controlled significance thresholds for GWAS analysis via the `SNP_FDR` environment variable.

#### Scenario: FDR threshold specified
- **WHEN** `SNP_FDR` environment variable is set to a value (e.g., 0.05)
- **THEN** the GAPIT() call includes `SNP.FDR` parameter with the specified value
- **AND** runtime configuration logs display the FDR threshold
- **AND** GAPIT applies Benjamini-Hochberg correction at the specified threshold

#### Scenario: FDR threshold not specified
- **WHEN** `SNP_FDR` environment variable is empty or not set
- **THEN** the GAPIT() call does not include `SNP.FDR` parameter
- **AND** GAPIT uses default behavior (no FDR filtering)
- **AND** backward compatibility is maintained with existing pipelines

#### Scenario: FDR parameter validation
- **WHEN** `SNP_FDR` is set to a numeric value
- **THEN** value is validated to be between 0.0 and 1.0
- **AND** non-numeric values result in validation error with clear message

### Requirement: FDR Configuration Documentation

The system SHALL document the `SNP_FDR` configuration option in `.env.example`.

#### Scenario: Environment variable documentation
- **WHEN** user views `.env.example`
- **THEN** `SNP_FDR` is documented with usage examples
- **AND** relationship to `SNP_THRESHOLD` is explained
- **AND** recommended values (0.05, 0.1) are listed

### Requirement: Argo Workflow FDR Support

Argo WorkflowTemplates and Workflows SHALL support the `snp-fdr` parameter for FDR-controlled analysis.

#### Scenario: WorkflowTemplate accepts snp-fdr parameter
- **GIVEN** the `gapit3-gwas-single-trait` WorkflowTemplate
- **WHEN** the template is invoked with a `snp-fdr` parameter
- **THEN** the `SNP_FDR` environment variable is set in the container
- **AND** the value is passed to the entrypoint script

#### Scenario: WorkflowTemplate default for snp-fdr
- **GIVEN** the `gapit3-gwas-single-trait` WorkflowTemplate
- **WHEN** `snp-fdr` parameter is not provided
- **THEN** the default value is empty string (FDR disabled)
- **AND** backward compatibility is maintained

#### Scenario: Workflow passes snp-fdr to template
- **GIVEN** a workflow file (test or parallel pipeline)
- **WHEN** the workflow passes `snp-fdr` to templateRef
- **THEN** the value propagates to the WorkflowTemplate
- **AND** all trait pods receive the same FDR threshold

### Requirement: Batch Submission FDR Support

Batch submission scripts SHALL support the `SNP_FDR` environment variable.

#### Scenario: submit-all-traits-runai.sh loads SNP_FDR
- **GIVEN** the batch submission script
- **WHEN** `SNP_FDR` is set in the environment or .env file
- **THEN** the value is passed to each RunAI workspace submission
- **AND** the value is displayed in submission output

#### Scenario: submit-all-traits-runai.sh default
- **GIVEN** the batch submission script
- **WHEN** `SNP_FDR` is not set
- **THEN** the parameter is not passed (or passed as empty)
- **AND** backward compatibility is maintained

