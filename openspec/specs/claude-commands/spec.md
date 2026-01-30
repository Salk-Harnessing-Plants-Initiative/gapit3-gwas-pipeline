# claude-commands Specification

## Purpose
TBD - created by archiving change add-claude-dev-commands. Update Purpose after archive.
## Requirements
### Requirement: Testing Commands
The system SHALL provide Claude slash commands for executing R unit tests, coverage analysis, and Docker functional tests to streamline development workflows.

#### Scenario: Running R unit tests
- **WHEN** developer invokes `/test-r` command
- **THEN** system executes `Rscript tests/testthat.R` and displays test results

#### Scenario: Analyzing test coverage
- **WHEN** developer invokes `/test-r-coverage` command
- **THEN** system runs tests with coverage reporting and displays uncovered lines

#### Scenario: Building Docker image
- **WHEN** developer invokes `/docker-build` command
- **THEN** system executes `docker build -t gapit3-gwas-pipeline .` with appropriate tags

#### Scenario: Running Docker functional tests
- **WHEN** developer invokes `/docker-test` command
- **THEN** system runs validation, trait extraction, and entrypoint tests in Docker container

### Requirement: Validation Commands
The system SHALL provide Claude slash commands for validating bash scripts, YAML workflows, and R code to ensure code quality before commits.

#### Scenario: Validating bash scripts
- **WHEN** developer invokes `/validate-bash` command
- **THEN** system runs shellcheck and bash syntax validation on all scripts in `scripts/` directory

#### Scenario: Validating YAML workflows
- **WHEN** developer invokes `/validate-yaml` command
- **THEN** system validates all Argo workflow YAML files for syntax and schema correctness

#### Scenario: Validating R scripts
- **WHEN** developer invokes `/validate-r` command
- **THEN** system checks R syntax and runs static analysis on scripts

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

### Requirement: Pull Request Review Command
The system SHALL provide a comprehensive PR review command that uses planning mode and ultrathink to analyze code changes, read existing PR comments, and post detailed reviews via GitHub CLI.

#### Scenario: Reviewing PR with comments
- **WHEN** developer invokes `/review-pr <PR_NUMBER>` command
- **THEN** system:
  - Activates planning mode for structured review approach
  - Enables ultrathink for deep analysis
  - Fetches PR details via `gh pr view <PR_NUMBER> --comments`
  - Reads inline code comments via `gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments`
  - Reads review summaries via `gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/reviews`
  - Analyzes code changes for correctness, style, and best practices
  - Posts comprehensive review via `gh pr review <PR_NUMBER> --comment --body "..."`

#### Scenario: Reviewing PR without existing comments
- **WHEN** developer invokes `/review-pr <PR_NUMBER>` command on PR with no comments
- **THEN** system performs full code review and posts initial review feedback via gh CLI

#### Scenario: Addressing review feedback
- **WHEN** PR has review comments and developer invokes `/review-pr <PR_NUMBER>`
- **THEN** system analyzes existing feedback, verifies fixes, and posts follow-up review

### Requirement: Pull Request Description Command
The system SHALL provide a command to generate comprehensive PR descriptions based on git diff and commit history.

#### Scenario: Generating PR description
- **WHEN** developer invokes `/pr-description` command
- **THEN** system:
  - Analyzes `git diff main...HEAD`
  - Reviews commit messages since branch divergence
  - Generates structured PR description with summary, changes, and testing notes
  - Formats output as markdown ready for GitHub PR

### Requirement: Changelog Update Command
The system SHALL provide a command to help maintain CHANGELOG.md following Keep a Changelog format.

#### Scenario: Updating changelog for new feature
- **WHEN** developer invokes `/update-changelog` command
- **THEN** system:
  - Reviews recent commits via `git log`
  - Identifies change categories (Added, Changed, Fixed, etc.)
  - Proposes changelog entries in Keep a Changelog format
  - Adds entries to Unreleased section

#### Scenario: Preparing version release
- **WHEN** developer invokes `/update-changelog` with release flag
- **THEN** system moves Unreleased items to new version section with date

