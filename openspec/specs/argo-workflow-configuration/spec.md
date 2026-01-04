# argo-workflow-configuration Specification

## Purpose

This spec defines the configuration patterns and conventions for Argo Workflows in the GAPIT3 GWAS pipeline, including parameter passing, resource configuration, and documentation standards.
## Requirements
### Requirement: Workflow Parameter Accuracy

All workflow parameters defined in `arguments.parameters` SHALL be referenced and used by the workflow. No unused parameters SHALL be defined.

#### Scenario: All parameters are used
- **GIVEN** a workflow YAML file with `arguments.parameters`
- **WHEN** the workflow is submitted
- **THEN** every parameter in `arguments.parameters` is referenced by at least one template
- **AND** no parameter appears in UI without affecting behavior

#### Scenario: Resource configuration visibility
- **GIVEN** a user wants to know resource allocation
- **WHEN** they inspect the workflow files
- **THEN** they find clear comments pointing to where resources are actually configured
- **AND** they understand that WorkflowTemplate contains the hardcoded values

### Requirement: Script Parameter Consistency

Helper scripts SHALL only accept parameters that have an effect on workflow execution.

#### Scenario: Script flags match workflow capabilities
- **GIVEN** the `submit_workflow.sh` script
- **WHEN** a user reviews the available flags
- **THEN** every flag corresponds to a workflow parameter that is actually used
- **AND** no flags are accepted that have no effect on execution

#### Scenario: Resource configuration documentation
- **GIVEN** the `submit_workflow.sh` script help text
- **WHEN** a user asks how to configure resources (CPU, memory)
- **THEN** the help text explains that resources are configured in WorkflowTemplate YAML
- **AND** provides the file path: `workflow-templates/gapit3-single-trait-template.yaml`

### Requirement: Consistent Environment Variable Pattern

All container templates that invoke the entrypoint SHALL explicitly set required environment variables rather than relying on defaults.

#### Scenario: Validate template sets env vars
- **GIVEN** a validate template in any workflow
- **WHEN** the template is defined
- **THEN** it includes `GENOTYPE_FILE` and `PHENOTYPE_FILE` environment variables
- **AND** the values match the dataset being processed

#### Scenario: Extract traits template consistency
- **GIVEN** an extract-traits template
- **WHEN** it references phenotype file
- **THEN** the path is consistent with the PHENOTYPE_FILE env var pattern

### Requirement: Accurate Documentation Comments

All comments in workflow YAML files SHALL accurately reflect the actual configuration.

#### Scenario: Trait count accuracy
- **GIVEN** a phenotype file with 187 columns (Taxa + 186 trait columns)
- **AND** a workflow processing trait indices 2-187
- **WHEN** comments describe the workflow
- **THEN** the count is stated as 186 traits
- **AND** the count matches the actual column range (187 - 2 + 1 = 186)

#### Scenario: Resource comments match reality
- **GIVEN** comments about parallelism or resources
- **WHEN** they describe limits
- **THEN** the values match `spec.parallelism` and WorkflowTemplate resources

### Requirement: WorkflowTemplate Default Alignment

WorkflowTemplate default parameter values SHALL reflect typical production usage.

#### Scenario: Models default includes MLM
- **GIVEN** the gapit3-gwas-single-trait WorkflowTemplate
- **WHEN** a user checks the default models parameter
- **THEN** it shows `BLINK,FarmCPU,MLM` (all three commonly used models)

### Requirement: No Display-Only Parameters

The system SHALL NOT define workflow parameters that appear in the UI but have no effect on execution. Parameters like `cpu-cores`, `memory-gb`, and `max-parallelism` SHALL be configured directly in WorkflowTemplate resources rather than as unused workflow parameters.

#### Scenario: All parameters affect behavior
- **WHEN** a parameter is defined in `arguments.parameters`
- **THEN** it is referenced by at least one template
- **AND** changing its value changes workflow behavior

