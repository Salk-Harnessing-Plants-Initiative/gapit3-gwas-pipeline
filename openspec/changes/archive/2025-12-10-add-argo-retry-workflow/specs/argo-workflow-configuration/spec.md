## ADDED Requirements

### Requirement: Argo Workflow Retry Capability

The system SHALL provide a mechanism to retry failed traits from a completed Argo workflow with configurable resource allocation.

#### Scenario: Auto-detect incomplete traits from output directories
- **GIVEN** a completed Argo workflow with output directory
- **WHEN** the user runs `retry-argo-traits.sh --workflow <name>`
- **THEN** the script extracts the models parameter from the workflow (e.g., "BLINK,FarmCPU,MLM")
- **AND** extracts the output-hostpath and trait range from the workflow
- **AND** inspects each trait output directory for expected model outputs
- **AND** identifies traits with missing directories (no output at all)
- **AND** identifies traits with incomplete model outputs (e.g., missing MLM)
- **AND** displays a summary showing which traits need retry and which models are missing

#### Scenario: Manual trait specification
- **GIVEN** a user knows specific traits that need retry
- **WHEN** the user runs `retry-argo-traits.sh --traits 5,28,29,30,31`
- **THEN** the script uses the specified traits without auto-detection
- **AND** validates that trait indices are valid numbers

#### Scenario: Dry-run mode
- **GIVEN** a retry request with `--dry-run` flag
- **WHEN** the script generates the retry workflow
- **THEN** it outputs the YAML to stdout or specified file
- **AND** does NOT submit to the cluster
- **AND** displays what would be submitted

#### Scenario: High-memory retry
- **GIVEN** traits that failed due to OOM (exit code 137)
- **WHEN** the user specifies `--highmem` flag
- **THEN** the generated workflow references `gapit3-gwas-single-trait-highmem` template
- **AND** the template provides 96Gi memory (vs 64Gi normal)
- **AND** the template provides 16 CPU cores (vs 12 normal)

#### Scenario: Workflow submission
- **GIVEN** a valid retry workflow YAML
- **WHEN** the user specifies `--submit` flag
- **THEN** the script submits via `argo submit`
- **AND** displays the new workflow name
- **AND** optionally watches with `--watch`

### Requirement: High-Memory WorkflowTemplate

The system SHALL provide a high-memory variant of the single-trait WorkflowTemplate for retrying resource-intensive traits.

#### Scenario: Template resource allocation
- **GIVEN** the `gapit3-gwas-single-trait-highmem` WorkflowTemplate
- **WHEN** a pod is scheduled using this template
- **THEN** memory request is 96Gi
- **AND** memory limit is 104Gi
- **AND** CPU request is 16 cores
- **AND** CPU limit is 20 cores
- **AND** OPENBLAS_NUM_THREADS is 16
- **AND** OMP_NUM_THREADS is 16

#### Scenario: Template compatibility
- **GIVEN** the high-memory template
- **WHEN** it is referenced from a retry workflow
- **THEN** it accepts the same parameters as the normal template
- **AND** produces the same output directory structure
- **AND** is functionally identical except for resource allocation

### Requirement: Retry Workflow Structure

The generated retry workflow SHALL follow the established workflow patterns and integrate with existing infrastructure.

#### Scenario: Volume configuration
- **GIVEN** an original workflow with data and output volume mounts
- **WHEN** a retry workflow is generated
- **THEN** it copies the volume configuration from the original
- **AND** uses the same hostPath values for data and outputs

#### Scenario: Workflow naming
- **GIVEN** an original workflow named `gapit3-gwas-parallel-8nj24`
- **WHEN** a retry workflow is generated
- **THEN** it uses generateName: `gapit3-gwas-retry-`
- **AND** inherits labels indicating it's a retry

#### Scenario: Timeout configuration
- **GIVEN** traits that previously timed out
- **WHEN** the retry workflow is generated
- **THEN** activeDeadlineSeconds is set to 604800 (7 days)
- **AND** allows sufficient time for slow-converging MLM

### Requirement: Aggregation Integration

The retry script SHALL optionally trigger result aggregation after workflow completion.

#### Scenario: Post-retry aggregation
- **GIVEN** a retry workflow submitted with `--aggregate` flag
- **WHEN** the workflow completes successfully
- **THEN** the script runs `aggregate-runai-results.sh --force`
- **AND** uses the same output directory as the original workflow
- **AND** displays aggregation summary
