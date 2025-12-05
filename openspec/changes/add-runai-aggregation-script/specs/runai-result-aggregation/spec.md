# Spec: RunAI Result Aggregation

## Overview

Automated monitoring and aggregation of GWAS results from manual RunAI execution workflow.

**Capability ID**: `runai-result-aggregation`

**Related Capabilities**: None (new capability)

---

## ADDED Requirements

### Requirement: Automatic Job Monitoring

The system SHALL provide automated monitoring of RunAI workspace completion status.

#### Scenario: Monitor all submitted trait jobs

**Given** user has submitted 186 trait jobs via `scripts/submit-all-traits-runai.sh`
**When** user runs `./scripts/aggregate-runai-results.sh`
**Then** the script SHALL:
- Query RunAI for all `gapit3-trait-*` workspaces
- Display count of jobs by status (Running, Succeeded, Failed, Pending)
- Poll RunAI every 30 seconds (default) for status updates
- Continue monitoring until all jobs reach terminal state (Succeeded or Failed)

#### Scenario: Monitor specific trait range

**Given** user submitted only traits 2-50
**When** user runs `./scripts/aggregate-runai-results.sh --start-trait 2 --end-trait 50`
**Then** the script SHALL:
- Only monitor workspaces `gapit3-trait-2` through `gapit3-trait-50`
- Ignore other `gapit3-trait-*` workspaces outside this range
- Complete when all 49 specified jobs reach terminal state

#### Scenario: Check status without waiting

**Given** user wants to check current status without blocking
**When** user runs `./scripts/aggregate-runai-results.sh --check-only`
**Then** the script SHALL:
- Display current job counts by status
- Show progress percentage
- Exit immediately without waiting for completion
- Return exit code 0

---

### Requirement: Progress Visualization

The system SHALL provide clear visual feedback during monitoring.

#### Scenario: Display monitoring progress

**Given** 186 total jobs with 120 succeeded, 30 running, 2 failed, 34 pending
**When** monitoring is active
**Then** the script SHALL display:
```
Progress: 120 succeeded, 30 running, 2 failed, 34 pending
Waiting for 64 jobs to complete...
[====================----------] 65% (122/186 complete)
```

#### Scenario: Update progress periodically

**Given** monitoring is active
**When** check interval elapses (default 30 seconds)
**Then** the script SHALL:
- Re-query RunAI workspace status
- Update displayed counts
- Refresh progress bar
- Show elapsed time

---

### Requirement: Automatic Aggregation Trigger

The system SHALL automatically execute results aggregation when all jobs complete.

#### Scenario: Trigger aggregation on completion

**Given** all 186 trait jobs have reached terminal status (Succeeded or Failed)
**When** monitoring detects completion
**Then** the script SHALL:
- Display "All jobs complete!" message
- Show final counts (e.g., "184 succeeded, 2 failed")
- Execute `Rscript scripts/collect_results.R` with appropriate parameters
- Pass `--output-dir`, `--batch-id`, `--threshold` arguments
- Display aggregation progress and results

#### Scenario: Force immediate aggregation

**Given** user knows all jobs are already complete
**When** user runs `./scripts/aggregate-runai-results.sh --force`
**Then** the script SHALL:
- Skip monitoring phase
- Immediately execute aggregation
- Use current timestamp for batch-id if not specified

#### Scenario: Warn on many failures

**Given** monitoring detects >10 failed jobs
**When** all jobs complete and aggregation is about to run
**Then** the script SHALL:
- Display warning: "Warning: X traits failed. Results will be partial."
- Prompt user: "Continue with aggregation? (y/N): "
- Exit with code 1 if user declines
- Continue aggregation if user confirms

---

### Requirement: Aggregation Output

The system SHALL create aggregated result files after successful execution.

#### Scenario: Create aggregated result files

**Given** aggregation completes successfully
**When** script finishes
**Then** the following files SHALL exist in `<output-dir>/aggregated_results/`:
- `summary_table.csv` - One row per successful trait with metadata
- `significant_snps.csv` - All SNPs with p-value < threshold (default 5e-8)
- `summary_stats.json` - Overall statistics (total traits, significant SNPs, etc.)

#### Scenario: Report aggregation results

**Given** aggregation completed
**When** script displays final summary
**Then** output SHALL include:
- "Aggregation completed successfully!" message
- Output directory path
- Batch ID used
- List of generated files with sizes
- Summary statistics from `summary_stats.json`

---

### Requirement: Error Handling

The system SHALL handle errors gracefully with informative messages.

#### Scenario: RunAI CLI not available

