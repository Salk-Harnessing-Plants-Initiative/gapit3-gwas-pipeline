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

## REMOVED Requirements

### Requirement: Display-Only Parameters

**Reason**: Parameters that appear in UI but have no effect cause operator confusion and debugging difficulty.

**Migration**:
- Remove `cpu-cores`, `memory-gb`, `max-parallelism` from workflow parameters
- Add comments explaining where these values are actually configured
- Resource values are in WorkflowTemplate: 64Gi memory, 12 CPU
- Parallelism is in `spec.parallelism`: 30

#### Affected Parameters (removed):
- `cpu-cores` -> Configured in WorkflowTemplate resources.requests.cpu
- `memory-gb` -> Configured in WorkflowTemplate resources.requests.memory
- `max-parallelism` -> Configured in spec.parallelism