#### Scenario: Resource configuration location
- **WHEN** a user needs to configure CPU, memory, or parallelism
- **THEN** they edit the WorkflowTemplate directly
- **AND** workflow parameters do not expose non-functional resource settings

### Requirement: Environment Variable Parameter Passing

The Argo WorkflowTemplate SHALL pass all runtime parameters to containers exclusively via environment variables, not CLI arguments.

#### Scenario: MODELS parameter passed correctly
- **WHEN** a workflow is submitted with `models: "BLINK,FarmCPU,MLM"` parameter
- **THEN** the container receives `MODELS=BLINK,FarmCPU,MLM` as an environment variable
- **AND** the entrypoint uses this value for GWAS analysis
- **AND** no CLI argument like `--models` is passed

#### Scenario: TRAIT_INDEX parameter passed correctly
- **WHEN** a workflow task runs for trait index 42
- **THEN** the container receives `TRAIT_INDEX=42` as an environment variable
- **AND** the entrypoint uses this value to select the phenotype column

#### Scenario: All parameters visible in pod description
- **WHEN** a user runs `kubectl describe pod <pod-name>`
- **THEN** all configuration parameters are visible in the Environment section
- **AND** the user can verify the exact values being used

### Requirement: Minimal Container Arguments

The WorkflowTemplate container args SHALL contain only the command selector (e.g., `run-single-trait`), not runtime parameters.

#### Scenario: Container args specify command only
- **GIVEN** the WorkflowTemplate container configuration
- **WHEN** the container starts
- **THEN** `args` contains only `["run-single-trait"]` or equivalent command selector
- **AND** no parameter values like `--models` or `--trait-index` appear in args

#### Scenario: Parameters not duplicated in args and env
- **GIVEN** a runtime parameter like MODELS
- **WHEN** the WorkflowTemplate is defined
- **THEN** the parameter appears in exactly one location (env section)
- **AND** the parameter does NOT appear in both args and env sections

### Requirement: Parameter Documentation

The WorkflowTemplate SHALL include comments explaining the environment-variable-only parameter passing pattern.

#### Scenario: Future developer understands the pattern
- **GIVEN** a developer reading the WorkflowTemplate YAML
- **WHEN** they look at the container configuration
- **THEN** they find a comment explaining that parameters are passed via env vars
- **AND** the comment explains why CLI args are not used

### Requirement: Argo Workflow Retry Capability

The system SHALL provide a mechanism to retry failed or incomplete traits from a completed Argo workflow with configurable resource allocation. Incomplete traits are detected using the Filter file as the definitive completion signal.

#### Scenario: Auto-detect incomplete traits using Filter file as completion signal

- **GIVEN** a completed or stopped Argo workflow with output directory
- **WHEN** the user runs `retry-argo-traits.sh --workflow <name> --output-dir <path>`
- **THEN** the script extracts the models parameter from the workflow (e.g., "BLINK,FarmCPU,MLM")
- **AND** extracts the output-hostpath and trait range from the workflow
- **AND** inspects each trait output directory for:
  1. Missing output directory entirely
  2. Missing `GAPIT.Association.Filter_GWAS_results.csv` (definitive completion signal)
- **AND** identifies traits as incomplete if Filter file is missing (regardless of GWAS_Results files present)
- **AND** displays a summary showing which traits need retry and why

#### Scenario: Filter file as definitive completion check

- **GIVEN** a trait output directory with `GAPIT.Association.GWAS_Results.BLINK.*.csv` file
- **AND** the directory is missing `GAPIT.Association.Filter_GWAS_results.csv`
- **WHEN** the script inspects this directory
- **THEN** the trait is marked as incomplete
- **AND** the summary shows "missing Filter file" as the reason
- **AND** the trait is included in the retry list
- **AND** the presence of partial GWAS_Results files does NOT mark the trait as complete

#### Scenario: Stopped workflow with partial outputs detected

