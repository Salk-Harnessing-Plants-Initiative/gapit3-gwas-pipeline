# Spec: Environment Validation and Dry-Run Mode

## ADDED Requirements

### Requirement: Standalone Environment Validation Script

The system SHALL provide a standalone script `scripts/validate-env.sh` that validates all configuration before job submission, catching errors that would cause 186 jobs to fail and preventing wasted cluster resources.

#### Scenario: Validation detects missing phenotype file

- **WHEN** a user runs `validate-env.sh` with a .env file that references a non-existent phenotype file
- **THEN** the script SHALL report an error "Phenotype file not found: <path>"
- **AND** exit with code 1 (validation failed)
- **AND** provide guidance on fixing the issue

#### Scenario: Validation detects invalid trait range

- **WHEN** a user's .env file specifies END_TRAIT greater than the number of columns in the phenotype file
- **THEN** the script SHALL report an error "END_TRAIT (X) exceeds column count (Y)"
- **AND** exit with code 1
- **AND** show the actual column count from the phenotype file

#### Scenario: Validation passes with correct configuration

- **WHEN** a user runs `validate-env.sh` with a valid .env file
- **AND** all data files exist
- **AND** all parameters are valid
- **THEN** the script SHALL display "✅ All validation checks passed"
- **AND** exit with code 0 (success)
- **AND** show the command to proceed with submission

#### Scenario: Validation works offline with warnings

- **WHEN** a user runs `validate-env.sh` without cluster filesystem access
- **THEN** the script SHALL warn "Cluster filesystem not accessible - skipping file checks"
- **AND** validate all parameters that don't require cluster access
- **AND** exit with code 0 if local validation passes
- **AND** note that cluster validation will occur when jobs start

---

### Requirement: Environment File Validation

The validation script MUST verify that the .env file exists, is readable, contains required variables, and has no syntax errors.

#### Scenario: Missing env file detected

- **WHEN** a user runs `validate-env.sh` and the .env file does not exist
- **THEN** the script SHALL report error ".env file not found: <path>"
- **AND** exit with code 1

#### Scenario: Required variables checked

- **WHEN** validation runs
- **THEN** the script SHALL verify all required variables are defined:
  - IMAGE, DATA_PATH_HOST, OUTPUT_PATH_HOST
  - GENOTYPE_FILE, PHENOTYPE_FILE
  - START_TRAIT, END_TRAIT
  - MODELS, PCA_COMPONENTS
  - PROJECT, JOB_PREFIX
- **AND** report any missing variables as errors

---

### Requirement: Phenotype File Structure Validation

The validation script MUST verify that the phenotype file has correct structure (tab-delimited, Taxa column, correct column count) before allowing submission.

#### Scenario: Phenotype column count verified

- **WHEN** validation checks the phenotype file
- **THEN** the script SHALL count the total number of columns
- **AND** store this count for trait index validation
- **AND** report the column count to the user

#### Scenario: Taxa column verified

- **WHEN** validation checks the phenotype file
- **THEN** the script SHALL verify the first column header is "Taxa"
- **AND** report an error if the first column is not "Taxa"

---

### Requirement: Trait Index Bounds Validation

The validation script MUST verify that START_TRAIT and END_TRAIT are within valid bounds (START >= 2, END <= column count, START <= END).

#### Scenario: START_TRAIT too low detected

- **WHEN** START_TRAIT is set to 1
- **THEN** the script SHALL report error "START_TRAIT must be >= 2 (column 1 is Taxa)"
- **AND** exit with code 1

#### Scenario: END_TRAIT exceeds columns detected

- **WHEN** END_TRAIT is greater than the phenotype file column count
- **THEN** the script SHALL report error "END_TRAIT (X) exceeds column count (Y)"
- **AND** exit with code 1

#### Scenario: Inverted range detected

- **WHEN** START_TRAIT is greater than END_TRAIT
- **THEN** the script SHALL report error "START_TRAIT (X) > END_TRAIT (Y)"
- **AND** exit with code 1

---

### Requirement: GAPIT Parameter Validation

The validation script MUST verify that all GAPIT parameters are within valid ranges and use correct values.

#### Scenario: Invalid model name detected

- **WHEN** MODELS contains an invalid model name (not in: BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM)
- **THEN** the script SHALL report error "Invalid model name: <model>"
- **AND** list valid model names
- **AND** exit with code 1

#### Scenario: PCA components out of range

- **WHEN** PCA_COMPONENTS is less than 0 or greater than 20
- **THEN** the script SHALL report error "PCA_COMPONENTS must be between 0 and 20"
- **AND** exit with code 1

#### Scenario: Invalid SNP threshold detected

- **WHEN** SNP_THRESHOLD is not a valid p-value (0 < x < 1)
- **THEN** the script SHALL report error "SNP_THRESHOLD must be between 0 and 1 (p-value)"
- **AND** exit with code 1

---

### Requirement: Resource Allocation Validation

The validation script MUST verify that resource allocation is reasonable and sufficient for GAPIT workloads.

#### Scenario: Insufficient memory warning

