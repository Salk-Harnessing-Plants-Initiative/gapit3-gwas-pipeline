# results-aggregation Delta Spec: Dynamic Model Detection

## ADDED Requirements

### Requirement: Aggregation must auto-detect expected models from workflow metadata

When the `--models` CLI flag is not specified (using default value), the aggregation script MUST attempt to auto-detect the expected models from the first trait directory's `gapit_metadata.json` file.

#### Scenario: Auto-detect models from v3.0.0 metadata

- **GIVEN** trait directories exist with `gapit_metadata.json` files
- **AND** the first trait's metadata contains: `{"model": "BLINK,FarmCPU"}`
- **AND** the `--models` flag is NOT specified
- **WHEN** the aggregation script runs
- **THEN** the script MUST:
  - Read the first trait's `gapit_metadata.json`
  - Extract models: `["BLINK", "FarmCPU"]`
  - Log: `"Auto-detected models from metadata: BLINK, FarmCPU"`
  - Use detected models for completeness checking

#### Scenario: Auto-detect models from legacy metadata format

- **GIVEN** trait directories exist with `gapit_metadata.json` files
- **AND** the first trait's metadata contains: `{"models": "MLM"}` (legacy parameter name)
- **AND** the `--models` flag is NOT specified
- **WHEN** the aggregation script runs
- **THEN** the script MUST:
  - Check for v3.0.0 `model` parameter first
  - Fall back to legacy `models` parameter
  - Extract models: `["MLM"]`
  - Use detected model for completeness checking

#### Scenario: CLI models flag overrides auto-detection

- **GIVEN** trait directories exist with metadata indicating `model: "BLINK,FarmCPU"`
- **AND** the CLI specifies `--models "MLM"`
- **WHEN** the aggregation script runs
- **THEN** the script MUST:
  - NOT read metadata for model detection
  - Log: `"Using CLI-specified models: MLM"`
  - Use only `["MLM"]` for completeness checking

#### Scenario: Fallback to default when metadata unavailable

- **GIVEN** trait directories exist WITHOUT `gapit_metadata.json` files
- **AND** the `--models` flag is NOT specified
- **WHEN** the aggregation script runs
- **THEN** the script MUST:
  - Emit warning: `"Could not auto-detect models from metadata; using default: BLINK,FarmCPU,MLM"`
  - Use default models `["BLINK", "FarmCPU", "MLM"]` for completeness checking
  - NOT fail the aggregation

#### Scenario: Fallback when metadata is malformed

- **GIVEN** trait directories exist with malformed `gapit_metadata.json` (invalid JSON)
- **AND** the `--models` flag is NOT specified
- **WHEN** the aggregation script runs
- **THEN** the script MUST:
  - Emit warning about malformed metadata
  - Fall back to default models
  - NOT fail the aggregation

---

### Requirement: Model names must be validated against known GAPIT models

The aggregation script MUST validate detected or specified model names against a canonical list of known GAPIT models and emit warnings for unrecognized models.

#### Scenario: All models are recognized

- **GIVEN** models to validate: `["BLINK", "FarmCPU", "MLM"]`
- **WHEN** model validation runs
- **THEN** validation MUST:
  - Return valid = TRUE
  - Return empty invalid_models list
  - NOT emit any warnings

#### Scenario: Unknown model name detected

- **GIVEN** models to validate: `["BLINK", "TYPO_MODEL"]`
- **WHEN** model validation runs
- **THEN** validation MUST:
  - Return valid = FALSE
  - Return invalid_models = `["TYPO_MODEL"]`
  - Emit warning: `"Unrecognized model name: TYPO_MODEL. Known models: BLINK, FarmCPU, MLM, ..."`

#### Scenario: Case-insensitive model matching

- **GIVEN** models to validate: `["blink", "farmcpu"]` (lowercase)
- **WHEN** model validation runs
- **THEN** validation MUST:
  - Match case-insensitively against known models
  - Return valid = TRUE
  - Use canonical form (BLINK, FarmCPU) for internal processing

---

### Requirement: Single authoritative list of known GAPIT models

The aggregation script MUST define a single constant containing all known GAPIT model names, eliminating duplicate hardcoded lists.

#### Scenario: Known models constant includes all GAPIT models

- **GIVEN** the KNOWN_GAPIT_MODELS constant in collect_results.R
- **WHEN** inspecting the constant
- **THEN** it MUST include at minimum:
  - `BLINK`
  - `FarmCPU`
  - `MLM`
  - `MLMM`
  - `GLM`
  - `SUPER`
  - `CMLM`
  - `FarmCPU.LM`
  - `Blink.LM`

#### Scenario: No duplicate model lists in codebase

- **GIVEN** the collect_results.R script
- **WHEN** searching for hardcoded model lists
- **THEN** there MUST be exactly one authoritative list (KNOWN_GAPIT_MODELS)
- **AND** all model validation MUST reference this single constant

## MODIFIED Requirements

### Requirement: Fail-fast on incomplete traits

When `GAPIT.Association.Filter_GWAS_results.csv` does not exist for a trait, the aggregation script MUST fail with a clear error message by default. The Filter file is the definitive completion signal - GAPIT only creates it after ALL models finish successfully.

**Modification**: Completeness checking now uses auto-detected models (when available) instead of only CLI-specified or default models. This ensures traits are correctly identified as complete when the workflow used a subset of models.

#### Scenario: Completeness uses auto-detected model subset

- **GIVEN** trait directories with metadata indicating `model: "BLINK"` (single model)
- **AND** Filter files exist for all traits
- **AND** GWAS_Results files exist only for BLINK (not FarmCPU or MLM)
- **WHEN** the aggregation script runs without `--models` flag
- **THEN** the script MUST:
  - Auto-detect expected model as `["BLINK"]`
  - Consider traits complete (they have BLINK results)
  - NOT fail due to "missing" FarmCPU or MLM results
  - Successfully aggregate all traits
