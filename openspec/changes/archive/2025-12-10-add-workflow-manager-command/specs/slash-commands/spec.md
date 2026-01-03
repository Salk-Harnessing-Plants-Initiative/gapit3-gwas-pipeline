## ADDED Requirements

### Requirement: Workflow Manager Slash Command

The system SHALL provide a `/manage-workflow` Claude Code slash command that orchestrates the complete workflow management cycle: assessment, cleanup, retry, and monitoring.

#### Scenario: Assess workflow with OOMKilled failures
- **GIVEN** a GWAS workflow `gapit3-gwas-parallel-XXXXX` with some OOMKilled tasks
- **WHEN** the user runs `/manage-workflow gapit3-gwas-parallel-XXXXX`
- **THEN** Claude fetches workflow status using `argo get`
- **AND** identifies tasks with exit code 137 or "OOMKilled" message
- **AND** extracts trait indices from task names (e.g., `run-all-traits(3:5)` → trait 5)
- **AND** reports: "Found X OOMKilled failures: traits Y, Z (require high-memory retry)"

#### Scenario: Assess workflow with stuck pods
- **GIVEN** a workflow with pods in `PodInitializing` state for > 10 minutes
- **WHEN** the user runs `/manage-workflow`
- **THEN** Claude identifies stuck pods by checking task duration vs. state
- **AND** reports: "Found X stuck pods (PodInitializing > 10min): traits Y, Z"
- **AND** recommends stopping the workflow to release stuck resources

#### Scenario: Stop stalled workflow
- **GIVEN** a workflow with stuck or stalled tasks
- **WHEN** Claude recommends stopping and user confirms
- **THEN** Claude executes `argo stop <workflow> -n runai-talmo-lab`
- **AND** verifies the workflow status changes to "Stopped"
- **AND** reports the number of tasks that were terminated

#### Scenario: Clean incomplete output directories
- **GIVEN** failed traits may have partial output directories
- **WHEN** cleanup is recommended and user confirms
- **THEN** Claude identifies directories for failed traits
- **AND** shows what will be deleted (dry-run preview)
- **AND** only deletes after explicit user confirmation
- **AND** reports cleanup results

#### Scenario: Generate retry workflow with high-memory
- **GIVEN** a workflow with OOMKilled failures for traits 5, 28, 30
- **WHEN** retry is needed
- **THEN** Claude uses `retry-argo-traits.sh` with:
  - `--workflow <original-workflow>`
  - `--traits 5,28,30`
  - `--highmem` (for OOMKilled failures)
  - `--aggregate` (to include aggregation step)
  - `--submit`
- **AND** reports the submitted retry workflow name

#### Scenario: Propagate SNP FDR parameter
- **GIVEN** the original workflow was submitted with `snp-fdr=0.05`
- **WHEN** a retry workflow is generated
- **THEN** the `retry-argo-traits.sh` script extracts snp-fdr from original workflow
- **AND** the retry workflow includes the same snp-fdr value
- **AND** Claude confirms: "SNP FDR threshold: 0.05 (propagated from original)"

#### Scenario: Monitor retry workflow progress
- **GIVEN** a retry workflow has been submitted
- **WHEN** monitoring is active
- **THEN** Claude periodically checks workflow status with `argo get`
- **AND** reports progress: "Retry progress: X/Y tasks complete"
- **AND** detects when workflow reaches Succeeded or Failed status
- **AND** reports final status including aggregation results

#### Scenario: Handle fully complete workflow
- **GIVEN** a workflow where all traits completed successfully
- **WHEN** the user runs `/manage-workflow`
- **THEN** Claude reports: "All X traits completed successfully"
- **AND** checks if aggregation ran (collect-results task)
- **AND** if aggregation missing, offers to run standalone aggregation
- **AND** does NOT recommend retry (no failed traits)

#### Scenario: Dry-run mode
- **GIVEN** the user wants to preview actions without executing
- **WHEN** the user runs `/manage-workflow <workflow> --dry-run`
- **THEN** Claude performs assessment (read-only)
- **AND** shows what cleanup would be performed (without executing)
- **AND** shows what retry command would be run (without submitting)
- **AND** clearly labels all output as "[DRY RUN]"