**Given** `runai` command is not in PATH
**When** user runs aggregation script
**Then** the script SHALL:
- Display "ERROR: runai CLI not found. Please install RunAI CLI."
- Exit with code 1
- Not proceed with monitoring

#### Scenario: RunAI not authenticated

**Given** user has not run `runai login`
**When** script attempts to query workspaces
**Then** the script SHALL:
- Display "ERROR: Not authenticated to RunAI. Run: runai login"
- Exit with code 1

#### Scenario: No jobs found

**Given** no `gapit3-trait-*` workspaces exist in project
**When** script queries RunAI
**Then** the script SHALL:
- Display "WARNING: No gapit3-trait-* jobs found in project <name>"
- Suggest: "Did you submit jobs with ./scripts/submit-all-traits-runai.sh ?"
- Exit with code 0 (not an error, just nothing to do)

#### Scenario: Aggregation script fails

**Given** `collect_results.R` exits with non-zero code
**When** aggregation executes
**Then** the script SHALL:
- Display "ERROR: Aggregation failed. Check logs above."
- List possible causes (no successful traits, directory not writable, etc.)
- Exit with code 1

#### Scenario: User interrupts monitoring

**Given** monitoring is in progress
**When** user presses Ctrl+C
**Then** the script SHALL:
- Catch SIGINT signal
- Display "Interrupted. Jobs continue running in RunAI."
- Exit with code 130 (standard for SIGINT)
- NOT terminate RunAI jobs (they continue independently)

---

### Requirement: Configuration Options

The system SHALL support customizable parameters via command-line arguments.

#### Scenario: Specify custom output directory

**Given** user wants results in `/custom/path/outputs`
**When** user runs `./scripts/aggregate-runai-results.sh --output-dir /custom/path/outputs`
**Then** aggregation SHALL:
- Read trait results from `/custom/path/outputs/trait_*/`
- Write aggregated results to `/custom/path/outputs/aggregated_results/`

#### Scenario: Specify custom batch ID

**Given** user wants to label this batch
**When** user runs `./scripts/aggregate-runai-results.sh --batch-id "iron-traits-v2"`
**Then** aggregation SHALL:
- Pass batch ID to `collect_results.R`
- Include batch ID in metadata
- Display batch ID in final summary

#### Scenario: Specify custom check interval

**Given** user wants faster updates
**When** user runs `./scripts/aggregate-runai-results.sh --check-interval 10`
**Then** monitoring SHALL:
- Poll RunAI every 10 seconds instead of default 30
- Update progress display every 10 seconds

#### Scenario: Use default values

**Given** user provides no arguments
**When** user runs `./scripts/aggregate-runai-results.sh`
**Then** the script SHALL use defaults:
- Output dir: `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs`
- Batch ID: `runai-<timestamp>` (e.g., "runai-20251107143022")
- Project: `talmo-lab`
- Start trait: 2
- End trait: 187
- Check interval: 30 seconds
- Threshold: 5e-8

---

### Requirement: Integration with Existing Scripts

The system SHALL integrate with existing RunAI workflow scripts.

#### Scenario: Reminder in submission script

**Given** user completes running `scripts/submit-all-traits-runai.sh`
**When** submission script displays final summary
**Then** output SHALL include:
```
Next steps:
1. Monitor progress:
   ./scripts/monitor-runai-jobs.sh --watch

2. Aggregate results when complete:
   ./scripts/aggregate-runai-results.sh
```

#### Scenario: Hint in monitoring script

**Given** user is watching job progress with `scripts/monitor-runai-jobs.sh`
**When** all jobs reach terminal status
**Then** monitoring output SHALL include:
```
All jobs complete!
Run aggregation with:
  ./scripts/aggregate-runai-results.sh
```

---

### Requirement: Help Documentation

The system SHALL provide comprehensive usage information.

#### Scenario: Display help message

**Given** user needs usage information
**When** user runs `./scripts/aggregate-runai-results.sh --help`
**Then** the script SHALL display:
- Script purpose and description
- Available options with defaults
- Usage examples (basic and advanced)
- Exit with code 0

#### Scenario: Help message content

