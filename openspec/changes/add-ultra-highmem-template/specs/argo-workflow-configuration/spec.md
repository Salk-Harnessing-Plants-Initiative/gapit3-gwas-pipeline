## MODIFIED Requirements

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

#### Scenario: Ultra-high-memory retry for FarmCPU failures

- **GIVEN** traits that failed with OOM at 96Gi highmem template
- **AND** partial outputs show BLINK completed but FarmCPU failed
- **WHEN** the user specifies `--ultrahighmem` flag
- **THEN** the generated workflow references `gapit3-gwas-single-trait-ultrahighmem` template
- **AND** the template provides 160Gi memory request and 180Gi limit
- **AND** the template provides 16 CPU cores request and 24 limit
- **AND** environment variables set OPENBLAS_NUM_THREADS=16 and OMP_NUM_THREADS=16

#### Scenario: Workflow submission

- **GIVEN** a valid retry workflow YAML
- **WHEN** the user specifies `--submit` flag
- **THEN** the script submits via `argo submit`
- **AND** displays the new workflow name
- **AND** optionally watches with `--watch`

#### Scenario: Configurable parallelism with template-specific defaults

- **GIVEN** a retry workflow being generated
- **WHEN** no `--parallelism` flag is specified
- **THEN** the script uses template-specific defaults:
  - standard template: 10 parallel jobs
  - highmem template: 10 parallel jobs
  - ultrahighmem template: 5 parallel jobs
- **AND** the parallelism value is included in the generated workflow YAML

#### Scenario: User-specified parallelism override

- **GIVEN** a user wants to control cluster resource usage
- **WHEN** the user specifies `--parallelism N` flag
- **THEN** the generated workflow uses N as the parallelism value
- **AND** this overrides the template-specific default
- **AND** the value is validated to be a positive integer

#### Scenario: Parallelism displayed in dry-run output

- **GIVEN** a retry request with `--dry-run` flag
- **WHEN** the script generates the retry workflow
- **THEN** the output clearly shows the parallelism value being used
- **AND** indicates whether it is the default or user-specified

## ADDED Requirements

### Requirement: Ultra-High-Memory WorkflowTemplate

The system SHALL provide a WorkflowTemplate with 160Gi memory allocation for GWAS datasets where FarmCPU or MLM exceeds the 96Gi highmem template capacity.

#### Scenario: Template exists with correct resource allocation

- **GIVEN** the cluster has Argo Workflows installed
- **WHEN** a user queries available WorkflowTemplates
- **THEN** `gapit3-gwas-single-trait-ultrahighmem` is listed
- **AND** the template specifies memory request of 160Gi and limit of 180Gi
- **AND** the template specifies CPU request of 16 and limit of 24

#### Scenario: Template used for large datasets

- **GIVEN** a GWAS dataset with >2 million SNPs and >500 samples
- **AND** the base genotype matrix exceeds 10GB (samples × SNPs × 8 bytes)
- **WHEN** a workflow references the ultrahighmem template
- **THEN** jobs complete successfully without OOMKilled errors
- **AND** FarmCPU and MLM models complete for complex traits

#### Scenario: Template selection guidance documented

- **GIVEN** a user needs to choose between standard, highmem, and ultrahighmem templates
- **WHEN** they consult the documentation
- **THEN** they find a decision tree based on:
  1. Base matrix size: (samples × SNPs × 8) / 1024³ GB
  2. Models being run: BLINK only, BLINK+FarmCPU, or all three
  3. Trait complexity: simple vs complex genetic architecture
- **AND** the guidance recommends ultrahighmem for base matrix >10GB with FarmCPU or MLM

### Requirement: Three-Tier Template Selection

The system SHALL provide clear guidance for selecting among three memory tiers based on dataset characteristics and GAPIT model requirements.

#### Scenario: Template tier table in documentation

- **GIVEN** a user reviewing cluster/argo/README.md
- **WHEN** they look for resource configuration guidance
- **THEN** they find a table with three tiers:
  | Template | Memory | CPU | Use Case |
  |----------|--------|-----|----------|
  | standard | 64Gi | 12 | <500K SNPs, <300 samples, BLINK only |
  | highmem | 96Gi | 16 | 500K-1.5M SNPs, <600 samples |
  | ultrahighmem | 160Gi | 16 | >1.5M SNPs or >600 samples, FarmCPU/MLM |

#### Scenario: FarmCPU memory warning documented

- **GIVEN** the docs/RESOURCE_SIZING.md documentation
- **WHEN** a user reads about FarmCPU memory requirements
- **THEN** they learn that FarmCPU's iterative pseudo-QTN algorithm uses 8× more memory than reported in original publications
- **AND** they understand that FarmCPU is the most common OOMKilled failure point
- **AND** they find the formula: `FarmCPU Memory (GB) = Base × 3.25 × Safety`