#### Scenario: Automated mode
- **GIVEN** the user wants to run without confirmations
- **WHEN** the user runs `/manage-workflow <workflow> --auto`
- **THEN** Claude proceeds through all phases without user confirmation
- **AND** logs each action taken
- **AND** only stops on errors or when complete

### Requirement: Failure Categorization

The workflow manager SHALL categorize failures into distinct types with appropriate remediation.

#### Scenario: OOMKilled failure detection
- **GIVEN** a task terminated with exit code 137
- **WHEN** categorizing the failure
- **THEN** it is classified as "OOMKilled"
- **AND** remediation is: use high-memory template (96Gi/16 CPU)

#### Scenario: Stuck pod detection
- **GIVEN** a pod in PodInitializing state for more than 10 minutes
- **WHEN** categorizing the failure
- **THEN** it is classified as "Stuck"
- **AND** remediation is: stop workflow, may indicate cluster resource issues

#### Scenario: Timeout failure detection
- **GIVEN** a task that exceeded activeDeadlineSeconds
- **WHEN** categorizing the failure
- **THEN** it is classified as "Timeout"
- **AND** remediation is: retry with longer deadline or investigate slow performance

#### Scenario: Other failure detection
- **GIVEN** a task failed with non-OOM, non-timeout error
- **WHEN** categorizing the failure
- **THEN** it is classified as "Error"
- **AND** Claude examines pod logs for error message
- **AND** reports the error for manual investigation

### Requirement: WSL Command Invocation

The workflow manager SHALL use correct WSL invocation patterns for Windows users.

#### Scenario: Execute argo commands via WSL
- **GIVEN** the user is on Windows
- **WHEN** executing argo CLI commands
- **THEN** Claude uses the pattern: `wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && <command>"`
- **AND** handles WSL mount path warnings gracefully

#### Scenario: Execute retry script via WSL
- **GIVEN** the user is on Windows
- **WHEN** executing retry-argo-traits.sh
- **THEN** Claude uses: `wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && cd /mnt/c/repos/gapit3-gwas-pipeline && ./scripts/retry-argo-traits.sh <args>"`

### Requirement: Built-in Troubleshooting

The workflow manager SHALL provide troubleshooting guidance when errors occur.

#### Scenario: Argo authentication failure
- **GIVEN** `argo` commands fail with "no configuration has been provided"
- **WHEN** Claude detects this error
- **THEN** Claude reports: "KUBECONFIG not set. Ensure ~/.kube/kubeconfig-runai-talmo-lab.yaml exists"
- **AND** suggests running: `wsl -e bash -c "ls -la ~/.kube/kubeconfig-runai-talmo-lab.yaml"`

#### Scenario: Cluster connection failure
- **GIVEN** commands fail with "Unable to connect to the server"
- **WHEN** Claude detects this error
- **THEN** Claude reports: "Cannot connect to Kubernetes cluster"
- **AND** suggests checking VPN connection and network access
- **AND** suggests running: `wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl cluster-info"`

#### Scenario: RBAC permission error
- **GIVEN** commands fail with "workflowtaskresults.argoproj.io is forbidden"
- **WHEN** Claude detects exit code 64
- **THEN** Claude reports: "RBAC permissions issue - this is a known limitation"
- **AND** explains the workflow may still have completed successfully
- **AND** suggests checking workflow status directly

#### Scenario: Volume mount failure
- **GIVEN** pods fail with "MountVolume.SetUp failed"
- **WHEN** Claude examines pod events
- **THEN** Claude reports: "Data volume mount failed"
- **AND** provides path mapping reference (Windows → WSL → Cluster)
- **AND** suggests verifying path exists with: `wsl -e bash -c "ls -la /mnt/hpi_dev/users/eberrigan/<dataset>"`

#### Scenario: WorkflowTemplate not found
- **GIVEN** workflow fails with "workflowtemplate not found"
- **WHEN** Claude detects this error
- **THEN** Claude reports: "WorkflowTemplate not installed"
- **AND** provides install command: `kubectl apply -f cluster/argo/workflow-templates/ -n runai-talmo-lab`