### Requirement: Command Discoverability
The system SHALL make all Claude commands easily discoverable through documentation and consistent naming patterns.

#### Scenario: Listing available commands
- **WHEN** developer opens `.claude/commands/` directory
- **THEN** all command files use descriptive kebab-case names with `.md` extension

#### Scenario: Understanding command purpose
- **WHEN** developer reads any command file
- **THEN** file contains clear description, usage examples, and expected output

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

### Requirement: Box Upload Command

The system SHALL provide a `/upload-to-box` Claude command that uploads completed GWAS pipeline results to Box cloud storage via rclone (located at `C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe`), with path validation and progress monitoring.

#### Scenario: Upload with explicit dataset path
- **GIVEN** user has completed a GWAS pipeline run at `\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS`
- **WHEN** user invokes `/upload-to-box 20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS`
- **THEN** system validates the source path exists on the network drive
- **AND** constructs the rclone command with correct source and destination paths
- **AND** executes from Desktop directory: `"C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" copy --update -P "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\20251208_..." box:"Phenotyping_team_GH/sleap-roots-pipeline-results/20251208_..."`
- **AND** displays upload progress with transfer statistics
- **AND** reports completion status (files transferred, total size, duration)

#### Scenario: Upload with default dataset from CLAUDE.md
- **GIVEN** CLAUDE.md specifies current working dataset as `20251122_Elohim_Bello_iron_deficiency_GAPIT_GWAS`
- **WHEN** user invokes `/upload-to-box` without arguments
- **THEN** system uses the current working dataset from CLAUDE.md context
- **AND** proceeds with upload as if dataset name was explicitly provided

#### Scenario: Validate source path exists before upload
- **GIVEN** user provides a dataset name that does not exist on the network drive
- **WHEN** user invokes `/upload-to-box nonexistent_dataset`
- **THEN** system checks if `\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\nonexistent_dataset` exists
- **AND** reports error: "Source directory not found: [path]"
- **AND** suggests verifying the dataset name and network connectivity
- **AND** does NOT attempt the rclone upload

#### Scenario: Dry-run mode previews upload without executing
- **GIVEN** user wants to verify the command before executing
- **WHEN** user invokes `/upload-to-box 20251208_... --dry-run`
- **THEN** system displays the full rclone command that would be executed
- **AND** shows source and destination paths
- **AND** does NOT execute the upload
- **AND** labels output clearly as "[DRY RUN]"

#### Scenario: Verify rclone is available at known location
- **GIVEN** rclone is installed at `C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe`
- **WHEN** user invokes `/upload-to-box`
- **THEN** system checks if rclone exists at the known location
- **AND** if not found, reports: "rclone not found at C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe"
- **AND** provides setup instructions for Box remote configuration

#### Scenario: Handle upload interruption gracefully
- **GIVEN** network issues or user cancellation may interrupt upload
- **WHEN** upload is interrupted
- **THEN** system reports partial progress (files transferred so far)
- **AND** informs user they can re-run command to resume (--update flag skips existing files)
- **AND** does not leave corrupted files on destination

#### Scenario: Verify upload completion
- **GIVEN** rclone upload completes without errors
- **WHEN** upload finishes
- **THEN** system reports: "Upload complete: X files, Y GB transferred"
- **AND** optionally runs `rclone check` to verify file integrity
- **AND** provides Box web link to the uploaded folder

#### Scenario: Support custom destination folder
- **GIVEN** user wants to upload to a different Box location
- **WHEN** user invokes `/upload-to-box 20251208_... --dest "Phenotyping_team_GH/custom-folder"`
- **THEN** system uses the custom destination instead of default `sleap-roots-pipeline-results`
- **AND** validates destination format is valid Box path

#### Scenario: Show transfer statistics during upload
- **GIVEN** large datasets may take significant time to upload
- **WHEN** upload is in progress
- **THEN** system displays real-time progress via rclone's `-P` flag
- **AND** shows: current file, transfer speed, ETA, total progress percentage
- **AND** updates progress in terminal without flooding output

