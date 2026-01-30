## ADDED Requirements

### Requirement: Data Validation Command

The system SHALL provide a `/validate-data` Claude command that validates GWAS input data directories against the requirements in `docs/DATA_REQUIREMENTS.md`.

#### Scenario: Validating complete data directory
- **WHEN** developer invokes `/validate-data <path>` with a valid data directory path
- **THEN** system validates:
  - Directory structure (`genotype/`, `phenotype/`, `metadata/` subdirectories)
  - Genotype file exists and is HapMap format (11 metadata columns + samples)
  - Phenotype file exists with `Taxa` column and numeric trait values
  - Sample IDs overlap between genotype and phenotype files
  - Optional accession IDs file format if present
- **AND** reports validation results with pass/fail status for each check
- **AND** provides actionable error messages for failures

#### Scenario: Validating data with missing files
- **WHEN** developer invokes `/validate-data <path>` with missing required files
- **THEN** system reports which files are missing
- **AND** provides expected file locations and formats

#### Scenario: Path mapping for cluster
- **WHEN** developer provides a Windows path (e.g., `Z:\users\...`)
- **THEN** system translates to cluster path (`/hpi/hpi_dev/users/...`) in output
- **AND** shows both Windows and cluster paths for clarity

### Requirement: RunAI Test Submission Command

The system SHALL provide a `/submit-runai-test` Claude command that submits test GWAS jobs to RunAI using the correct CLI v2 syntax.

#### Scenario: Submitting single trait test
- **WHEN** developer invokes `/submit-runai-test` with data path and trait index
- **THEN** system generates correct `runai workspace submit` command with:
  - `--host-path` for data and output mounts (NOT `--pvc`)
  - Environment variables for all configuration (NOT `--config`)
  - Correct mount-propagation settings
  - Standard resource requests (12 CPU, 32G memory)
- **AND** includes Git Bash path mangling fix (`MSYS_NO_PATHCONV=1`) when needed

#### Scenario: Submitting with FDR parameter
- **WHEN** developer invokes `/submit-runai-test` with `SNP_FDR` specified
- **THEN** system includes `--environment SNP_FDR=<value>` in command
- **AND** validates FDR value is between 0.0 and 1.0

#### Scenario: Monitoring submitted job
- **WHEN** test job is submitted successfully
- **THEN** command includes monitoring instructions:
  - `runai workspace describe <job-name> -p <project>`
  - `runai workspace logs <job-name> -p <project> --follow`

## MODIFIED Requirements

### Requirement: Workflow Management Commands

The system SHALL provide Claude slash commands for managing Argo workflows and RunAI jobs to simplify cluster operations.

#### Scenario: Submitting test workflow (Argo)
- **WHEN** developer invokes `/submit-test-workflow` command
- **THEN** system shows Argo workflow submission for 3-trait test
- **AND** provides alternative `/submit-runai-test` for RunAI-based submission

#### Scenario: Submitting test workflow (RunAI)
- **WHEN** developer needs RunAI submission instead of Argo
- **THEN** system directs to `/submit-runai-test` command
- **AND** explains that workspace workloads require manual termination while training workloads auto-complete

#### Scenario: Monitoring jobs
- **WHEN** developer invokes `/monitor-jobs` command
- **THEN** system displays real-time status of RunAI jobs using `scripts/monitor-runai-jobs.sh`

#### Scenario: Aggregating results
- **WHEN** developer invokes `/aggregate-results` command
- **THEN** system runs `scripts/aggregate-runai-results.sh` to collect GWAS results

#### Scenario: Cleaning up jobs
- **WHEN** developer invokes `/cleanup-jobs` command
- **THEN** system executes `scripts/cleanup-runai.sh` to remove failed/completed jobs
