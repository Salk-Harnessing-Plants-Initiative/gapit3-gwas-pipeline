# Argo Workflows Service Account Requirements

## Overview

The GAPIT3 GWAS pipeline runs on Argo Workflows in the `runai-talmo-lab` namespace. Understanding the two service accounts and their roles is **critical** for successful workflow execution.

**Key Takeaway**: All workflow YAML files MUST use `serviceAccountName: default` for pod execution.

## Service Account Roles

### 1. argo-user (Human Submission)

**Purpose**: For humans submitting and managing workflows via CLI

**Permissions**:
- Create workflows (`argo submit`)
- List workflows (`argo list`)
- Delete workflows (`argo delete`)
- Watch workflow status (`argo watch`)
- Read pod logs (`argo logs`)

**Critical Limitation**:
- **LACKS** `workflowtaskresults` create/update permission
- This is an Argo-internal resource required for workflow execution
- Pods running with this SA will fail with permission errors

**Usage**:
- Used automatically when you run `argo` CLI commands
- Configured in your kubeconfig for authentication
- **DO NOT use as `serviceAccountName` in workflow YAML**

### 2. default (Pod Execution)

**Purpose**: For pods executing workflow tasks

**Permissions**:
- All workflow execution permissions
- **HAS** `workflowtaskresults` create/update permission (critical!)
- Can create/manage pods
- Can access volumes and secrets

**Usage**:
- Set as `serviceAccountName: default` in all workflow YAML files
- **REQUIRED** for workflow templates and workflows
- This is what makes workflows actually run

## The Critical Bug (Commit f1410fe)

### What Happened

In commit f1410fe, `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml` was incorrectly changed to use `argo-user` instead of `default`. This was based on a misunderstanding of RBAC roles.

**The Error**:
```yaml
spec:
  serviceAccountName: argo-user  # WRONG - breaks workflow execution
```

**The Fix**:
```yaml
spec:
  serviceAccountName: default  # CORRECT - required for workflowtaskresults
```

### Admin's Test Results (2025-11-18)

Our cluster admin tested both configurations:

**With `default` SA** (CORRECT):
- ✅ `validate-inputs` step succeeded
- ✅ `extract-traits` step succeeded
- ✅ `run-trait-2`, `run-trait-3`, `run-trait-4` steps started
- ❌ `run-trait` steps hit OOMKilled (memory issue - unrelated to SA)

**With `argo-user` SA** (WRONG):
- ❌ Workflow fails immediately with:
  ```
  Error (exit code 64): workflowtaskresults.argoproj.io is forbidden:
  User "system:serviceaccount:runai-talmo-lab:argo-user" cannot create resource
  ```

**Conclusion**: The `default` service account is correctly configured and has all required permissions. The OOMKilled error is a separate memory allocation issue, not a service account problem.

## Correct Configuration

### All Workflow Files MUST Use:

```yaml
spec:
  serviceAccountName: default  # Required for workflowtaskresults permission
```

### Verified Files (Current Status)

| File | Service Account | Status |
|------|----------------|--------|
| `gapit3-single-trait-template.yaml` | `default` | ✅ FIXED |
| `gapit3-test-pipeline.yaml` | `default` | ✅ CORRECT |
| `gapit3-parallel-pipeline.yaml` | `default` | ✅ CORRECT |
| `trait-extractor-template.yaml` | `default` | ✅ CORRECT |
| `results-collector-template.yaml` | `default` | ✅ CORRECT |

## Path Configuration

### Network Share to Cluster Mount Mapping

The HPI storage is accessible via two methods:

**Network Share** (from Windows/macOS workstations):
```
\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\
```

**Cluster Mount** (from GPU cluster nodes):
```
/hpi/hpi_dev/users/eberrigan/
```

These point to the **same physical storage**. Files you place on the network share are immediately visible on the cluster at the corresponding path.

### Example Paths

**Test Directories** (created November 2024):
```yaml
# Workflow parameter
data-hostpath: "/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data"
output-hostpath: "/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs"
```

