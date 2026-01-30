# results-aggregation Specification

## Purpose

This spec defines the behavior of the GAPIT results aggregation script (`scripts/collect_results.R`), which collects significant SNPs from multiple trait analyses into a single summary output with model tracking.
## Requirements
### Requirement: Aggregation must read GAPIT Filter files instead of complete GWAS_Results files

The aggregation script MUST read `GAPIT.Association.Filter_GWAS_results.csv` files which contain only significant SNPs instead of reading complete `GAPIT.Association.GWAS_Results.*.csv` files which contain all SNPs.

#### Scenario: Aggregating results from trait with Filter file

**Given** a trait directory containing:
- `GAPIT.Association.Filter_GWAS_results.csv` (5 rows: header + 4 significant SNPs)
- `GAPIT.Association.GWAS_Results.BLINK.trait_name.csv` (1,400,000 rows)

**When** the aggregation script processes this trait

**Then** the script MUST:
- Read `GAPIT.Association.Filter_GWAS_results.csv`
- NOT read `GAPIT.Association.GWAS_Results.BLINK.*.csv`
- Extract all 4 significant SNPs from Filter file
- Complete in <1 second for this trait

#### Scenario: Performance improvement for 186 traits with 2 models

**Given** 186 trait directories, each with BLINK and FarmCPU models
**And** each trait has ~5 significant SNPs on average

**When** the aggregation script processes all 186 traits

**Then** the script MUST:
- Read 186 Filter files (~1,000 total rows)
- NOT read 372 GWAS_Results files (~521M total rows)
- Complete in <30 seconds
- Use <2GB memory

---

### Requirement: Model information must be extracted from Filter file traits column

The aggregation script MUST parse the `traits` column in the Filter file to extract both the GAPIT model name and the trait name.

#### Scenario: Parsing standard model and trait name

**Given** a Filter file with row:
```csv
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,traits
SNP_123,1,12345,1.2e-9,0.15,500,0.05,2.3e-8,BLINK.root_length
```

**When** the script parses the `traits` column

**Then** the script MUST:
- Extract model: `"BLINK"` (everything before first period)
- Extract trait: `"root_length"` (everything after first period)
- Create columns: `model="BLINK"`, `trait="root_length"`
- Remove original `traits` column

#### Scenario: Parsing trait name with periods

**Given** a Filter file with `traits` value: `"BLINK.mean_GR_rootLength_day_1.2(NYC)"`

**When** the script parses the `traits` column

**Then** the script MUST:
- Extract model: `"BLINK"`
- Extract trait: `"mean_GR_rootLength_day_1.2(NYC)"` (preserving internal periods)
- NOT split on periods within trait name

---

### Requirement: Output CSV must include model column

The aggregated results CSV MUST include a `model` column indicating which GAPIT model identified each significant SNP.

#### Scenario: Output format with model column

**Given** aggregation of traits with BLINK and FarmCPU models

**When** the aggregated CSV is written

**Then** the output MUST have columns in this order:
```
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model
```

#### Scenario: SNP found by multiple models appears as multiple rows

**Given** a SNP at chr1:12345 found by BLINK (p=1.2e-9) and FarmCPU (p=2.3e-9)

**When** the aggregated CSV is created

**Then** the output MUST contain two rows:
```csv
SNP_123,1,12345,1.2e-9,0.15,500,0.05,2.3e-8,root_length,BLINK
SNP_123,1,12345,2.3e-9,0.15,500,0.06,3.1e-8,root_length,FarmCPU
```

---

### Requirement: Summary statistics must include per-model counts

The aggregation summary statistics MUST include counts of significant SNPs per model and identification of SNPs found by multiple models.

#### Scenario: Summary statistics for multi-model run

**Given** aggregated results with:
- 25 SNPs found only by BLINK
- 17 SNPs found only by FarmCPU
- 11 SNPs found by both models

**When** summary statistics are generated

**Then** `summary_stats.json` MUST include:
```json
{
  "snps_by_model": {
    "BLINK": 25,
    "FarmCPU": 28,
    "both_models": 11
  }
}
```

---

### Requirement: Aggregation must sort output by P.value

The aggregated results CSV MUST be sorted in ascending order by P.value.

#### Scenario: Output sorted by significance

**Given** aggregated SNPs with P.values: 5.2e-10, 1.2e-9, 3.4e-8, 8.7e-9

**When** the output CSV is written

**Then** rows MUST be sorted:
```
Row 1: P.value = 5.2e-10  (most significant)
Row 2: P.value = 1.2e-9
Row 3: P.value = 8.7e-9
Row 4: P.value = 3.4e-8
```

---

### Requirement: Console output must report per-model statistics

The aggregation script console output MUST display per-model SNP counts.

#### Scenario: Console output for multi-model aggregation

