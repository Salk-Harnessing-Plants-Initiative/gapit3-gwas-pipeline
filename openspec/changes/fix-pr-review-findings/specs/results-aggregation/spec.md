## MODIFIED Requirements

### Requirement: Aggregation must generate human-readable markdown summary report

The aggregation script MUST generate a `pipeline_summary.md` file alongside the existing JSON and CSV outputs, containing a formatted summary of the GWAS results suitable for sharing with scientific collaborators.

**Modification**: Duration values MUST be displayed in correct units. NA/NaN/NULL duration values MUST render as "N/A" instead of crashing. NA MAF values in top SNPs table MUST render as "N/A" instead of causing `sprintf` errors. The script MUST always create the output CSV file even when zero significant SNPs are found (header-only file), so that `--markdown-only` mode does not fail on missing CSV.

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
  - Create `all_traits_significant_snps.csv` with header row only (no data rows)
  - Executive summary shows "0 significant SNPs"
  - Top SNPs table shows "No significant SNPs found at threshold X"
  - Model statistics show all zeros
  - NOT fail or produce empty file

#### Scenario: Duration displayed in correct units

- **GIVEN** aggregation results with `total_duration_hours = 1.0` (meaning 1 hour)
- **WHEN** the executive summary is generated
- **THEN** the duration MUST display as "1.0 hours"
- **AND** MUST NOT display as "60.0 hours" (which would indicate the value was multiplied by 60 then labeled hours)

#### Scenario: NA MAF in top SNPs table

- **GIVEN** a BLINK model result where the MAF column contains NA (known GAPIT BLINK quirk)
- **WHEN** the top SNPs table is rendered in markdown
- **THEN** the MAF value MUST display as "N/A"
- **AND** MUST NOT crash with `sprintf("%.3f", NA)` error

#### Scenario: NaN or NA duration handled gracefully

- **GIVEN** a workflow where duration metadata is missing or corrupted
- **AND** `format_duration()` receives NaN, NA, or NULL as input
- **WHEN** the function is called
- **THEN** it MUST return "N/A"
- **AND** MUST NOT crash or produce "NaN minutes"

### Requirement: All extracted functions must be pure with explicit parameters

All functions in the aggregation modules MUST be pure functions with no reliance on global state - all inputs must be passed as explicit parameters.

**Modification**: `format_pvalue()` and `format_number()` MUST be vector-safe, handling inputs of length > 1 by applying element-wise via `vapply`. `collect_workflow_stats()` MUST use `<<-` (not `<-`) inside `tryCatch` error handlers to correctly assign to the enclosing scope. `select_best_trait_dirs()` MUST NOT depend on the `%>%` pipe operator from magrittr; use explicit `dplyr::` function calls instead.

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

#### Scenario: format_pvalue handles vector input

- **GIVEN** a vector of p-values including NA: `c(NA, 1e-5, 3.2e-10)`
- **WHEN** `format_pvalue()` is called with this vector
- **THEN** it MUST return a character vector of length 3
- **AND** NA inputs produce "NA" string
- **AND** numeric inputs produce formatted scientific notation

#### Scenario: collect_workflow_stats handles corrupted metadata

- **GIVEN** a trait directory with an invalid (non-JSON) `metadata.json` file
- **WHEN** `collect_workflow_stats()` processes this directory
- **THEN** the trait MUST be bucketed under workflow name "unknown"
- **AND** the function MUST NOT crash
- **AND** the error MUST be caught by the tryCatch handler using `<<-` assignment

### Requirement: Results aggregation produces output CSV with complete SNP information

The aggregation script MUST produce a CSV file containing all significant SNPs from all traits with complete statistical information and model tracking.

**Modification**: The rbind loop for combining trait results MUST use `lapply` + `do.call(rbind, ...)` instead of incremental `rbind` in a for-loop (O(n) vs O(n^2)). SNP overlap between models MUST be computed once via a shared helper function, not duplicated in multiple code paths. The `quit()` calls MUST include `save="no"` to prevent saving R workspace on exit. Trait directory matching MUST use a single standardized regex pattern `^trait_\\d+` across all code paths.

#### Scenario: Aggregation uses modular functions

- **GIVEN** the refactored `collect_results.R` that sources modules
- **WHEN** aggregation runs on a valid output directory
- **THEN** the behavior MUST be identical to the pre-refactor version:
  - Same output file names and formats
  - Same significant SNP detection logic
  - Same model tracking
  - Same deduplication behavior

#### Scenario: Efficient combination of trait results

- **GIVEN** 200 trait directories each with significant SNPs
- **WHEN** results are combined into a single data frame
- **THEN** the combination MUST use `lapply` + `do.call(rbind, ...)` pattern
- **AND** MUST NOT use incremental `rbind` inside a for-loop
- **AND** MUST complete in O(n) time complexity

## ADDED Requirements

### Requirement: Aggregation utility functions must be independently testable

The functions `check_trait_completeness` and `read_filter_file` MUST be defined in `scripts/lib/aggregation_utils.R` so that tests can source them directly without fragile brace-counting extraction from `scripts/collect_results.R`.

#### Scenario: Test sources aggregation_utils.R for check_trait_completeness

- **GIVEN** the file `scripts/lib/aggregation_utils.R`
- **WHEN** an R test session sources the file
- **THEN** `check_trait_completeness()` function MUST be available
- **AND** tests MUST NOT extract the function by parsing R source code with brace counting