- **WHEN** MEMORY is less than 16G
- **THEN** the script SHALL warn "Memory allocation (<16G) may be insufficient for GAPIT"
- **AND** recommend at least 16G (32G optimal)
- **AND** exit with code 0 (warning, not error)

#### Scenario: Unreasonable CPU value detected

- **WHEN** CPU is less than 1 or greater than 64
- **THEN** the script SHALL report error "CPU must be between 1 and 64"
- **AND** exit with code 1

---

### Requirement: Dry-Run Mode for Submission Script

The submission script MUST support a `--dry-run` flag that validates configuration and shows the submission plan without actually submitting jobs.

#### Scenario: Dry-run shows submission plan

- **WHEN** a user runs `submit-all-traits-runai.sh --dry-run`
- **AND** validation passes
- **THEN** the script SHALL display:
  - Number of jobs to be submitted
  - Job name range (start to end)
  - Resource allocation per job
  - Peak total resource usage
  - First 5 job names as examples
  - Command to actually submit
- **AND** exit with code 0 without submitting any jobs

#### Scenario: Dry-run catches errors before submission

- **WHEN** a user runs `submit-all-traits-runai.sh --dry-run`
- **AND** validation fails
- **THEN** the script SHALL display validation errors
- **AND** exit with code 1
- **AND** NOT proceed to show submission plan

---

### Requirement: Validation Performance

The validation script MUST complete in reasonable time to enable rapid configuration iteration.

#### Scenario: Full validation completes quickly

- **WHEN** a user runs `validate-env.sh` with full validation (including cluster file checks)
- **THEN** the script SHALL complete in less than 30 seconds

#### Scenario: Quick mode validation very fast

- **WHEN** a user runs `validate-env.sh --quick`
- **THEN** the script SHALL skip slow checks (cluster file access, image pull test)
- **AND** complete in less than 5 seconds
- **AND** validate all local parameters

---

### Requirement: Error Message Quality

Validation error messages MUST be clear, actionable, and provide guidance on how to fix issues.

#### Scenario: Error includes fix suggestion

- **WHEN** validation detects an error
- **THEN** the error message SHALL include:
  - What is wrong
  - Why it's wrong
  - How to fix it (if applicable)
  - Example of correct configuration (if applicable)

#### Scenario: Warnings distinguished from errors

- **WHEN** validation encounters a non-blocking issue
- **THEN** it SHALL display as a warning (yellow, ⚠ symbol)
- **AND** allow validation to continue
- **AND** exit with code 0 if no errors found

---

### Requirement: Exit Code Conventions

The validation script MUST use standard exit codes to enable scripting and CI/CD integration.

#### Scenario: Exit codes follow convention

- **WHEN** validation runs
- **THEN** the script SHALL exit with:
  - Code 0: Validation passed (no errors, warnings OK)
  - Code 1: Validation failed (errors found)
  - Code 2: Script error (missing file, invalid arguments)

---

## MODIFIED Requirements

### Requirement: Job Submission Script Arguments

The job submission script SHALL accept additional flags for dry-run and validation modes.

#### Scenario: Dry-run flag accepted

- **WHEN** a user runs `submit-all-traits-runai.sh --dry-run`
- **THEN** the script SHALL enter dry-run mode
- **AND** NOT submit any jobs
- **AND** show what would be submitted

#### Scenario: Dry-run combinable with other flags

- **WHEN** a user runs `submit-all-traits-runai.sh --dry-run --start-trait 2 --end-trait 10`
- **THEN** the script SHALL validate configuration for traits 2-10
- **AND** show submission plan for those 9 jobs only
- **AND** NOT submit jobs

---

## Cross-References

**Related Capabilities**:
- `runai-job-submission` - Validation prevents bad submissions
- `environment-configuration` - Validates .env file structure
- `docker-workflow-ux` - Image validation (reused here)

**Dependencies**:
- Requires existing `.env` file structure
- Requires access to cluster filesystem (for file validation)
- Optionally uses `runai` CLI (for project validation)
- Optionally uses `gh` CLI or Docker CLI (for image validation)

**Security Considerations**:
- Validation script reads .env but doesn't modify it
- File checks use read-only operations
- No sensitive data logged to console
- Exit codes don't leak sensitive information

---

## Implementation Notes

**Backward Compatibility**:
- All changes are additive (no breaking changes)
- Validation is optional (users can skip it)
- Submission script works without --dry-run flag
- Existing .env files work unchanged

**Testing Strategy**:
- Create test .env files with known errors
- Test each validation category independently
- Test graceful degradation (offline mode)
- Test performance (< 30s full, <5s quick)
- Integration test: validate → fix → revalidate → submit

**Performance Targets**:
- Full validation: <30 seconds
- Quick validation: <5 seconds
- Cluster file checks: <10 seconds
- Image validation: <5 seconds (cached)

**Graceful Degradation**:
- Works offline (skips network checks)
- Works without cluster access (warns)
- Works without validation tools (warns)
- Never blocks on optional checks

**Success Metrics**:
- 100% of configuration errors caught before submission
- <1% false positives (valid configs failing validation)
- Validation time <30s (full), <5s (quick)
- User satisfaction: "Saved me from failed job submission"
