# Implementation Tasks

## 1. Testing Commands
- [x] 1.1 Create `test-r.md` command for running R unit tests via testthat
- [x] 1.2 Create `test-r-coverage.md` command for R test coverage analysis
- [x] 1.3 Create `docker-build.md` command for building Docker image
- [x] 1.4 Create `docker-test.md` command for running Docker functional tests

## 2. Validation Commands
- [x] 2.1 Create `validate-bash.md` command for shellcheck and bash syntax validation
- [x] 2.2 Create `validate-yaml.md` command for YAML validation of Argo workflows
- [x] 2.3 Create `validate-r.md` command for R script validation and linting

## 3. Workflow Management Commands
- [x] 3.1 Create `submit-test-workflow.md` command for submitting Argo test workflow (3 traits)
- [x] 3.2 Create `monitor-jobs.md` command for monitoring RunAI/Argo jobs
- [x] 3.3 Create `aggregate-results.md` command for aggregating GWAS results
- [x] 3.4 Create `cleanup-jobs.md` command for cleaning up failed/completed jobs

## 4. Pull Request Commands
- [x] 4.1 Create `review-pr.md` command with:
  - [x] Planning mode activation
  - [x] Ultrathink activation
  - [x] Reading PR comments via gh CLI
  - [x] Code review analysis
  - [x] Posting review to GitHub via gh CLI
- [x] 4.2 Create `pr-description.md` command for generating PR descriptions

## 5. Documentation Commands
- [x] 5.1 Create `update-changelog.md` command following Keep a Changelog format

## 6. Verification
- [x] 6.1 Test each command manually to ensure correct syntax
- [x] 6.2 Verify all commands work with Claude Code slash command system
- [x] 6.3 Update `.claude/commands/README.md` if needed with command catalog