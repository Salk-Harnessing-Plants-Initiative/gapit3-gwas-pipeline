# workflow-volume-configuration Specification

## Purpose
TBD - created by archiving change fix-argo-workflow-validation. Update Purpose after archive.
## Requirements
### Requirement: WorkflowTemplate Volume Constraint

WorkflowTemplates SHALL NOT define volumes with input parameter references. Argo Workflows validates resource quantities at workflow submission time, before template parameter substitution occurs.

#### Scenario: Template with parameterized volumes fails validation
- **GIVEN** a WorkflowTemplate defines volumes using `{{inputs.parameters.data-hostpath}}`
- **WHEN** a workflow submits using `templateRef` to reference this template
- **THEN** Argo validation fails with error "quantities must match the regular expression"
- **AND** the workflow is rejected before execution

#### Scenario: Template with only volumeMounts succeeds validation
- **GIVEN** a WorkflowTemplate defines only `volumeMounts` referencing workflow-level volumes by name
- **WHEN** a workflow defines volumes at `spec.volumes` level and references the template
- **THEN** Argo validation succeeds
- **AND** the workflow is accepted and begins execution

### Requirement: Workflow-Level Volume Definition

Workflows SHALL define volumes at the `spec.volumes` level using `{{workflow.parameters.*}}` references, which are resolved at submission time.

#### Scenario: Workflow defines hostPath volumes for data access
- **GIVEN** a GAPIT3 workflow needs to mount genotype and phenotype data
- **WHEN** the workflow defines volumes at `spec.volumes` with `hostPath` and workflow parameter references
- **THEN** pods can mount these volumes using standard `volumeMounts` configuration
- **AND** the volumes reference workflow-level parameters which are substituted at submission time

#### Scenario: Multiple tasks reference same workflow volumes
- **GIVEN** a workflow defines volumes named `nfs-data` and `nfs-outputs`
- **WHEN** multiple parallel trait analysis tasks reference templates with `volumeMounts`
- **THEN** all tasks can mount the same volumes concurrently
- **AND** read-only mounts (`nfs-data`) prevent conflicts

### Requirement: Volume Naming Convention

Templates and workflows SHALL use consistent volume names (`nfs-data` for input data, `nfs-outputs` for results) to ensure compatibility.

#### Scenario: Template expects standard volume names
- **GIVEN** the `gapit3-gwas-single-trait` template expects volumes named `nfs-data` and `nfs-outputs`
- **WHEN** a workflow uses this template via `templateRef`
- **THEN** the workflow MUST provide volumes with exactly these names
- **AND** the volumes MUST be mounted at `/data` and `/outputs` respectively

#### Scenario: Documentation explains volume requirements
- **GIVEN** a developer wants to create a new workflow using `gapit3-gwas-single-trait` template
- **WHEN** they read the WorkflowTemplate file
- **THEN** comments clearly state required volume names and mount paths

