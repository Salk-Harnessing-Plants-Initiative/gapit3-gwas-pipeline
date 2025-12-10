# Proposal: Fix Argo Workflow Validation Error for WorkflowTemplate

**Change ID**: `fix-argo-workflow-validation`
**Status**: Implemented
**Created**: 2025-11-07
**Updated**: 2025-12-08
**Author**: Claude Code

## Problem Statement

The GAPIT3 test workflow fails to submit with the following error:

```
Error: Failed to submit workflow: rpc error: code = InvalidArgument desc =
templates.test-pipeline.tasks.run-trait-2 quantities must match the regular
expression '^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$'
```

### Root Cause Analysis

The error occurs because the `gapit3-single-trait-template.yaml` WorkflowTemplate defines `volumes` at the template level (inside the `run-gwas` template). When a workflow references this template using `templateRef`, Argo Workflows validates resource quantities at workflow submission time, **before** parameter substitution occurs.

The problematic structure is:
```yaml
- name: run-gwas
  inputs:
    parameters:
      - name: data-hostpath
      - name: output-hostpath
  # ...
  volumes:  # ❌ PROBLEM: Volumes with parameter refs don't work in WorkflowTemplates
    - name: nfs-data
      hostPath:
        path: "{{inputs.parameters.data-hostpath}}"  # Not yet substituted during validation
```

### Why This Fails

1. **Workflow submission**: Argo validates the workflow structure
2. **Template reference validation**: Argo tries to validate `gapit3-gwas-single-trait` template
3. **Resource validation**: Sees `{{inputs.parameters.memory-gb}}Gi` and `{{inputs.parameters.cpu-cores}}`
4. **Volume validation**: Sees `{{inputs.parameters.data-hostpath}}` in volumes
5. **Validation failure**: These template expressions don't match the resource quantity regex

### Current Workaround Attempted

We tried:
- ✅ Adding missing parameters (`data-hostpath`, `output-hostpath`, `models`)
- ✅ Updating namespace from `default` to `runai-talmo-lab`
- ❌ But volumes with parameterized paths in WorkflowTemplates still fail validation

## Proposed Solution

### Option 1: Move Volumes to Workflow Level (Recommended)

Remove `volumes` from the WorkflowTemplate and define them at the workflow level, then pass them as inputs.

**Pros**:
- Aligns with Argo Workflows best practices
- Volumes are workflow-level resources
- No validation issues

**Cons**:
- Slightly more verbose workflows
- Volumes must be redefined in each workflow

### Option 2: Use Script Template with Inline Volume Definition

Convert the container template to a script template with embedded volume definitions.

**Pros**:
- Keeps everything in one template

**Cons**:
- More complex template structure
- Less idiomatic Argo Workflows

### Recommendation

**Use Option 1** - Move volumes to workflow level and pass volume mount names as convention.

## Affected Components

- `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`
- `cluster/argo/workflows/gapit3-test-pipeline.yaml`
- `cluster/argo/workflows/gapit3-parallel-pipeline.yaml`

## Success Criteria

All criteria have been met:

1. ✅ `argo submit gapit3-test-pipeline.yaml -n runai-talmo-lab` succeeds without validation errors
2. ✅ Workflow pods successfully mount data and output volumes via hostPath
3. ✅ GWAS analysis runs successfully on test traits
4. ✅ Results are written to output directory

## Related Issues

- User attempting to deploy GAPIT3 pipeline to Argo Workflows
- All prerequisites met (kubectl configured, templates deployed)
- Data files validated and correctly structured

## Implementation Plan

See `tasks.md` for detailed implementation steps.
