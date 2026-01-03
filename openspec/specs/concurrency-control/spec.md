# concurrency-control Specification

## Purpose
TBD - created by archiving change fix-concurrency-and-add-retry. Update Purpose after archive.
## Requirements
### Requirement: Batch-Specific Job Counting

The submission script MUST count only jobs from the current batch (matching `JOB_PREFIX`) when determining concurrency, not all jobs in the shared RunAI project.

#### Scenario: Multiple Users in Shared Project

**Given** user A has 30 jobs running with prefix "usera-gwas-"
**And** user B starts submitting jobs with prefix "userb-gwas-"
**And** user B has `MAX_CONCURRENT=50` in their .env
**When** user B's script checks for concurrency
**Then** it MUST count only "userb-gwas-*" jobs
**And** it MUST NOT count "usera-gwas-*" jobs
**And** it MUST allow submission if userb-gwas jobs < 50

#### Scenario: Same User Multiple Batches

**Given** user has 40 jobs running with prefix "experiment1-"
**And** user starts new batch with prefix "experiment2-"
**And** user has `MAX_CONCURRENT=50` in .env for experiment2
**When** experiment2 script checks concurrency
**Then** it MUST count only "experiment2-*" jobs
**And** it MUST NOT count "experiment1-*" jobs
**And** it MUST allow submission since experiment2 has 0 jobs

#### Scenario: Job Prefix Pattern Matching

**Given** job names: "gapit3-trait-2", "gapit3-trait-10", "gapit3-trait-100"
**And** JOB_PREFIX="gapit3-trait"
**When** script filters jobs by prefix
**Then** it MUST match all three jobs
**And** it MUST use pattern `^[[:space:]]*$JOB_PREFIX-` for matching
**And** it MUST handle leading whitespace from runai output

### Requirement: All Active States Counted

The submission script MUST count all non-terminal job states (Running, Pending, ContainerCreating, Starting), not only "Running" state.

#### Scenario: Jobs in Pending State

**Given** 30 jobs in "Running" state
**And** 20 jobs in "Pending" state
**And** MAX_CONCURRENT=50
**When** script checks concurrency
**Then** it MUST count 50 total active jobs
**And** it MUST wait (not submit) because 50 >= 50

#### Scenario: Jobs in ContainerCreating State

**Given** 40 jobs in "Running" state
**And** 5 jobs in "ContainerCreating" state
**And** 5 jobs in "Succeeded" state
**And** MAX_CONCURRENT=50
**When** script checks concurrency
**Then** it MUST count 45 active jobs (Running + ContainerCreating)
**And** it MUST NOT count "Succeeded" jobs
**And** it MUST allow submission because 45 < 50

#### Scenario: Terminal States Excluded

**Given** jobs in various states:
- 40 "Running"
- 10 "Succeeded"
- 5 "Failed"
- 3 "Completed"
**And** MAX_CONCURRENT=50
**When** script counts active jobs
**Then** it MUST count only 40 (Running)
**And** it MUST exclude Succeeded, Failed, Completed
**And** it MUST use pattern `grep -vE "Succeeded|Failed|Completed"`

### Requirement: Accurate Concurrency Enforcement

The submission script MUST respect `MAX_CONCURRENT` limit exactly for the current batch, preventing more than MAX_CONCURRENT active jobs at any time.

#### Scenario: Exact Limit Enforcement

**Given** MAX_CONCURRENT=5
**And** script is submitting 10 jobs
**When** first 5 jobs are submitted and active
**Then** script MUST wait before submitting job 6
**And** script MUST print "[WAIT] 5 active jobs in batch (max: 5)"
**And** when a job completes, count becomes 4
**Then** script MUST submit job 6
**And** active count MUST return to 5

#### Scenario: Zero Concurrent Jobs at Start

**Given** MAX_CONCURRENT=50
**And** no existing jobs with matching prefix
**When** script starts submitting
**Then** first 50 jobs MUST submit without waiting
**And** job 51 MUST trigger wait state
**And** script MUST wait until count < 50 before continuing

#### Scenario: Wait Loop Polling

**Given** script is waiting (active jobs >= MAX_CONCURRENT)
**When** in wait loop
**Then** script MUST check job count every 30 seconds
**And** script MUST use same counting logic (prefix + active states)
**And** when active jobs < MAX_CONCURRENT
**Then** script MUST resume submission

### Requirement: Clear User Feedback

The submission script MUST provide clear log messages that distinguish between batch-specific and project-wide job counts.

#### Scenario: Wait Message Clarity

**Given** script is waiting due to concurrency limit
**When** wait message is displayed
**Then** it MUST say "active jobs in batch" not "jobs running"
**And** it MUST show the batch-specific count
**And** message format MUST be: "[WAIT] N active jobs in batch (max: M). Waiting 30s..."

#### Scenario: Successful Submission Message

**Given** script submits a job successfully
**When** confirmation message is displayed
**Then** it MUST say "[SUBMIT] Trait N (job: <job-name>)"
**And** it MUST follow with "→ Success"

### Requirement: Variable Naming Consistency

The submission script MUST use variable name `ACTIVE` instead of `RUNNING` to accurately reflect what is being counted.

#### Scenario: Variable Renaming

**Given** current code uses variable `RUNNING`
**When** fix is applied
**Then** all occurrences of `RUNNING` variable MUST be renamed to `ACTIVE`
**And** this MUST include:
- Variable declaration
- While loop condition
- Log message variable references

### Requirement: Code Documentation

The concurrency checking code MUST include inline comments explaining the filtering and counting logic.

#### Scenario: Comment Requirements

**Given** the concurrency check code block
**When** developers read the code
**Then** comments MUST explain:
- Why job prefix filtering is needed
- What states are considered "active"
- Why terminal states are excluded
**And** comments MUST appear before the `ACTIVE=` assignment
**And** comments MUST be concise (1-3 lines)

