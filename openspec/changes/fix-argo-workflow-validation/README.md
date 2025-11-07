# Fix Argo Workflow Validation Error

**Change ID**: `fix-argo-workflow-validation`
**Status**: Proposed
**Created**: 2025-11-07

## Summary

Fixes Argo Workflows validation error that prevents GAPIT3 test workflow submission. The error occurs because volumes with parameterized paths in WorkflowTemplates are validated before parameter substitution, causing validation to fail.

## Problem

```bash
$ argo submit gapit3-test-pipeline.yaml -n runai-talmo-lab
Error: Failed to submit workflow: rpc error: code = InvalidArgument desc =
templates.test-pipeline.tasks.run-trait-2 quantities must match the regular
expression '^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$'
```

## Solution

Move volume definitions from WorkflowTemplate to workflow level, following the pattern from [sleap-roots-pipeline](https://github.com/talmolab/sleap-roots-pipeline/blob/main/sleap-roots-pipeline.yaml):

**Before (❌ Broken)**:
```yaml
# WorkflowTemplate
- name: run-gwas
  inputs:
    parameters:
      - name: data-hostpath
      - name: output-hostpath
  volumes:  # ❌ Fails validation
    - name: nfs-data
      hostPath:
        path: "{{inputs.parameters.data-hostpath}}"
```

**After (✅ Working)**:
```yaml
# Workflow
spec:
  volumes:  # ✅ Defined at workflow level
    - name: nfs-data
      hostPath:
        path: "{{workflow.parameters.data-hostpath}}"
        type: Directory

# WorkflowTemplate
- name: run-gwas
  inputs:
    parameters:
      # data-hostpath removed
  container:
    volumeMounts:  # References workflow volume by name
      - name: nfs-data
        mountPath: /data
```

## Files Changed

- `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`
- `cluster/argo/workflows/gapit3-test-pipeline.yaml`
- `cluster/argo/workflows/gapit3-parallel-pipeline.yaml`

## Implementation Time

~30-40 minutes (see `tasks.md`)

## Testing

1. Re-deploy template
2. Submit test workflow
3. Verify pods mount volumes correctly
4. Confirm GWAS analysis runs successfully

## References

- [Proposal](./proposal.md) - Detailed problem analysis and solution options
- [Design](./design.md) - Architecture decisions and implementation strategy
- [Tasks](./tasks.md) - Step-by-step implementation guide
- [Spec](./specs/workflow-volume-configuration/spec.md) - Formal requirements

## External References

- [sleap-roots-pipeline](https://github.com/talmolab/sleap-roots-pipeline) - Reference implementation
- [Salk RunAI Guide](https://researchit.salk.edu/runai/kubectl-and-argo-cli-usage/) - Cluster documentation
