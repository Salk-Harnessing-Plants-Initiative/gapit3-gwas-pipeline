# RBAC Permissions Issue for Argo Workflows

## Issue Summary

Argo Workflows in the `runai-talmo-lab` namespace cannot create `workflowtaskresults` resources, causing workflows to fail with exit code 64 even when the actual pod work completes successfully.

## Error Message

```
Error (exit code 64): workflowtaskresults.argoproj.io is forbidden:
User "system:serviceaccount:runai-talmo-lab:default" cannot create resource
"workflowtaskresults" in API group "argoproj.io" in the namespace "runai-talmo-lab"
```

## Impact

- Workflow pods execute successfully (exit code 0)
- Argo cannot save task results due to permissions
- Workflow is marked as "Error" instead of "Succeeded"
- Subsequent DAG tasks are not triggered (marked as "Omitted: depends condition not met")
- Pipeline cannot complete end-to-end

## Current Configuration

- **Namespace**: `runai-talmo-lab`
- **Service Account**: `default`
- **Workflow Engine**: Argo Workflows
- **Missing Permission**: Create `workflowtaskresults.argoproj.io`

## Required Fix

Grant the `default` service account in the `runai-talmo-lab` namespace permission to create Argo Workflow task results.

### Option 1: Role + RoleBinding (Recommended)

Create a Role and RoleBinding specifically for Argo Workflows:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-workflow-role
  namespace: runai-talmo-lab
rules:
- apiGroups:
  - argoproj.io
  resources:
  - workflowtaskresults
  verbs:
  - create
  - get
  - list
  - patch
  - update
  - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-workflow-rolebinding
  namespace: runai-talmo-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-workflow-role
subjects:
- kind: ServiceAccount
  name: default
  namespace: runai-talmo-lab
```

Apply with:
```bash
kubectl apply -f argo-rbac.yaml -n runai-talmo-lab
```

### Option 2: Use Dedicated Service Account

Create a dedicated service account for Argo Workflows with appropriate permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-workflow-sa
  namespace: runai-talmo-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-workflow-role
  namespace: runai-talmo-lab
rules:
- apiGroups:
  - argoproj.io
  resources:
  - workflowtaskresults
  - workflows
  - workflowtemplates
  verbs:
  - create
  - get
  - list
  - patch
  - update
  - delete
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-workflow-rolebinding
  namespace: runai-talmo-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-workflow-role
subjects:
- kind: ServiceAccount
  name: argo-workflow-sa
  namespace: runai-talmo-lab
```

Then update workflow files to use this service account:
```yaml
spec:
  serviceAccountName: argo-workflow-sa
```

## Verification Steps

After applying the RBAC changes, verify the fix:

1. **Check permissions**:
```bash
kubectl auth can-i create workflowtaskresults.argoproj.io \
  --as=system:serviceaccount:runai-talmo-lab:default \
  -n runai-talmo-lab
```

Expected output: `yes`

2. **Submit test workflow**:
```bash
kubectl create -f cluster/argo/workflows/gapit3-test-pipeline.yaml -n runai-talmo-lab
```

3. **Monitor workflow**:
```bash
kubectl get workflow -n runai-talmo-lab --watch
```

Expected status: `Succeeded` (not `Error`)

4. **Check pod logs** (should show successful completion):
```bash
WORKFLOW_NAME=$(kubectl get workflow -n runai-talmo-lab --sort-by=.metadata.creationTimestamp -o name | tail -1)
kubectl logs -n runai-talmo-lab -l workflows.argoproj.io/workflow=${WORKFLOW_NAME##*/} --all-containers
```

## Related Documentation

- [Argo Workflows RBAC](https://argoproj.github.io/argo-workflows/workflow-rbac/)
- [Kubernetes RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Salk RunAI Guide](https://researchit.salk.edu/runai/kubectl-and-argo-cli-usage/)

## Contact

If you have questions about this issue, please contact:
- **Project**: GAPIT3 GWAS Pipeline
- **Repository**: https://github.com/salk-harnessing-plants-initiative/gapit3-gwas-pipeline
- **Related Workflow**: `gapit3-test-nhqqx` (failed with exit code 64 on 2025-11-07)

## Additional Notes

- The workflow validation errors have been resolved (parameterized volumes and resources)
- Pods are executing successfully (exit code 0)
- This is purely a permissions issue preventing Argo from recording task results
- Once fixed, the full GWAS pipeline (186 parallel traits) can be executed
