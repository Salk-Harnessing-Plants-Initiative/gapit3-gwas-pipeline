## ADDED Requirements

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
