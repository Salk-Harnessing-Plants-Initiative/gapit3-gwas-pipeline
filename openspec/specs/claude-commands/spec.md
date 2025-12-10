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

