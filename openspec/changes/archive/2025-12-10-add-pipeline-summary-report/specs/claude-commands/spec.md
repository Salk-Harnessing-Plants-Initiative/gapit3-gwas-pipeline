## ADDED Requirements

### Requirement: Generate Pipeline Summary command

A Claude command MUST exist to generate human-readable markdown summaries from completed GWAS pipeline outputs.

#### Scenario: Generate summary from aggregated results directory

- **GIVEN** a completed pipeline with aggregated results at `Z:\users\eberrigan\20251208_...\outputs\aggregated_results\`
- **AND** the directory contains `summary_stats.json` and `all_traits_significant_snps.csv`
- **WHEN** user invokes `/generate-pipeline-summary` with the output path
- **THEN** the command MUST:
  - Read existing JSON and CSV files
  - Generate `pipeline_summary.md` in the same directory
  - Display success message with path to generated report
  - Show executive summary preview in console

#### Scenario: Handle missing required files

- **GIVEN** a directory path that does not contain `summary_stats.json`
- **WHEN** user invokes `/generate-pipeline-summary`
- **THEN** the command MUST:
  - Display error: "Missing required file: summary_stats.json"
  - Suggest running aggregation first
  - NOT create any output files

#### Scenario: Validate and report completeness

- **GIVEN** aggregated results with 186 traits
- **AND** 5 traits have missing metadata
- **WHEN** user invokes `/generate-pipeline-summary`
- **THEN** the command MUST:
  - Generate the summary report
  - Include warning in report about incomplete metadata
  - Display completeness percentage in console output