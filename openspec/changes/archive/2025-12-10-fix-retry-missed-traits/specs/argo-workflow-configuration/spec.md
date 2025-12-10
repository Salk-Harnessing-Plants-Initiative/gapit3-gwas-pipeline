## ADDED Requirements

### Requirement: Argo Workflow Retry Capability

The system SHALL provide a mechanism to retry failed or incomplete traits from a completed Argo workflow with configurable resource allocation. Incomplete traits are detected using the Filter file as the definitive completion signal.

#### Scenario: Auto-detect incomplete traits using Filter file as completion signal

- **GIVEN** a completed or stopped Argo workflow with output directory
- **WHEN** the user runs `retry-argo-traits.sh --workflow <name> --output-dir <path>`
- **THEN** the script extracts the models parameter from the workflow (e.g., "BLINK,FarmCPU,MLM")
- **AND** extracts the output-hostpath and trait range from the workflow
- **AND** inspects each trait output directory for:
  1. Missing output directory entirely
  2. Missing `GAPIT.Association.Filter_GWAS_results.csv` (definitive completion signal)
- **AND** identifies traits as incomplete if Filter file is missing (regardless of GWAS_Results files present)
- **AND** displays a summary showing which traits need retry and why

#### Scenario: Filter file as definitive completion check

- **GIVEN** a trait output directory with `GAPIT.Association.GWAS_Results.BLINK.*.csv` file
- **AND** the directory is missing `GAPIT.Association.Filter_GWAS_results.csv`
- **WHEN** the script inspects this directory
- **THEN** the trait is marked as incomplete
- **AND** the summary shows "missing Filter file" as the reason
- **AND** the trait is included in the retry list
- **AND** the presence of partial GWAS_Results files does NOT mark the trait as complete

#### Scenario: Stopped workflow with partial outputs detected

- **GIVEN** a workflow that was stopped mid-execution via `argo stop`
- **AND** some traits were running when stopped and created partial outputs (GWAS_Results but no Filter)
- **WHEN** the script runs with `--output-dir` flag
- **THEN** all partially-completed traits are detected via missing Filter file
- **AND** no traits are missed due to having some GWAS_Results files

#### Scenario: Manual trait specification

- **GIVEN** a user knows specific traits that need retry
- **WHEN** the user runs `retry-argo-traits.sh --traits 5,28,29,30,31`
- **THEN** the script uses the specified traits without auto-detection
- **AND** validates that trait indices are valid numbers

#### Scenario: Dry-run mode shows detection details

- **GIVEN** a retry request with `--dry-run` flag
- **WHEN** the script generates the retry workflow
- **THEN** it outputs the YAML to stdout or specified file
- **AND** does NOT submit to the cluster
- **AND** displays what would be submitted
- **AND** shows detection summary: "X traits incomplete (missing Filter file)"

#### Scenario: High-memory retry

- **GIVEN** traits that failed due to OOM (exit code 137)
- **WHEN** the user specifies `--highmem` flag
- **THEN** the generated workflow references `gapit3-gwas-single-trait-highmem` template
- **AND** the template provides 96Gi memory (vs 64Gi normal)
- **AND** the template provides 16 CPU cores (vs 12 normal)

#### Scenario: Workflow submission

- **GIVEN** a valid retry workflow YAML
- **WHEN** the user specifies `--submit` flag
- **THEN** the script submits via `argo submit`
- **AND** displays the new workflow name
- **AND** optionally watches with `--watch`