- **GIVEN** a workflow that was stopped mid-execution via `argo stop`
- **AND** some traits were running when stopped and created partial outputs (GWAS_Results but no Filter)
- **WHEN** the script runs with `--output-dir` flag
- **THEN** all partially-completed traits are detected via missing Filter file
- **AND** no traits are missed due to having some GWAS_Results files

#### Scenario: Manual trait specification

- **GIVEN** a user knows specific traits that need retry
- **WHEN** the user runs `retry-argo-traits.sh --traits 5,28,29,30,31`
- **THEN** the script uses the specified traits without auto-detection
- **AND** validates that trait indices are valid numbers

#### Scenario: Dry-run mode shows detection details

- **GIVEN** a retry request with `--dry-run` flag
- **WHEN** the script generates the retry workflow
- **THEN** it outputs the YAML to stdout or specified file
- **AND** does NOT submit to the cluster
- **AND** displays what would be submitted
- **AND** shows detection summary: "X traits incomplete (missing Filter file)"

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

### Requirement: Standalone Aggregation Workflow Capability

The system SHALL provide a standalone Argo workflow for running results aggregation independently of the main GWAS pipeline. This enables aggregating results after retry workflows complete or re-aggregating with different parameters without re-running GWAS analyses.

#### Scenario: Submit standalone aggregation workflow

- **GIVEN** an output directory containing completed trait analyses
- **WHEN** the user submits `gapit3-aggregation-standalone.yaml` with:
  - `output-hostpath`: Path to outputs directory containing `trait_NNN_*` directories
  - `batch-id`: Optional identifier for the aggregation run
  - `image`: Docker image tag
- **THEN** the workflow runs the `gapit3-results-collector` WorkflowTemplate
- **AND** aggregates all trait results into `aggregated_results/` directory
- **AND** produces the same output as in-pipeline aggregation

#### Scenario: Aggregation after retry workflow completes

- **GIVEN** a retry workflow that completed without aggregation (no `--aggregate` flag)
- **AND** all traits now have Filter files indicating completion
- **WHEN** the user runs standalone aggregation with the same `output-hostpath`
- **THEN** the aggregation includes results from both original and retry runs
- **AND** the deduplication logic selects the best directory for each trait

#### Scenario: Standalone workflow uses existing WorkflowTemplate

- **GIVEN** the `gapit3-results-collector` WorkflowTemplate is installed on the cluster
- **WHEN** the standalone aggregation workflow is submitted
- **THEN** it references the template via `templateRef`
- **AND** does NOT duplicate the aggregation container definition
- **AND** inherits resource limits from the template (8Gi request, 16Gi limit)

#### Scenario: Workflow submission command pattern

- **GIVEN** a user wants to run standalone aggregation
- **WHEN** they follow the documentation
- **THEN** they can submit using:
  ```bash
  argo submit cluster/argo/workflows/gapit3-aggregation-standalone.yaml \
    -p output-hostpath="/hpi/hpi_dev/users/USERNAME/PROJECT/outputs" \
    -p batch-id="gapit3-gwas-parallel-XXXXX" \
    -n runai-talmo-lab
  ```
- **AND** the workflow generates a unique name like `gapit3-aggregate-XXXXX`

---

### Requirement: Aggregation Method Documentation

The system SHALL document when to use each aggregation method to help users choose the appropriate approach for their scenario.

#### Scenario: Method comparison documentation exists

- **GIVEN** a user needs to aggregate GWAS results
- **WHEN** they consult the Argo README documentation
- **THEN** they find a comparison table showing:
  | Scenario | Method | Command/File |
  |----------|--------|--------------|
  | Main pipeline with traits | In-DAG | `gapit3-parallel-pipeline.yaml` (automatic) |
  | Retry after OOM | In-DAG retry | `retry-argo-traits.sh --aggregate` |
  | After workflow stops | Standalone | `gapit3-aggregation-standalone.yaml` |
  | Local re-aggregation | R script | `Rscript scripts/collect_results.R` |
- **AND** they understand which method to use for their scenario

