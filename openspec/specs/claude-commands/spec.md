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

#### Scenario: Submitting test workflow
- **WHEN** developer invokes `/submit-test-workflow` command
- **THEN** system executes submission script for 3-trait test workflow with appropriate parameters

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

