# Spec: Mount Failure Retry

## ADDED Requirements

### Requirement: Automatic Mount Failure Detection

The retry script MUST automatically detect jobs that failed due to infrastructure mount failures by checking for exit code 2 and mount failure indicators in logs.

#### Scenario: Detect Infrastructure Mount Failure

**Given** a job failed with exit code 2
**And** job logs contain "INFRASTRUCTURE MOUNT FAILURE"
**When** retry script analyzes the job
**Then** job MUST be identified as mount failure
**And** job MUST be eligible for retry

#### Scenario: Skip Configuration Errors

**Given** a job failed with exit code 1
**And** job logs contain "Missing required files"
**When** retry script analyzes the job
**Then** job MUST NOT be identified as mount failure
**And** job MUST be skipped (logged as "configuration error, manual fix needed")

#### Scenario: Skip Unknown Errors

**Given** a job failed
**And** logs are not available OR logs don't contain mount failure indicators
**When** retry script analyzes the job
**Then** job MUST be skipped
**And** script MUST log "Could not determine failure reason, skipping"

### Requirement: Bounded Retry Attempts

The retry script MUST limit retry attempts to a configurable maximum (default 3) to prevent infinite retry loops.

#### Scenario: Maximum Retries Enforced

**Given** a job has failed with mount error
**And** MAX_RETRIES=3
**When** retry script runs
**Then** job MUST be retried up to 3 times
**And** if all 3 retries fail
**Then** job MUST be marked as "permanently failed"
**And** no further retries MUST be attempted
**And** user MUST be notified in final report

#### Scenario: Retry Counter Tracking

**Given** retry script runs multiple times
**When** a job is retried
**Then** script MUST track retry count per trait
**And** count MUST persist across script invocations
**Or** script MUST check job creation timestamp to infer retry count

### Requirement: Exponential Backoff

The retry script MUST use exponential backoff delays between retry attempts to reduce cluster pressure.

#### Scenario: Backoff Delay Calculation

**Given** RETRY_DELAY_BASE=30 seconds
**When** retry attempt 1 fails
**Then** script MUST wait 30 seconds before attempt 2
**When** retry attempt 2 fails
**Then** script MUST wait 60 seconds before attempt 3 (30 × 2^1)
**When** retry attempt 3 fails
**Then** script MUST wait 120 seconds (30 × 2^2) OR give up if MAX_RETRIES=3

#### Scenario: No Delay Before First Retry

**Given** a newly detected mount failure
**When** retry script decides to retry
**Then** first retry MUST NOT have artificial delay
**And** job MUST be deleted and resubmitted immediately

### Requirement: Safe Dry-Run Mode

The retry script MUST support a --dry-run flag that shows what would be retried without actually retrying.

#### Scenario: Dry-Run Identification Only

**Given** retry script runs with --dry-run flag
**When** failed jobs are analyzed
**Then** script MUST identify mount failures
**And** script MUST print "[DRY-RUN] Would retry trait N (mount failure detected)"
**And** script MUST NOT delete any jobs
**And** script MUST NOT submit any jobs
**And** script MUST exit with code 0

#### Scenario: Dry-Run Statistics

**Given** 10 failed jobs (5 mount failures, 5 config errors)
**And** retry script runs with --dry-run
**When** script completes
**Then** it MUST report:
- Total failed jobs found: 10
- Mount failures (would retry): 5
- Config errors (skip): 5

### Requirement: Job Lifecycle Management

The retry script MUST properly manage job lifecycle: delete failed job, resubmit trait, wait for completion or next failure.

#### Scenario: Delete Before Resubmit

**Given** a failed job "gapit3-trait-37"
**When** retry script decides to retry
**Then** script MUST delete the failed job first
**And** deletion MUST complete before resubmission
**And** if deletion fails
**Then** script MUST log error and skip retry

#### Scenario: Extract Trait Index

**Given** job name "eberrigan-gapit-gwas-42"
**And** JOB_PREFIX="eberrigan-gapit-gwas"
**When** retry script extracts trait index
**Then** it MUST extract "42"
**And** it MUST use pattern: `echo "$job_name" | sed "s/^${JOB_PREFIX}-//"`

#### Scenario: Resubmit Single Trait

**Given** trait index 37 needs retry
**When** retry script resubmits
**Then** it MUST call submission script with START_TRAIT=37 END_TRAIT=37
**And** it MUST use same .env configuration
**And** it MUST pass confirmation automatically (no interactive prompt)
**And** command MUST be: `(export START_TRAIT=37 END_TRAIT=37; bash submit-all-traits-runai.sh <<< "y")`

