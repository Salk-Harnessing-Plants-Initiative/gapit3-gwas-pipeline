# Runtime Configuration

Runtime configuration for the GAPIT3 GWAS pipeline through environment variables.

## ADDED Requirements

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
