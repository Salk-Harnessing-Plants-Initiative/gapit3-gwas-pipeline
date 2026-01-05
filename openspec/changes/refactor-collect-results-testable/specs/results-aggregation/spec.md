# results-aggregation Delta Spec: Testable Module Architecture

## ADDED Requirements

### Requirement: Aggregation functions must be extractable as testable modules

The aggregation script MUST organize reusable functions into separate module files that can be sourced independently without triggering script execution, enabling unit testing.

#### Scenario: Sourcing aggregation_utils.R does not execute aggregation

- **GIVEN** the file `scripts/lib/aggregation_utils.R` exists
- **WHEN** an R session sources the file with `source("scripts/lib/aggregation_utils.R")`
- **THEN** the session MUST:
  - Have `extract_models_from_metadata` function available
  - Have `validate_model_names` function available
  - Have `detect_models_from_first_trait` function available
  - Have `get_gapit_param` function available
  - Have `select_best_trait_dirs` function available
  - NOT execute any aggregation logic
  - NOT require CLI arguments
  - NOT print any output

#### Scenario: Sourcing constants.R provides configuration values

- **GIVEN** the file `scripts/lib/constants.R` exists
- **WHEN** an R session sources the file
- **THEN** the session MUST have:
  - `KNOWN_GAPIT_MODELS` character vector with all supported models
  - `DEFAULT_MODELS` character vector with default model list
  - No side effects or console output

---

### Requirement: All extracted functions must be pure with explicit parameters

All functions in the aggregation modules MUST be pure functions with no reliance on global state - all inputs must be passed as explicit parameters.

#### Scenario: validate_model_names accepts custom known_models parameter

- **GIVEN** a custom list of known models `c("MODEL_A", "MODEL_B")`
- **WHEN** calling `validate_model_names(c("MODEL_A"), known_models = c("MODEL_A", "MODEL_B"))`
- **THEN** the function MUST:
  - Return `list(valid = TRUE, invalid_models = character(0))`
  - NOT reference global KNOWN_GAPIT_MODELS
  - Be deterministic (same input always gives same output)

#### Scenario: Functions work without global environment setup

- **GIVEN** a fresh R session with no global variables set
- **AND** modules are sourced
- **WHEN** calling any extracted function with valid parameters
- **THEN** the function MUST:
  - Execute successfully
  - NOT throw errors about missing global variables
  - Return expected results based only on provided parameters

---

### Requirement: Aggregation output must include configuration metadata

The `summary_stats.json` output MUST include a `configuration` section documenting all settings used during aggregation for reproducibility.

#### Scenario: Configuration section in summary_stats.json

- **GIVEN** aggregation runs with:
  - Auto-detected models: `["BLINK", "FarmCPU"]`
  - Significance threshold: `5e-8`
  - allow_incomplete: `false`
- **WHEN** aggregation completes successfully
- **THEN** `summary_stats.json` MUST include:
  ```json
  {
    "configuration": {
      "expected_models": ["BLINK", "FarmCPU"],
      "models_source": "auto-detected",
      "significance_threshold": 5e-8,
      "allow_incomplete": false
    }
  }
  ```

#### Scenario: CLI-specified models recorded in configuration

- **GIVEN** aggregation runs with `--models "MLM"`
- **WHEN** aggregation completes
- **THEN** `summary_stats.json` configuration MUST show:
  - `expected_models`: `["MLM"]`
  - `models_source`: `"cli"`

#### Scenario: Default models recorded when auto-detection fails

- **GIVEN** aggregation runs without `--models` flag
- **AND** no metadata files exist for auto-detection
- **WHEN** aggregation completes
- **THEN** `summary_stats.json` configuration MUST show:
  - `expected_models`: `["BLINK", "FarmCPU", "MLM"]`
  - `models_source`: `"default"`

---

### Requirement: Module sourcing must use robust path resolution

The main script MUST source modules using path resolution that works regardless of the current working directory.

#### Scenario: Script runs from project root

- **GIVEN** current directory is project root
- **WHEN** running `Rscript scripts/collect_results.R --output-dir /path`
- **THEN** modules MUST be sourced successfully

#### Scenario: Script runs from scripts directory

- **GIVEN** current directory is `scripts/`
- **WHEN** running `Rscript collect_results.R --output-dir /path`
- **THEN** modules MUST be sourced successfully

#### Scenario: Script runs via absolute path

- **GIVEN** any current directory
- **WHEN** running `Rscript /full/path/to/scripts/collect_results.R --output-dir /path`
- **THEN** modules MUST be sourced successfully

## MODIFIED Requirements

### Requirement: Results aggregation produces output CSV with complete SNP information

The aggregation script MUST produce a CSV file containing all significant SNPs from all traits with complete statistical information and model tracking.

**Modification**: The script now uses modular functions from `scripts/lib/aggregation_utils.R` for model validation and trait directory selection. The output format and content remain unchanged.

#### Scenario: Aggregation uses modular functions

- **GIVEN** the refactored `collect_results.R` that sources modules
- **WHEN** aggregation runs on a valid output directory
- **THEN** the behavior MUST be identical to the pre-refactor version:
  - Same output file names and formats
  - Same significant SNP detection logic
  - Same model tracking
  - Same deduplication behavior