### Requirement: Comprehensive Statistics

The retry script MUST report detailed statistics on retry operations.

#### Scenario: Final Report Content

**Given** retry script completes
**When** final report is printed
**Then** it MUST include:
- Total failed jobs found
- Mount failures detected
- Jobs retried (count)
- Jobs succeeded after retry (count)
- Jobs failed after max retries (count)
- Jobs skipped (not mount failures) (count)

#### Scenario: Real-Time Progress

**Given** retry script is running
**When** analyzing each job
**Then** script MUST print:
- "[INFO] Analyzing: <job-name>"
- "  → Mount failure detected" OR "  → Not a mount failure, skipping"
**And** when retrying
**Then** script MUST print:
- "[INFO] Deleting failed job..."
- "[INFO] Resubmitting trait N (attempt M/MAX)..."
- "[SUCCESS] Trait N resubmitted" OR "[FAILED] Resubmission failed"

### Requirement: Error Handling and Resilience

The retry script MUST handle edge cases gracefully and continue processing remaining jobs even if some retries fail.

#### Scenario: Job Already Deleted

**Given** a failed job in list
**And** job was manually deleted before retry script runs
**When** retry script tries to access the job
**Then** script MUST detect job no longer exists
**And** script MUST log "[WARNING] Job no longer exists, skipping"
**And** script MUST continue with next job

#### Scenario: Logs Unavailable

**Given** a failed job
**And** logs are not available (job was deleted too long ago)
**When** retry script tries to get logs
**Then** script MUST handle empty log output
**And** script MUST log "[WARNING] Could not retrieve logs, skipping"
**And** script MUST continue with next job

#### Scenario: Resubmission Failure

**Given** a mount failure identified for retry
**When** resubmission command fails
**Then** script MUST log "[ERROR] Resubmission failed"
**And** script MUST increment FAILED counter
**And** script MUST continue with next job (not exit)

### Requirement: Configuration Options

The retry script MUST accept command-line arguments for common configuration options.

#### Scenario: Command-Line Arguments

**Given** retry script is executed
**Then** it MUST support these flags:
- `--dry-run`: Show what would be retried without acting
- `--max-retries N`: Override maximum retry attempts (default: 3)
- `--retry-delay N`: Override base delay in seconds (default: 30)
- `--help, -h`: Show usage information

#### Scenario: Help Text

**Given** user runs `retry-failed-traits.sh --help`
**When** help text is displayed
**Then** it MUST include:
- Description of script purpose
- List of all command-line options
- Usage examples (basic retry, dry-run, custom max-retries)
- Explanation of exit codes

### Requirement: Exit Code Contract

The retry script MUST use exit codes that indicate success, partial success, or failure.

#### Scenario: Success Exit Code

**Given** all detected mount failures were retried successfully
**When** retry script completes
**Then** it MUST exit with code 0

#### Scenario: Partial Success Exit Code

**Given** some mount failures were retried successfully
**And** some failed after max retries
**When** retry script completes
**Then** it MUST exit with code 0 (partial success is still success)
**And** final report MUST clearly show failed count

#### Scenario: Error Exit Code

**Given** retry script encounters critical error (e.g., runai CLI not found)
**When** error occurs
**Then** script MUST exit with code 1
**And** error message MUST be printed to stderr

## Constraints

### Dependencies

- retry script MUST NOT require Python, R, or other languages (Bash only)
- retry script MUST use only standard UNIX tools (grep, awk, sed, wc)
- retry script MUST require runai CLI to be installed and authenticated
- retry script MUST require access to .env file in project root

### Testing

- retry script MUST have automated unit tests in `tests/unit/test-retry-script.sh`
- unit tests MUST validate syntax, trait extraction, mount detection, and filtering logic
- unit tests MUST NOT require RunAI cluster access (mock-based testing)
- CI workflow MUST run unit tests on every push/PR
- CI workflow MUST fail if syntax validation or unit tests fail

### Performance

- Retry script MUST process each job in < 10 seconds (excluding backoff waits)
- Retry script MUST handle up to 100 failed jobs without memory issues
- Exponential backoff MUST NOT exceed 300 seconds (5 minutes)

### Compatibility

- Retry script MUST work with same RunAI versions as submission script
- Retry script MUST respect existing .env configuration format
- Retry script MUST NOT interfere with concurrently running submission script

### Safety

- Retry script MUST NOT delete jobs that are currently running
- Retry script MUST NOT retry more than MAX_RETRIES times
- Retry script MUST NOT modify .env file
- Retry script MUST filter by JOB_PREFIX to avoid affecting other users' jobs
