## ADDED Requirements

### Requirement: Autonomous Pipeline Monitor

The system SHALL provide a background monitoring script that executes post-workflow tasks without user intervention.

#### Scenario: Monitor workflow until completion
- **WHEN** the script is launched with a valid workflow name
- **THEN** it polls the workflow status every poll-interval seconds
- **AND** it logs each status check with timestamp
- **AND** it exits the monitoring loop when status is Succeeded or Failed

#### Scenario: Validate output completeness
- **WHEN** the workflow completes successfully
- **THEN** the script counts Filter files in the output directory
- **AND** it compares the count against expected-traits parameter
- **AND** it logs the validation result (PASS if count >= 95% of expected)

#### Scenario: Submit aggregation workflow
- **WHEN** validation passes
- **THEN** the script submits the standalone aggregation workflow to the cluster
- **AND** it waits for the aggregation workflow to complete
- **AND** it logs the aggregation workflow name and status

#### Scenario: Trigger Box upload
- **WHEN** aggregation completes successfully
- **THEN** the script triggers rclone copy with --update flag via PowerShell
- **AND** it logs the upload command and completion status

#### Scenario: Handle workflow failure
- **WHEN** the monitored workflow status is Failed
- **THEN** the script logs the failure
- **AND** it exits with non-zero exit code
- **AND** it does NOT proceed to aggregation or upload

#### Scenario: Handle timeout
- **WHEN** the timeout period expires before workflow completion
- **THEN** the script logs a timeout error
- **AND** it exits with non-zero exit code

### Requirement: Background Execution

The monitoring script SHALL support background execution that persists beyond terminal session.

#### Scenario: Run in background with nohup
- **WHEN** the script is launched with nohup
- **THEN** it continues running after terminal disconnect
- **AND** all output is logged to the log file

#### Scenario: Log file location
- **WHEN** the script runs
- **THEN** all output is logged to `$OUTPUT_DIR/pipeline_monitor.log`
- **AND** each log line includes ISO8601 timestamp

### Requirement: Cross-Platform Execution

The script SHALL execute from WSL while interacting with Windows tools.

#### Scenario: Access cluster via WSL
- **WHEN** the script checks workflow status
- **THEN** it uses the KUBECONFIG at `~/.kube/kubeconfig-runai-talmo-lab.yaml`
- **AND** it uses the argo CLI installed in WSL

#### Scenario: Trigger Box upload via PowerShell
- **WHEN** the script triggers Box upload
- **THEN** it calls `powershell.exe -NoProfile -Command` from WSL
- **AND** it uses the rclone executable at `C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe`
- **AND** it uses Z: drive path for the source directory