**Given** aggregation with BLINK and FarmCPU models

**When** the script runs

**Then** console output MUST include:
```
Collecting significant SNPs...
  - Reading Filter files (fast mode)
  - Models detected: BLINK, FarmCPU
  - Total significant SNPs: 42
    - BLINK: 25 SNPs
    - FarmCPU: 28 SNPs
    - Found by both models: 11 SNPs
```

---

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

### Requirement: Aggregation must generate human-readable markdown summary report

The aggregation script MUST generate a `pipeline_summary.md` file alongside the existing JSON and CSV outputs, containing a formatted summary of the GWAS results suitable for sharing with scientific collaborators.

#### Scenario: Markdown report generated during successful aggregation

- **GIVEN** aggregation of 186 traits with BLINK, FarmCPU, and MLM models
- **AND** aggregation completes successfully producing `summary_stats.json` and `all_traits_significant_snps.csv`
- **WHEN** the aggregation script finishes
- **THEN** the script MUST:
  - Create `pipeline_summary.md` in the same directory as other outputs
  - Include executive summary with total traits, success rate, and total significant SNPs
  - Include top 20 SNPs table sorted by p-value
  - Include model statistics breakdown
  - Include reproducibility information (workflow ID, timestamp)
  - Complete markdown generation in <5 seconds

#### Scenario: Markdown report handles zero significant SNPs

- **GIVEN** aggregation of traits where no SNPs meet significance threshold
- **WHEN** the aggregation script finishes
- **THEN** the script MUST:
  - Create `pipeline_summary.md` with appropriate message
  - Executive summary shows "0 significant SNPs"
  - Top SNPs table shows "No significant SNPs found at threshold X"
  - Model statistics show all zeros
  - NOT fail or produce empty file

#### Scenario: Markdown can be regenerated from existing data

- **GIVEN** existing `summary_stats.json` and `all_traits_significant_snps.csv` files
- **AND** user runs aggregation with `--markdown-only` flag
- **WHEN** the script executes
- **THEN** the script MUST:
  - Read existing JSON and CSV files
  - Generate new `pipeline_summary.md`
  - NOT re-read trait directories
  - NOT modify existing JSON or CSV files

---

### Requirement: Markdown summary must include executive summary section

The markdown report MUST begin with an executive summary section providing at-a-glance statistics for quick assessment.

#### Scenario: Executive summary content for complete run

- **GIVEN** aggregation results with:
  - Workflow ID: `gapit3-gwas-parallel-6hjx8`
  - 186 traits, all successful
  - 1886 significant SNPs
  - Top hit: PERL1.8641002 with p-value 3.97e-88
- **WHEN** markdown report is generated
- **THEN** the executive summary MUST include:
  ```markdown
  ## Executive Summary

  | Metric | Value |
  |--------|-------|
  | Dataset | gapit3-gwas-parallel-6hjx8 |
  | Analysis Date | 2025-12-09 |
  | Total Traits | 186 |
  | Successful | 186 (100%) |
  | Failed | 0 |
  | Total Significant SNPs | 1,886 |
  | Top Hit | PERL1.8641002 (p = 3.97e-88) |
  | Top Trait | mean_TotLen.EucLen_day_1(NYC) (668 SNPs) |
  ```

#### Scenario: Executive summary with partial failures

- **GIVEN** aggregation with `--allow-incomplete` flag
- **AND** 181 successful traits, 5 skipped due to missing Filter files
- **WHEN** markdown report is generated
- **THEN** the executive summary MUST show:
  - Total Traits: 186
  - Successful: 181 (97.3%)
  - Failed/Skipped: 5
  - Warning note about incomplete traits

---

### Requirement: Markdown summary must include top SNPs table

The markdown report MUST include a table of the most significant SNPs sorted by p-value.

#### Scenario: Top 20 SNPs displayed in table format

- **GIVEN** 1886 significant SNPs across multiple traits
- **WHEN** markdown report is generated
- **THEN** the top SNPs section MUST:
  - Show heading "## Top Significant SNPs"
  - Display exactly 20 rows (or all if fewer than 20)
  - Include columns: Rank, SNP, Chr, Pos, P-value, MAF, Model, Trait
  - Sort by P-value ascending (most significant first)
  - Format p-values in scientific notation (e.g., "3.97e-88")
  - Truncate trait names longer than 40 characters with "..."
  - Include note: "Showing top 20 of 1,886 total significant SNPs"

#### Scenario: Top SNPs table with duplicate SNP across models

- **GIVEN** SNP PERL1.8641127 found by both BLINK and FarmCPU
- **WHEN** markdown report is generated
- **THEN** the table MUST:
  - Show each (SNP, model) combination as separate row
  - Display the model that found it with lower p-value first

---

### Requirement: Markdown summary must include model statistics