**Production Paths** (customize per user):
```yaml
# Workflow parameter
data-hostpath: "/hpi/hpi_dev/users/eberrigan/gapit3-gwas/data"
output-hostpath: "/hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs"
```

### Important Path Notes

- **Always use `/hpi/` prefix**, not `/mnt/`
- Paths must exist on the cluster before workflow submission
- Use `hostPath` volume type (not NFS, even though it's network storage)
- Genotype/phenotype data should be read-only (`readOnly: true`)
- Output directories can be created automatically (`type: DirectoryOrCreate`)

## Memory Requirements

### By Task Type

| Task | Request | Limit | Notes |
|------|---------|-------|-------|
| **Validation** | 2Gi | 4Gi | Checks files exist and are valid |
| **Extract Traits** | 2Gi | 4Gi | Reads phenotype header |
| **GWAS (single trait)** | 32Gi | 36Gi | Memory-intensive R computations |
| **Results Collection** | 8Gi | 16Gi | Aggregates 186 trait results |

### OOMKilled Troubleshooting

If you see `OOMKilled` (exit code 137):

**This is a memory limit issue, NOT a service account issue.**

Admin's test showed OOMKilled on `run-trait` steps even with correct `default` SA. The workflow progressed successfully through validation and extraction, proving the SA is correct.

**Solutions**:
1. Increase memory allocation in workflow YAML (already at 32Gi request, 36Gi limit)
2. Reduce dataset size (fewer SNPs, fewer samples)
3. Use memory-efficient GAPIT models (BLINK instead of FarmCPU)
4. Monitor actual memory usage with `kubectl top pods`

**Note**: 32Gi is the minimum recommended for GWAS. For very large datasets (500K+ SNPs), 64Gi+ may be required.

## Common Errors and Solutions

### Error 1: workflowtaskresults forbidden

```
Error (exit code 64): workflowtaskresults.argoproj.io is forbidden:
User "system:serviceaccount:runai-talmo-lab:argo-user" cannot create resource
```

**Cause**: Using `argo-user` service account in workflow YAML

**Fix**: Change to `serviceAccountName: default` in the workflow/template file

**Files to Check**:
```bash
grep -n "serviceAccountName" cluster/argo/**/*.yaml
```

All should show `default`, not `argo-user`.

### Error 2: OOMKilled (Exit code 137)

```
Status: Failed (OOMKilled)
Exit code: 137
Message: Container was killed due to out of memory
```

**Cause**: Insufficient memory allocation for the task

**Fix**: Increase memory limits in workflow YAML

**Example Fix**:
```yaml
resources:
  requests:
    memory: "32Gi"  # Increase from 16Gi
  limits:
    memory: "36Gi"  # Increase from 20Gi
```

### Error 3: Pod succeeded but workflow shows failed

**Cause**: Service account lacks permission to record task success

**Fix**: Verify using `serviceAccountName: default`

**Verification**:
```bash
# Check workflow definition
kubectl get workflow <workflow-name> -n runai-talmo-lab -o yaml | grep serviceAccountName

# Expected output:
#   serviceAccountName: default
```

### Error 4: Mount path not found

```
Error: mkdir: cannot create directory '/data': Read-only file system
```

**Cause**: Incorrect path format or wrong volume type

**Fix**:
- Use `/hpi/hpi_dev/` prefix, not `/mnt/hpi_dev/`
- Ensure `hostPath` volume type, not `nfs`
- Verify path exists on cluster: `ls /hpi/hpi_dev/users/eberrigan/`

## Verification Commands

### Check Service Account Permissions

```bash
# Verify default SA has workflowtaskresults permission
kubectl auth can-i create workflowtaskresults.argoproj.io \
  --as=system:serviceaccount:runai-talmo-lab:default \
  -n runai-talmo-lab

# Expected output: yes
```

```bash
# Verify argo-user SA lacks workflowtaskresults permission
kubectl auth can-i create workflowtaskresults.argoproj.io \
  --as=system:serviceaccount:runai-talmo-lab:argo-user \
  -n runai-talmo-lab

# Expected output: no
```

### Check Workflow Configuration

```bash
# List all service accounts in workflow files
grep "serviceAccountName" cluster/argo/**/*.yaml

# All should show "default", none should show "argo-user"
```

### Test Workflow Submission

```bash
# Submit test workflow (3 traits)
argo submit cluster/argo/workflows/gapit3-test-pipeline.yaml \
  -n runai-talmo-lab --watch

# Watch for:
# - validate-inputs: Succeeded
# - extract-traits: Succeeded
# - run-trait-*: Running (may hit OOMKilled if memory insufficient)
```

### Check Pod Service Account at Runtime

```bash
# Get running pods from a workflow
kubectl get pods -n runai-talmo-lab -l workflows.argoproj.io/workflow=<workflow-name>

# Describe a pod to see its service account
kubectl describe pod <pod-name> -n runai-talmo-lab | grep "Service Account"

# Expected output: Service Account: default
```

## Best Practices

### 1. Always Use `default` SA
```yaml
spec:
  serviceAccountName: default  # In all workflow and template files
```

### 2. Use `argo-user` Only for CLI
```bash
# This automatically uses argo-user credentials from your kubeconfig
argo submit cluster/argo/workflows/gapit3-test-pipeline.yaml -n runai-talmo-lab
```

### 3. Test with 3 Traits Before Full Run
```bash
# Run test pipeline (3 traits) first
argo submit cluster/argo/workflows/gapit3-test-pipeline.yaml -n runai-talmo-lab --watch

# If successful, run full pipeline (186 traits)
argo submit cluster/argo/workflows/gapit3-parallel-pipeline.yaml -n runai-talmo-lab --watch
```

### 4. Monitor Memory Usage
```bash
# Watch pod resource usage in real-time
kubectl top pods -n runai-talmo-lab -l workflows.argoproj.io/workflow=<workflow-name>

# If consistently hitting limits, increase memory allocation
```

### 5. Keep Paths Consistent
```yaml
# Use the same base path across all workflows
data-hostpath: "/hpi/hpi_dev/users/eberrigan/gapit3-gwas/data"
output-hostpath: "/hpi/hpi_dev/users/eberrigan/gapit3-gwas/outputs"
```

### 6. Verify Templates Are Installed
```bash
# List installed WorkflowTemplates
kubectl get workflowtemplate -n runai-talmo-lab

# Update a template after changes
kubectl apply -f cluster/argo/workflow-templates/gapit3-single-trait-template.yaml
```

## Migration Checklist

If you have workflows using the wrong service account:

- [ ] Update `serviceAccountName` to `default` in all workflow files
- [ ] Update `serviceAccountName` to `default` in all template files
- [ ] Apply updated templates: `kubectl apply -f cluster/argo/workflow-templates/`
- [ ] Delete failed workflows: `argo delete <workflow-name> -n runai-talmo-lab`
- [ ] Resubmit workflows with corrected configuration
- [ ] Monitor for `workflowtaskresults` errors (should be gone)
- [ ] Monitor for memory issues (separate from SA issues)

## Workflow Submission Process

### Step 1: Prepare Data
```bash
# Copy data to cluster via network share
# From Windows: Copy to \\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\gapit3-gwas\data\
# Cluster sees it at: /hpi/hpi_dev/users/eberrigan/gapit3-gwas/data/
```

### Step 2: Install/Update Templates
```bash
# Install or update workflow templates
kubectl apply -f cluster/argo/workflow-templates/gapit3-single-trait-template.yaml
kubectl apply -f cluster/argo/workflow-templates/results-collector-template.yaml

# Verify installation
kubectl get workflowtemplate -n runai-talmo-lab
```

### Step 3: Submit Workflow
```bash
# Submit and watch
argo submit cluster/argo/workflows/gapit3-test-pipeline.yaml \
  -n runai-talmo-lab --watch

# Or submit without watching
argo submit cluster/argo/workflows/gapit3-test-pipeline.yaml -n runai-talmo-lab
```

### Step 4: Monitor Progress
```bash
# List workflows
argo list -n runai-talmo-lab

# Get workflow status
argo get <workflow-name> -n runai-talmo-lab

# View logs
argo logs <workflow-name> -n runai-talmo-lab
```

### Step 5: Retrieve Results
```bash
# Results are written to output directory
# From Windows: Access via \\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\gapit3-gwas\outputs\
# Each trait gets its own directory: trait_002_TraitName/, trait_003_TraitName/, etc.
```

## Related Documentation

- [ARGO_SETUP.md](ARGO_SETUP.md) - Full Argo setup guide
- [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md) - Historical context (issue now resolved)
- [MANUAL_RUNAI_EXECUTION.md](MANUAL_RUNAI_EXECUTION.md) - Alternative execution method using RunAI directly
- [RUNAI_SETUP.md](RUNAI_SETUP.md) - RunAI workspace setup

## Troubleshooting Decision Tree

```
Workflow fails
│
├─ Error mentions "workflowtaskresults"?
│  └─ YES → Check serviceAccountName in workflow YAML
│     └─ Is it "default"?
│        ├─ NO → Change to "default", resubmit
│        └─ YES → Check template has "default" SA
│
├─ Error is "OOMKilled" (exit 137)?
│  └─ YES → Increase memory limits in workflow YAML
│     └─ Already at 32Gi+?
│        └─ Reduce dataset size or use fewer models
│
├─ Error is "Pod succeeded but workflow failed"?
│  └─ YES → Service account issue
│     └─ Verify using "default" SA in workflow definition
│
└─ Error is "path not found" or "permission denied"?
   └─ YES → Check path configuration
      ├─ Use /hpi/ prefix (not /mnt/)
      ├─ Verify path exists on cluster
      └─ Check hostPath volume type
```

## FAQ

### Q: Why can't I use `argo-user` for workflow execution?

**A**: The `argo-user` service account lacks permission to create `workflowtaskresults`, which is an internal Argo resource required for tracking task execution state. Only `default` has this permission.

### Q: When do I use `argo-user`?

**A**: Never explicitly. It's used automatically when you run `argo` CLI commands (submit, list, delete, etc.). Your kubeconfig authenticates you as `argo-user` for these operations.

### Q: How do I know if my workflow is using the correct SA?

**A**:
```bash
# Check the workflow definition
kubectl get workflow <name> -n runai-talmo-lab -o yaml | grep serviceAccountName

# Should show: serviceAccountName: default
```

### Q: What's the difference between the network share path and cluster path?

**A**: They're the same storage, different mount points:
- Network share: `\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\`
- Cluster: `/hpi/hpi_dev/users/eberrigan/`

Files you copy to the network share are immediately visible on the cluster.

### Q: Why do GWAS tasks need 32Gi+ memory?

**A**: GAPIT performs genome-wide association analysis with:
- 500K+ SNP markers
- 300+ samples
- Multiple statistical models (BLINK, FarmCPU)
- Matrix operations in R

This requires substantial memory. Lower memory limits result in OOMKilled errors.

### Q: Can I run workflows with less memory?

**A**: Only for validation and trait extraction tasks (2-4Gi). GWAS tasks require 32Gi minimum. Reducing memory for GWAS will cause failures.

## Summary

**Critical Rules**:
1. ✅ All workflow YAML files use `serviceAccountName: default`
2. ✅ Paths use `/hpi/hpi_dev/` prefix
3. ✅ GWAS tasks have 32Gi+ memory allocation
4. ✅ Test with 3 traits before full 186-trait run

**Common Mistakes**:
1. ❌ Using `argo-user` in workflow YAML (causes permission errors)
2. ❌ Using `/mnt/hpi_dev/` path prefix (causes mount errors)
3. ❌ Insufficient memory for GWAS tasks (causes OOMKilled)
4. ❌ Skipping test run before full pipeline (wastes compute resources)

Following these guidelines ensures successful workflow execution on the Salk HPI GPU cluster.
