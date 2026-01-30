# Kubernetes Permissions Reference

Consolidated reference for all Kubernetes RBAC and permissions required by the GAPIT3 GWAS Pipeline.

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Service Accounts](#service-accounts)
3. [RBAC Roles](#rbac-roles)
4. [Volume Permissions](#volume-permissions)
5. [Verification Commands](#verification-commands)
6. [Troubleshooting](#troubleshooting)

---

## Quick Reference

| Component | Service Account | Purpose |
|-----------|----------------|---------|
| CLI Operations | `argo-user` | Human workflow submission via `argo` CLI |
| Pod Execution | `default` | Workflow task execution (REQUIRED) |

**Critical Rule**: All workflow YAML files MUST use `serviceAccountName: default`.

---

## Service Accounts

### argo-user (Human Submission)

Used automatically when running `argo` CLI commands.

**Permissions**:
- Create/list/delete workflows
- Watch workflow status
- Read pod logs

**Limitations**:
- LACKS `workflowtaskresults` create permission
- DO NOT use as `serviceAccountName` in workflow YAML

### default (Pod Execution)

Used by pods executing workflow tasks.

**Permissions**:
- All workflow execution permissions
- `workflowtaskresults` create/update (critical)
- Pod create/manage
- Volume access

**Usage**:
```yaml
spec:
  serviceAccountName: default  # REQUIRED in all workflow files
```

---

## RBAC Roles

### Required Permissions for Workflow Execution

The `default` service account requires these permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-workflow-role
  namespace: <your-namespace>
rules:
- apiGroups: ["argoproj.io"]
  resources: ["workflowtaskresults"]
  verbs: ["create", "get", "list", "patch", "update", "delete"]
- apiGroups: ["argoproj.io"]
  resources: ["workflows", "workflowtemplates"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
```

### RoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-workflow-rolebinding
  namespace: <your-namespace>
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-workflow-role
subjects:
- kind: ServiceAccount
  name: default
  namespace: <your-namespace>
```

---

## Volume Permissions

### hostPath Volumes

The pipeline uses hostPath volumes for data access:

```yaml
volumes:
- name: data-volume
  hostPath:
    path: /hpi/hpi_dev/users/<username>/data
    type: Directory
- name: output-volume
  hostPath:
    path: /hpi/hpi_dev/users/<username>/outputs
    type: DirectoryOrCreate
```

**Requirements**:
- Paths must exist on cluster nodes
- Use `/hpi/` prefix (not `/mnt/`)
- Read permissions for genotype/phenotype data
- Write permissions for output directory

### Path Mapping

| Context | Base Path |
|---------|-----------|
| Windows Share | `\\multilab-na.ad.salk.edu\hpi_dev\users\` |
| WSL | `/mnt/hpi_dev/users/` |
| Cluster | `/hpi/hpi_dev/users/` |

---

## Verification Commands

### Check Service Account Permissions

```bash
# Verify default SA has workflowtaskresults permission
kubectl auth can-i create workflowtaskresults.argoproj.io \
  --as=system:serviceaccount:<namespace>:default \
  -n <namespace>
# Expected: yes

# Verify argo-user SA lacks this permission (expected behavior)
kubectl auth can-i create workflowtaskresults.argoproj.io \
  --as=system:serviceaccount:<namespace>:argo-user \
  -n <namespace>
# Expected: no
```

### Check Workflow Configuration

```bash
# Verify all workflow files use correct SA
grep "serviceAccountName" cluster/argo/**/*.yaml
# All should show: default

# Check installed WorkflowTemplates
kubectl get workflowtemplate -n <namespace>
```

### Check Pod Service Account at Runtime

```bash
# Get pods from a workflow
kubectl get pods -n <namespace> -l workflows.argoproj.io/workflow=<workflow-name>

# Describe pod to verify SA
kubectl describe pod <pod-name> -n <namespace> | grep "Service Account"
# Expected: Service Account: default
```

---

## Troubleshooting

### Error: workflowtaskresults forbidden

```
Error (exit code 64): workflowtaskresults.argoproj.io is forbidden
```

**Cause**: Workflow YAML uses `argo-user` instead of `default`

**Fix**:
1. Check workflow file: `grep serviceAccountName <workflow.yaml>`
2. Change to `serviceAccountName: default`
3. Reapply templates: `kubectl apply -f cluster/argo/workflow-templates/`
4. Resubmit workflow

### Error: Pod succeeded but workflow failed

**Cause**: Service account lacks permission to record task success

**Fix**: Verify workflow uses `serviceAccountName: default`

### Error: Mount path not found

```
Error: mkdir: cannot create directory '/data': Read-only file system
```

**Cause**: Incorrect path or volume type

**Fix**:
- Use `/hpi/hpi_dev/` prefix (not `/mnt/hpi_dev/`)
- Verify `hostPath` volume type
- Check path exists on cluster: `ls /hpi/hpi_dev/users/<username>/`

### Error: Permission denied on volume

**Cause**: Insufficient file permissions on NFS/hostPath

**Fix**:
- Check directory permissions: `ls -la /hpi/hpi_dev/users/<username>/`
- Ensure output directory is writable
- Contact cluster admin if permissions need adjustment

---

## Related Documentation

- [argo-service-accounts.md](argo-service-accounts.md) - Detailed SA documentation with examples
- [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md) - Historical context (issue resolved)
- [ARGO_SETUP.md](ARGO_SETUP.md) - Full Argo Workflows setup guide
- [WORKFLOW_ARCHITECTURE.md](WORKFLOW_ARCHITECTURE.md) - Technical architecture

---

*Last updated: 2025-01-03*