# Tasks: Fix Argo Workflow Validation Error

## Phase 1: Update WorkflowTemplate ✅ Ready to Start

### Task 1.1: Remove volumes from template
**File**: `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`

**Actions**:
1. Remove `volumes` section (lines 116-125) from `run-gwas` template
2. Remove `data-hostpath` and `output-hostpath` from `inputs.parameters`
3. Keep `volumeMounts` in container spec unchanged
4. Add documentation comment explaining volume requirements

**Validation**:
```bash
# Verify YAML syntax
grep -A5 "volumes:" cluster/argo/workflow-templates/gapit3-single-trait-template.yaml
# Should NOT appear in run-gwas template

# Verify inputs
grep -A15 "inputs:" cluster/argo/workflow-templates/gapit3-single-trait-template.yaml
# Should NOT include data-hostpath or output-hostpath
```

**Estimated time**: 5 minutes

---

### Task 1.2: Re-deploy updated template
**Command**:
```bash
kubectl apply -f cluster/argo/workflow-templates/gapit3-single-trait-template.yaml -n runai-talmo-lab
```

**Validation**:
```bash
kubectl get workflowtemplates gapit3-gwas-single-trait -n runai-talmo-lab -o yaml | grep -A10 "run-gwas"
# Verify no volumes section in template
```

**Estimated time**: 1 minute

---

## Phase 2: Update Test Workflow ✅ Ready to Start

### Task 2.1: Add workflow-level volumes
**File**: `cluster/argo/workflows/gapit3-test-pipeline.yaml`

**Actions**:
1. Add `volumes` section at `spec` level (after `serviceAccountName`, before `arguments`)
2. Define `nfs-data` volume with `{{workflow.parameters.data-hostpath}}`
3. Define `nfs-outputs` volume with `{{workflow.parameters.output-hostpath}}`

**Expected structure**:
```yaml
spec:
  entrypoint: test-pipeline
  serviceAccountName: default

  # Add volumes here
  volumes:
  - name: nfs-data
    hostPath:
      path: "{{workflow.parameters.data-hostpath}}"
      type: Directory
  - name: nfs-outputs
    hostPath:
      path: "{{workflow.parameters.output-hostpath}}"
      type: DirectoryOrCreate

  arguments:
    # ... existing parameters
```

**Validation**:
```bash
grep -A10 "volumes:" cluster/argo/workflows/gapit3-test-pipeline.yaml | head -15
# Should show workflow-level volumes
```

**Estimated time**: 3 minutes

---

### Task 2.2: Remove volume path parameters from tasks
**File**: `cluster/argo/workflows/gapit3-test-pipeline.yaml`

**Actions**:
For each of the 3 trait tasks (`run-trait-2`, `run-trait-3`, `run-trait-4`):
1. Remove `- name: data-hostpath` parameter line
2. Remove `value: "{{workflow.parameters.data-hostpath}}"` line
3. Remove `- name: output-hostpath` parameter line
4. Remove `value: "{{workflow.parameters.output-hostpath}}"` line

**Validation**:
```bash
grep -B2 -A1 "data-hostpath\|output-hostpath" cluster/argo/workflows/gapit3-test-pipeline.yaml
# Should only appear in workflow-level volumes, not in task arguments
```

**Estimated time**: 5 minutes

---

### Task 2.3: Submit test workflow
**Command**:
```bash
cd cluster/argo/workflows
argo submit gapit3-test-pipeline.yaml -n runai-talmo-lab
```

**Expected output**:
```
Name:                gapit3-test-xxxxx
Namespace:           runai-talmo-lab
ServiceAccount:      default
Status:              Pending
Created:             Thu Nov 07 12:30:00 -0800 (now)
```

**Validation**:
- ✅ No validation errors
- ✅ Workflow name returned (e.g., `gapit3-test-xxxxx`)

**Estimated time**: 1 minute

---

## Phase 3: Verify Workflow Execution ✅ Ready After Phase 2