The markdown report MUST include a breakdown of significant SNPs by GWAS model.

#### Scenario: Model statistics for multi-model run

- **GIVEN** aggregation results with:
  - FarmCPU: 1345 SNPs
  - BLINK: 427 SNPs
  - MLM: 114 SNPs
  - Overlap (found by 2+ models): 198 SNPs
- **WHEN** markdown report is generated
- **THEN** the model statistics section MUST include:
  ```markdown
  ## Model Statistics

  | Model | SNPs Found | % of Total |
  |-------|------------|------------|
  | FarmCPU | 1,345 | 71.4% |
  | BLINK | 427 | 22.6% |
  | MLM | 114 | 6.0% |

  **Cross-Model Validation:** 198 SNPs (10.5%) found by multiple models
  ```

---

### Requirement: Markdown summary must include chromosome distribution

The markdown report MUST include a summary of significant SNPs by chromosome.

#### Scenario: Chromosome distribution table

- **GIVEN** significant SNPs distributed across 5 chromosomes:
  - Chr 4: 809 SNPs
  - Chr 1: 495 SNPs
  - Chr 5: 256 SNPs
  - Chr 2: 173 SNPs
  - Chr 3: 153 SNPs
- **WHEN** markdown report is generated
- **THEN** the chromosome section MUST include:
  ```markdown
  ## Chromosome Distribution

  | Chromosome | SNP Count | % of Total |
  |------------|-----------|------------|
  | 4 | 809 | 42.9% |
  | 1 | 495 | 26.2% |
  | 5 | 256 | 13.6% |
  | 2 | 173 | 9.2% |
  | 3 | 153 | 8.1% |
  ```

---

### Requirement: Markdown summary must include reproducibility information

The markdown report MUST include provenance information for FAIR compliance and reproducibility.

#### Scenario: Reproducibility block with full provenance

- **GIVEN** aggregation run with Argo workflow metadata available
- **WHEN** markdown report is generated
- **THEN** the reproducibility section MUST include:
  ```markdown
  ## Reproducibility

  | Field | Value |
  |-------|-------|
  | Workflow ID | gapit3-gwas-parallel-6hjx8 |
  | Workflow UID | abc123-def456-... |
  | Container Image | ghcr.io/talmo-lab/gapit3-gwas-pipeline:sha-xyz |
  | Collection Time | 2025-12-09 21:25:24 |
  | Aggregation Host | collector-pod-xyz |
  | R Version | R version 4.4.1 (2024-06-14) |
  | GAPIT Version | 3.5.0 |
  ```

#### Scenario: Reproducibility block with missing provenance

- **GIVEN** aggregation run outside Argo (local execution)
- **AND** workflow metadata not available
- **WHEN** markdown report is generated
- **THEN** the reproducibility section MUST:
  - Show "N/A" for unavailable fields
  - Still include available fields (collection time, R version)
  - NOT fail or omit the section entirely

---

### Requirement: Markdown generation can be disabled

The aggregation script MUST support a `--no-markdown` flag to skip markdown report generation.

#### Scenario: Skip markdown generation with flag

- **GIVEN** user runs aggregation with `--no-markdown` flag
- **WHEN** aggregation completes
- **THEN** the script MUST:
  - Create `summary_stats.json` and `all_traits_significant_snps.csv`
  - NOT create `pipeline_summary.md`
  - Print message: "Skipping markdown report generation (--no-markdown)"

---

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

## Reference: GAPIT Output Quirks

This section documents known GAPIT output format quirks that the aggregation script handles. This is a reference for maintainers and is not a normative requirement.

### BLINK Column Order Issue

GAPIT's BLINK model outputs the Filter file with columns in a different order than other models:

| Model | MAF Column Contains |
|-------|---------------------|
| MLM, FarmCPU, GLM | Minor allele frequency (0.0-0.5) |
| BLINK | Sample count (e.g., 536) - **incorrect** |

The aggregation script detects MAF values > 1 and sets them to NA, logging a warning.

### NYC/Kansas Duplicate Outputs

When `Multiple_analysis=TRUE`, GAPIT generates two sets of output files:
- Files ending in `(NYC)` - New York City method (standard single-locus)
- Files ending in `(Kansas)` - Kansas method (multi-locus variant)

**These contain identical data.** The Filter file only includes NYC results to avoid duplication. The aggregation script parses the suffix into an `analysis_type` column.

### Filter File Column Limitations

The Filter file (`GAPIT.Association.Filter_GWAS_results.csv`) contains only:
- `SNP`, `Chr`, `Pos`, `P.value`, `MAF`, `traits`

The full GWAS_Results files additionally contain `nobs`, `Effect`, `H&B.P.Value` but are not used for aggregation due to their size (1.4M rows per model per trait).