**Given** help is displayed
**Then** output SHALL include at minimum:
```
Usage: aggregate-runai-results.sh [OPTIONS]

Monitor RunAI job completion and automatically aggregate GWAS results.

Options:
  --output-dir DIR      Output directory [default: from env]
  --batch-id ID         Batch identifier [default: runai-TIMESTAMP]
  --project NAME        RunAI project [default: talmo-lab]
  --start-trait NUM     First trait index [default: 2]
  --end-trait NUM       Last trait index [default: 187]
  --check-interval SEC  Polling interval [default: 30]
  --check-only          Check status and exit, don't wait
  --force               Skip waiting, run aggregation immediately
  --help                Show this help message

Examples:
  # Wait for all jobs, then aggregate
  ./scripts/aggregate-runai-results.sh

  # Custom output and batch ID
  ./scripts/aggregate-runai-results.sh \\
    --output-dir /custom/path \\
    --batch-id "my-batch"

  # Only aggregate traits 2-50
  ./scripts/aggregate-runai-results.sh --start-trait 2 --end-trait 50

  # Check status without waiting
  ./scripts/aggregate-runai-results.sh --check-only
```

---

## MODIFIED Requirements

*None - this is a new capability with no existing requirements to modify.*

---

## REMOVED Requirements

*None - no requirements are being removed.*

---

## Cross-References

### Related Specifications

- **Manual RunAI Execution** (docs/MANUAL_RUNAI_EXECUTION.md): This capability extends the manual execution workflow with automated aggregation
- **Batch Submission** (scripts/submit-all-traits-runai.sh): This script complements the submission script
- **Job Monitoring** (scripts/monitor-runai-jobs.sh): Shares similar RunAI CLI interaction patterns

### Dependencies

- **External**: RunAI CLI installed and authenticated
- **Scripts**: `scripts/collect_results.R` (no modifications needed)
- **Data**: RunAI workspaces named `gapit3-trait-{INDEX}`

### Compatibility

- **Argo Workflows**: This capability is specific to manual RunAI execution; Argo workflows have built-in aggregation
- **Backward Compatibility**: Users can still manually run `collect_results.R` if they prefer

---

## Implementation Notes

### Technical Constraints

- **Polling Approach**: Script uses polling rather than event-driven approach due to RunAI CLI limitations
- **RunAI CLI Format**: Depends on `runai workspace list` output format remaining stable
- **Bash Compatibility**: Requires bash 4.0+ for associative arrays (if used)

### Performance Considerations

- **API Load**: One RunAI API call every 30 seconds (default) - negligible load
- **Long-Running**: Script may run for 3-4 hours during full 186-trait execution
- **Background Execution**: Users can run in tmux/screen or background with nohup

### Security Considerations

- **Authentication**: Relies on user's existing RunAI authentication
- **Permissions**: Requires read access to RunAI project workspaces
- **File System**: Requires write access to output directory

---

## Testing Requirements

### Unit Tests

- [x] Script exists and is executable
- [ ] `--help` displays usage
- [ ] `--check-only` exits immediately
- [ ] `--force` skips monitoring
- [ ] Error handling for missing prerequisites

### Integration Tests

- [ ] End-to-end: submit 3 traits → monitor → aggregate
- [ ] Verify aggregated result files created
- [ ] Verify correct trait count in summary_table.csv
- [ ] Test with failed jobs (some traits fail)
- [ ] Test with no jobs (clean project)
- [ ] Test user interrupt (Ctrl+C)

### Manual Verification

- [ ] Run on cluster with actual RunAI jobs
- [ ] Verify monitoring updates correctly
- [ ] Verify aggregation runs automatically
- [ ] Check output files are correct
- [ ] Validate user experience is smooth

---

## Documentation Requirements

- [x] docs/MANUAL_RUNAI_EXECUTION.md - Add "Step 4: Aggregate Results" section
- [x] docs/RUNAI_QUICK_REFERENCE.md - Add aggregation command examples
- [x] README.md - Add to "Current workarounds available" list
- [x] CHANGELOG.md - Document new feature in [Unreleased]
- [x] scripts/submit-all-traits-runai.sh - Add reminder message
- [x] scripts/monitor-runai-jobs.sh - Add hint when jobs complete

---

## Future Enhancements

Potential additions not in initial scope:

1. **Email Notifications**: `--notify-email user@example.com`
2. **Slack Integration**: `--slack-webhook $URL`
3. **Incremental Aggregation**: Aggregate as results arrive
4. **HTML Report**: `--html-report` flag
5. **Auto-cleanup**: Delete completed workspaces after aggregation
6. **Progress Persistence**: Save state to resume after interruption
7. **Multi-project Support**: Aggregate from multiple RunAI projects

---

## Approval Checklist

- [x] Requirements are clear and testable
- [x] All scenarios have Given/When/Then structure
- [x] Error cases are covered
- [x] Integration points documented
- [x] Documentation requirements listed
- [x] Testing strategy defined
- [x] No conflicts with existing capabilities
