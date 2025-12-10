# Tasks: Fix Argo Workflow Validation Error

## Phase 1: Update WorkflowTemplate ✅ Complete

- [x] 1.1 Remove volumes from template
- [x] 1.2 Remove `data-hostpath` and `output-hostpath` from `inputs.parameters`
- [x] 1.3 Keep `volumeMounts` in container spec unchanged
- [x] 1.4 Add documentation comment explaining volume requirements

## Phase 2: Update Test Workflow ✅ Complete

- [x] 2.1 Add `volumes` section at `spec` level with hostPath volumes
- [x] 2.2 Remove volume path parameters from task arguments
- [x] 2.3 Verify workflow submits without validation errors

## Phase 3: Update Parallel Workflow ✅ Complete

- [x] 3.1 Add `volumes` section at workflow spec level
- [x] 3.2 Remove volume path parameters from wrapper task

## Phase 4: Verification ✅ Complete

- [x] 4.1 WorkflowTemplate has only `volumeMounts`, no `volumes` section
- [x] 4.2 Both workflows define `nfs-data` and `nfs-outputs` at spec level
- [x] 4.3 Comments in template explain volume requirements

## Implementation Summary

The fix has been successfully implemented:

1. **WorkflowTemplate** ([gapit3-single-trait-template.yaml](cluster/argo/workflow-templates/gapit3-single-trait-template.yaml)):
   - Removed `volumes` section from template (was causing validation errors)
   - Removed `data-hostpath` and `output-hostpath` input parameters
   - Kept `volumeMounts` referencing `nfs-data` and `nfs-outputs` by name
   - Added documentation comments explaining volume requirements (lines 35-38)

2. **Test Workflow** ([gapit3-test-pipeline.yaml](cluster/argo/workflows/gapit3-test-pipeline.yaml)):
   - Added workflow-level `volumes` at `spec.volumes` (lines 39-47)
   - Uses `hostPath` volumes with `{{workflow.parameters.*}}` references
   - Task arguments no longer include `data-hostpath` or `output-hostpath`

3. **Parallel Workflow** ([gapit3-parallel-pipeline.yaml](cluster/argo/workflows/gapit3-parallel-pipeline.yaml)):
   - Added workflow-level `volumes` at `spec.volumes` (lines 44-52)
   - Same pattern as test workflow

## Success Criteria ✅ All Met

- [x] Workflow submits without validation errors
- [x] Pods can mount data and output volumes via hostPath
- [x] GWAS analysis runs successfully
- [x] Results written to output directory
