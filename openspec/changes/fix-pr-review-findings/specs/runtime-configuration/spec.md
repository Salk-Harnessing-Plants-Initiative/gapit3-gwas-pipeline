## MODIFIED Requirements

### Requirement: Entrypoint MUST validate configuration before execution

The container entrypoint MUST validate all configuration values before starting R scripts, failing fast with clear error messages.

**Modification**: The `exec` command MUST use bash array expansion (`"${cmd_array[@]}"`) to prevent word splitting. ANSI color codes MUST be conditional on terminal attachment (`[ -t 1 ]`). The threshold validation regex MUST be tightened to `^[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$` to reject invalid formats. The `validate_paths` function exit code 2 MUST be captured and propagated (not collapsed to generic failure). Whitespace trimming MUST use shell parameter expansion (`${var##...}`) instead of fragile `xargs` piping.

#### Scenario: Invalid model name rejected

- **GIVEN** environment variable `MODELS=INVALID`
- **WHEN** the container starts
- **THEN** it MUST exit with error code 1
- **AND** display error message listing valid models (BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM)

#### Scenario: Exec uses array expansion

- **GIVEN** a command string with arguments containing spaces
- **WHEN** the entrypoint calls `exec`
- **THEN** it MUST use `exec "${cmd_array[@]}"` form
- **AND** MUST NOT use `exec $cmd` which causes word splitting

#### Scenario: ANSI colors disabled in non-interactive mode

- **GIVEN** the container is running in a non-interactive context (e.g., Argo workflow pod)
- **AND** stdout is not a terminal (`[ ! -t 1 ]`)
- **WHEN** log messages are printed
- **THEN** ANSI color escape codes MUST NOT be included
- **AND** log output MUST be clean plain text

#### Scenario: Threshold validation rejects malformed values

- **GIVEN** environment variable `SNP_THRESHOLD=abc123`
- **WHEN** the entrypoint validates inputs
- **THEN** validation MUST fail with a clear error message
- **AND** values like `5e-8`, `0.05`, `1.0e-10` MUST pass validation

#### Scenario: validate_paths exit code 2 propagated

- **GIVEN** the `validate_paths` function detects a missing required path
- **AND** the function returns exit code 2
- **WHEN** the entrypoint calls `validate_paths`
- **THEN** the exit code 2 MUST be captured via `$?`
- **AND** the entrypoint MUST exit with the same code 2
- **AND** MUST NOT collapse to generic exit code 1

### Requirement: Container MUST accept runtime configuration via environment variables

The container MUST accept all analysis parameters through environment variables, eliminating the need for image rebuilds when changing configuration.

**Modification**: The `get_env_or_null()` R helper function MUST apply `trimws()` to environment variable values before returning them, to handle whitespace introduced by shell quoting or YAML formatting.

#### Scenario: Environment variable with trailing whitespace

- **GIVEN** environment variable `MODELS` is set to `"BLINK "` (with trailing space)
- **WHEN** `get_env_or_null("MODELS")` is called
- **THEN** it MUST return `"BLINK"` (trimmed)
- **AND** MUST NOT return `"BLINK "` with trailing whitespace

#### Scenario: Run with default configuration

- **GIVEN** a Docker container with no environment variables set
- **WHEN** the container starts with `run-single-trait` command
- **THEN** it MUST use default values for all parameters (MODELS=BLINK,FarmCPU, PCA_COMPONENTS=3, etc.)
- **AND** run GWAS analysis successfully

## ADDED Requirements

### Requirement: Shell scripts must sanitize external inputs

Shell scripts that construct commands from user-provided or environment-sourced values MUST sanitize inputs to prevent command injection and YAML injection.

#### Scenario: Dataset name sanitized before use in commands

- **GIVEN** `$DATASET_NAME` contains characters outside `[:alnum:]._-/`
- **WHEN** the variable is used in a command (e.g., PowerShell invocation)
- **THEN** the value MUST be sanitized via `tr -cd '[:alnum:]._-/'` or equivalent
- **AND** injection characters (`;`, `|`, `$()`, backticks) MUST be stripped

#### Scenario: Numeric CLI arguments validated

- **GIVEN** a script accepts `--expected-traits` as a numeric argument
- **WHEN** the argument value is non-numeric
- **THEN** the script MUST reject it with a clear error message
- **AND** MUST NOT pass it to arithmetic operations

#### Scenario: YAML interpolation escaped

- **GIVEN** a script generates YAML by interpolating shell variables
- **WHEN** a variable value contains YAML special characters (`:`, `{`, `}`, `[`, `]`)
- **THEN** the value MUST be quoted in the generated YAML
- **AND** YAML injection MUST NOT be possible

#### Scenario: Temp files cleaned up on exit

- **GIVEN** a script creates temporary files (e.g., `$TEMP_YAML`)
- **WHEN** the script exits (normally or via signal)
- **THEN** a trap MUST ensure temporary files are removed
- **AND** the trap MUST handle EXIT, INT, and TERM signals