### Task 3.1: Monitor workflow status
**Commands**:
```bash
# Get workflow name from submission output
WORKFLOW_NAME=gapit3-test-xxxxx  # Replace with actual name

# Watch workflow progress
argo get $WORKFLOW_NAME -n runai-talmo-lab --watch

# Or view in real-time
argo logs $WORKFLOW_NAME -n runai-talmo-lab --follow
```

**Validation**:
- ✅ Workflow status changes from `Pending` → `Running`
- ✅ Validation step completes
- ✅ Extract traits step completes
- ✅ Three trait tasks start in parallel

**Estimated time**: 5 minutes (monitoring)

---

### Task 3.2: Verify volume mounts in pods
**Commands**:
```bash
# List pods for the workflow
kubectl get pods -n runai-talmo-lab -l workflows.argoproj.io/workflow=$WORKFLOW_NAME

# Check one of the trait pods
POD_NAME=$(kubectl get pods -n runai-talmo-lab -l workflows.argoproj.io/workflow=$WORKFLOW_NAME --field-selector=status.phase=Running -o name | head -1)

# Verify volumes are mounted
kubectl describe $POD_NAME -n runai-talmo-lab | grep -A20 "Mounts:"

# Exec into pod and check data access
kubectl exec $POD_NAME -n runai-talmo-lab -- ls -la /data/genotype/
kubectl exec $POD_NAME -n runai-talmo-lab -- ls -la /outputs/
```

**Validation**:
- ✅ `/data` mount shows as read-only
- ✅ `/outputs` mount shows as read-write
- ✅ Can list files in `/data/genotype/`
- ✅ Can create files in `/outputs/`

**Estimated time**: 5 minutes

---

## Phase 4: Update Parallel Workflow ✅ Ready After Phase 2

### Task 4.1: Apply same changes to parallel workflow
**File**: `cluster/argo/workflows/gapit3-parallel-pipeline.yaml`

**Actions**:
1. Add `volumes` section at workflow spec level (same as test workflow)
2. Remove `data-hostpath` and `output-hostpath` from task arguments in `run-single-trait-wrapper`

**Validation**:
```bash
# Check workflow-level volumes exist
grep -A10 "volumes:" cluster/argo/workflows/gapit3-parallel-pipeline.yaml | head -15

# Verify no volume path params in wrapper
grep -A30 "run-single-trait-wrapper" cluster/argo/workflows/gapit3-parallel-pipeline.yaml | grep -c "data-hostpath"
# Should output: 0
```

**Estimated time**: 5 minutes

---

## Phase 5: Documentation Updates ✅ Optional

### Task 5.1: Update QUICKSTART_EBERRIGAN.md
**File**: `QUICKSTART_EBERRIGAN.md`

**Actions**:
- Update any references to template parameters
- Add note about workflow-level volume requirements

**Estimated time**: 3 minutes

---

### Task 5.2: Update DEPLOYMENT_TESTING.md
**File**: `docs/DEPLOYMENT_TESTING.md`

**Actions**:
- Add troubleshooting section for validation errors
- Document volume configuration requirements

**Estimated time**: 5 minutes

---

## Total Estimated Time

- **Phase 1**: 6 minutes
- **Phase 2**: 9 minutes
- **Phase 3**: 10 minutes (includes waiting for workflow to start)
- **Phase 4**: 5 minutes
- **Phase 5**: 8 minutes (optional)

**Total**: ~40 minutes (or ~30 minutes if skipping documentation)

## Dependencies

- ✅ `kubectl` configured and authenticated
- ✅ `argo` CLI installed
- ✅ Workflow templates already deployed
- ✅ Data files in correct location

## Success Criteria

- [ ] Workflow submits without validation errors
- [ ] Pods start successfully with volumes mounted
- [ ] GWAS analysis runs on 3 test traits
- [ ] Results appear in output directory
- [ ] No errors in workflow logs

## Rollback Plan

If issues occur:
1. Revert template: Re-apply original `gapit3-single-trait-template.yaml`
2. Revert workflows: Use git to restore original workflow files
3. Delete failed workflow: `argo delete <workflow-name> -n runai-talmo-lab`

## Notes

- This is a breaking change for the template, but no production workflows exist yet
- After this fix, all future workflows must define volumes at workflow level
- Consider adding this requirement to template documentation/comments
