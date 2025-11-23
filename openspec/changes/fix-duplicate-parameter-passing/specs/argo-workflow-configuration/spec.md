## ADDED Requirements

### Requirement: Environment Variable Parameter Passing

The Argo WorkflowTemplate SHALL pass all runtime parameters to containers exclusively via environment variables, not CLI arguments.

#### Scenario: MODELS parameter passed correctly
- **WHEN** a workflow is submitted with `models: "BLINK,FarmCPU,MLM"` parameter
- **THEN** the container receives `MODELS=BLINK,FarmCPU,MLM` as an environment variable
- **AND** the entrypoint uses this value for GWAS analysis
- **AND** no CLI argument like `--models` is passed

#### Scenario: TRAIT_INDEX parameter passed correctly
- **WHEN** a workflow task runs for trait index 42
- **THEN** the container receives `TRAIT_INDEX=42` as an environment variable
- **AND** the entrypoint uses this value to select the phenotype column

#### Scenario: All parameters visible in pod description
- **WHEN** a user runs `kubectl describe pod <pod-name>`
- **THEN** all configuration parameters are visible in the Environment section
- **AND** the user can verify the exact values being used

### Requirement: Minimal Container Arguments

The WorkflowTemplate container args SHALL contain only the command selector (e.g., `run-single-trait`), not runtime parameters.

#### Scenario: Container args specify command only
- **GIVEN** the WorkflowTemplate container configuration
- **WHEN** the container starts
- **THEN** `args` contains only `["run-single-trait"]` or equivalent command selector
- **AND** no parameter values like `--models` or `--trait-index` appear in args

#### Scenario: Parameters not duplicated in args and env
- **GIVEN** a runtime parameter like MODELS
- **WHEN** the WorkflowTemplate is defined
- **THEN** the parameter appears in exactly one location (env section)
- **AND** the parameter does NOT appear in both args and env sections

### Requirement: Parameter Documentation

The WorkflowTemplate SHALL include comments explaining the environment-variable-only parameter passing pattern.

#### Scenario: Future developer understands the pattern
- **GIVEN** a developer reading the WorkflowTemplate YAML
- **WHEN** they look at the container configuration
- **THEN** they find a comment explaining that parameters are passed via env vars
- **AND** the comment explains why CLI args are not used

## REMOVED Requirements

### Requirement: CLI Argument Parameter Passing

**Reason**: CLI arguments were passed but ignored by the entrypoint, causing silent failures where parameters appeared to be set but were not used.

**Migration**: All parameters previously passed as CLI arguments are now passed as environment variables. The entrypoint already reads from environment variables, so no code changes are needed in the entrypoint itself.

#### Affected CLI Arguments (removed):
- `--trait-index` -> Use `TRAIT_INDEX` env var
- `--models` -> Use `MODELS` env var
- `--config` -> Removed (not used by entrypoint)
- `--output-dir` -> Use `OUTPUT_PATH` env var
- `--threads` -> Use `OPENBLAS_NUM_THREADS` and `OMP_NUM_THREADS` env vars
