# Design: Fix Argo Workflow Volume Validation

## Architecture Overview

### Current (Broken) Architecture

```
Workflow (gapit3-test-pipeline.yaml)
  ├─ Task: run-trait-2
  │   └─ templateRef: gapit3-gwas-single-trait
  │       └─ template: run-gwas
  │           ├─ inputs: data-hostpath, output-hostpath, cpu-cores, memory-gb
  │           ├─ container: (uses {{inputs.parameters.*}})
  │           └─ volumes:  ❌ FAILS VALIDATION
  │               ├─ nfs-data: {{inputs.parameters.data-hostpath}}
  │               └─ nfs-outputs: {{inputs.parameters.output-hostpath}}
```

**Problem**: Argo validates templates at workflow submission time. When it encounters `volumes` with parameter references in a WorkflowTemplate, it tries to validate them before parameter substitution, causing validation failure.

### Proposed Architecture

```
Workflow (gapit3-test-pipeline.yaml)
  ├─ volumes: (defined at workflow level)
  │   ├─ nfs-data: {{workflow.parameters.data-hostpath}}
  │   └─ nfs-outputs: {{workflow.parameters.output-hostpath}}
  │
  ├─ Task: run-trait-2
  │   └─ templateRef: gapit3-gwas-single-trait
  │       └─ template: run-gwas
  │           ├─ inputs: trait-index, trait-name, image, cpu-cores, memory-gb, models
  │           └─ container:
  │               └─ volumeMounts: (reference workflow volumes by name)
  │                   ├─ nfs-data → /data
  │                   └─ nfs-outputs → /outputs
```

**Solution**: Move volume definitions to workflow level where they can use `{{workflow.parameters.*}}` which is resolved at submission time.

## Key Design Decisions

### Decision 1: Volume Definition Location

**Options Considered**:

1. **Workflow-level volumes** (SELECTED)
   - ✅ Aligns with Argo best practices
   - ✅ No validation issues
   - ✅ Volumes are workflow-scoped resources
   - ❌ Must redeclare in each workflow

2. **Template-level volumes**
   - ✅ Would be more DRY
   - ❌ Doesn't work with templateRef + parameters
   - ❌ Fails Argo validation

3. **Pod-level volumes in template**
   - ✅ Would keep everything in template
   - ❌ More complex
   - ❌ Not standard Argo pattern

**Rationale**: Workflow-level volumes are the idiomatic Argo Workflows approach and avoid validation issues.

### Decision 2: Template Input Parameters

**Keep**: `trait-index`, `trait-name`, `image`, `cpu-cores`, `memory-gb`, `models`

**Remove**: `data-hostpath`, `output-hostpath`

**Rationale**: The template doesn't need to know about volume paths. It only needs to know that volumes named `nfs-data` and `nfs-outputs` will be available via workflow-level definition.

### Decision 3: Volume Mount Convention

**Convention**: All workflows using `gapit3-gwas-single-trait` template must define:
- Volume named `nfs-data` → mounted at `/data` (read-only)
- Volume named `nfs-outputs` → mounted at `/outputs` (read-write)

**Documentation**: Add comment in WorkflowTemplate explaining this requirement.

## Implementation Strategy

### Phase 1: Update WorkflowTemplate
1. Remove `volumes` section from `run-gwas` template
2. Remove `data-hostpath` and `output-hostpath` from input parameters
3. Keep `volumeMounts` in container spec (references workflow volumes by name)
4. Add documentation comment about required workflow volumes

### Phase 2: Update Test Workflow
1. Add `volumes` section at workflow spec level
2. Use `{{workflow.parameters.data-hostpath}}` and `{{workflow.parameters.output-hostpath}}`
3. Remove `data-hostpath` and `output-hostpath` from task arguments
4. Test submission

### Phase 3: Update Parallel Workflow
1. Apply same changes as test workflow
2. Ensure all 186 trait tasks work correctly

## Validation Plan

### Unit Tests
- ❌ Argo workflows don't have traditional unit tests
- ✅ Use `argo lint` (if available) to validate YAML

### Integration Tests
1. Submit test workflow
2. Verify workflow starts successfully
3. Check pod has correct volume mounts
4. Verify data files are accessible in pod
5. Verify output files are written successfully

### Acceptance Criteria
- Workflow submission succeeds
- Pods start and mount volumes correctly
- GWAS analysis completes successfully
- Results appear in output directory

## Migration Path

Since this is a new deployment (not yet running in production):
1. Update templates and workflows in place
2. Re-deploy templates: `kubectl apply -f gapit3-single-trait-template.yaml -n runai-talmo-lab`
3. Submit test workflow: `argo submit gapit3-test-pipeline.yaml -n runai-talmo-lab`

No backward compatibility concerns.

## Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Volume mounts fail due to path issues | High | Low | Test with known-good paths from user's environment |
| Pods can't access NFS/hostPath | High | Medium | Verify cluster nodes can access `/hpi/hpi_dev/users/eberrigan/...` |
| Template changes break existing workflows | High | None | No existing workflows in production yet |

## Alternative Approaches Rejected

### 1. Dynamic Volume Provisioning
- **Why rejected**: Requires PVCs, not suitable for existing NFS/hostPath setup
- **When to reconsider**: If moving to cloud storage or S3

### 2. ConfigMap for Paths
- **Why rejected**: Adds unnecessary complexity for simple path parameters
- **When to reconsider**: If many workflows need the same configuration

### 3. Custom Resource Definitions
- **Why rejected**: Massive overkill for this use case
- **When to reconsider**: Never for this project

## References

- [Argo Workflows: Volumes](https://argoproj.github.io/argo-workflows/fields/#volumes)
- [Argo Workflows: WorkflowTemplate](https://argoproj.github.io/argo-workflows/workflow-templates/)
- [Kubernetes: Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Salk RunAI: kubectl and Argo CLI Usage](https://researchit.salk.edu/runai/kubectl-and-argo-cli-usage/) - Official guide for RunAI cluster configuration
- [sleap-roots-pipeline](https://github.com/talmolab/sleap-roots-pipeline/blob/main/sleap-roots-pipeline.yaml) - Reference implementation demonstrating workflow-level volume definitions with hostPath
