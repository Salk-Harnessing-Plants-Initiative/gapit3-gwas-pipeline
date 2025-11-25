# Spec: Workflow Volume Configuration

**Capability**: workflow-volume-configuration
**Status**: Proposed
**Affects**: Argo Workflows deployment pattern

## Context

The GAPIT3 pipeline uses Argo Workflows for orchestrating parallel GWAS analysis. The pipeline needs to mount data and output directories into pods running GWAS calculations. Following the pattern established in [sleap-roots-pipeline](https://github.com/talmolab/sleap-roots-pipeline/blob/main/sleap-roots-pipeline.yaml), volumes must be defined at the workflow level, not in WorkflowTemplates.

## MODIFIED Requirements

### Requirement: WorkflowTemplate must not define volumes with input parameters
**Priority**: Critical
**Rationale**: Argo Workflows validates resource quantities at workflow submission time, before template parameter substitution occurs. Volumes with parameterized paths in WorkflowTemplates cause validation failures.

#### Scenario: Template with volumes fails validation
**Given**: A WorkflowTemplate defines volumes using `{{inputs.parameters.data-hostpath}}`
**When**: A workflow submits using `templateRef` to reference this template
**Then**: Argo validation fails with error "quantities must match the regular expression"
**And**: The workflow is rejected before execution

#### Scenario: Template without volumes succeeds validation
**Given**: A WorkflowTemplate defines only `volumeMounts` referencing workflow-level volumes by name
**When**: A workflow defines volumes at `spec.volumes` level and references the template
**Then**: Argo validation succeeds
**And**: The workflow is accepted and begins execution

---

### Requirement: Workflows must define volumes at spec level
**Priority**: Critical
**Rationale**: Aligns with Argo Workflows best practices and matches pattern from sleap-roots-pipeline

#### Scenario: Workflow defines hostPath volumes for data access
**Given**: A GAPIT3 workflow needs to mount genotype and phenotype data
**When**: The workflow defines:
```yaml
spec:
  volumes:
  - name: nfs-data
    hostPath:
      path: "{{workflow.parameters.data-hostpath}}"
      type: Directory
  - name: nfs-outputs
    hostPath:
      path: "{{workflow.parameters.output-hostpath}}"
      type: DirectoryOrCreate
```
**Then**: Pods can mount these volumes using standard `volumeMounts` configuration
**And**: The volumes reference workflow-level parameters which are substituted at submission time

#### Scenario: Multiple tasks reference same workflow volumes
**Given**: A workflow defines volumes named `nfs-data` and `nfs-outputs`
**When**: Multiple parallel trait analysis tasks reference templates with `volumeMounts`
**Then**: All tasks can mount the same volumes concurrently
**And**: Read-only mounts (`nfs-data`) prevent conflicts
**And**: Each task writes to its own subdirectory in `nfs-outputs`

---

### Requirement: Volume mount paths must be consistent across workflows
**Priority**: High
**Rationale**: Templates expect standard mount paths; workflows must provide volumes at those paths

#### Scenario: Template expects standard volume names
**Given**: The `gapit3-gwas-single-trait` template expects volumes named `nfs-data` and `nfs-outputs`
**When**: A workflow uses this template via `templateRef`
**Then**: The workflow MUST provide volumes with exactly these names
**And**: The volumes MUST be mounted at `/data` and `/outputs` respectively
**And**: Failure to provide correctly named volumes results in pod startup failure

#### Scenario: Documentation explains volume requirements
**Given**: A developer wants to create a new workflow using `gapit3-gwas-single-trait` template
**When**: They read the WorkflowTemplate file
**Then**: Comments at the top clearly state required volume names and mount paths
**And**: An example workflow snippet shows correct volume configuration

---

## REMOVED Requirements

### Requirement: [REMOVED] WorkflowTemplates may define volumes with input parameters
**Rationale**: This pattern does not work with Argo Workflows validation. Moved to workflow level.

---

## Implementation Notes

### Template Changes Required
- Remove `volumes` section from `gapit3-single-trait-template.yaml`
- Remove `data-hostpath` and `output-hostpath` from template input parameters
- Keep `volumeMounts` unchanged (references volumes by name)
- Add documentation comment explaining volume requirements

### Workflow Changes Required
**Test Workflow** (`gapit3-test-pipeline.yaml`):
- Add `volumes` section at `spec` level
- Remove `data-hostpath` and `output-hostpath` from task arguments

**Parallel Workflow** (`gapit3-parallel-pipeline.yaml`):
- Add `volumes` section at `spec` level
- Remove `data-hostpath` and `output-hostpath` from wrapper task arguments

### Validation Steps
1. Template re-deployment: `kubectl apply -f gapit3-single-trait-template.yaml -n runai-talmo-lab`
2. Workflow submission: `argo submit gapit3-test-pipeline.yaml -n runai-talmo-lab`
3. Pod inspection: Verify volumes mounted correctly in running pods
4. Execution test: Confirm GWAS analysis can read data and write results

## Dependencies
- Follows pattern from [sleap-roots-pipeline](https://github.com/talmolab/sleap-roots-pipeline/blob/main/sleap-roots-pipeline.yaml)
- Aligns with [Salk RunAI kubectl/Argo guide](https://researchit.salk.edu/runai/kubectl-and-argo-cli-usage/)
- Uses `hostPath` volumes consistent with cluster configuration

## Migration Notes
- This is a breaking change for the WorkflowTemplate
- No existing production workflows to migrate (first deployment)
- Future workflows must follow new volume definition pattern
