#!/usr/bin/env bash
set -euo pipefail

# Uncomment the line below to see every command as it executes
# set -x

################################################################################
# check-argo-permissions.sh
################################################################################
# Tests all RBAC permissions for the current kubectl context (argo-user)
# in the runai-talmo-lab namespace.
#
# Usage:
#   ./scripts/check-argo-permissions.sh
#
# Output:
#   Prints a table showing which permissions are granted (✓) or denied (✗)
################################################################################

NAMESPACE="${NAMESPACE:-runai-talmo-lab}"

echo "=============================================="
echo "RBAC Permission Check for argo-user"
echo "Namespace: $NAMESPACE"
echo "Context: $(kubectl config current-context)"
echo "=============================================="
echo ""

# Function to check a permission and format output
check_perm() {
    local resource="$1"
    local verb="$2"
    local description="$3"

    if kubectl auth can-i "$verb" "$resource" -n "$NAMESPACE" &>/dev/null; then
        echo "✓ $description"
        return 0
    else
        echo "✗ $description"
        return 1
    fi
}

################################################################################
# 1. Argo Workflows (argoproj.io) Resources
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. ARGO WORKFLOWS (argoproj.io)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "--- Workflows ---"
check_perm "workflows.argoproj.io" "create" "Create workflows (submit)"
check_perm "workflows.argoproj.io" "get" "Get workflow details"
check_perm "workflows.argoproj.io" "list" "List all workflows"
check_perm "workflows.argoproj.io" "watch" "Watch workflow changes"
check_perm "workflows.argoproj.io" "delete" "Delete workflows"
check_perm "workflows.argoproj.io" "patch" "Patch workflows"
check_perm "workflows.argoproj.io" "update" "Update workflows"
echo ""

echo "--- WorkflowTemplates ---"
check_perm "workflowtemplates.argoproj.io" "create" "Create workflow templates"
check_perm "workflowtemplates.argoproj.io" "get" "Get workflow template details"
check_perm "workflowtemplates.argoproj.io" "list" "List workflow templates"
check_perm "workflowtemplates.argoproj.io" "patch" "Patch workflow templates"
check_perm "workflowtemplates.argoproj.io" "update" "Update workflow templates"
check_perm "workflowtemplates.argoproj.io" "delete" "Delete workflow templates"
echo ""

echo "--- CronWorkflows ---"
check_perm "cronworkflows.argoproj.io" "create" "Create cron workflows"
check_perm "cronworkflows.argoproj.io" "get" "Get cron workflow details"
check_perm "cronworkflows.argoproj.io" "list" "List cron workflows"
check_perm "cronworkflows.argoproj.io" "patch" "Patch cron workflows"
check_perm "cronworkflows.argoproj.io" "update" "Update cron workflows"
check_perm "cronworkflows.argoproj.io" "delete" "Delete cron workflows"
echo ""

echo "--- WorkflowTaskResults (CRITICAL!) ---"
check_perm "workflowtaskresults.argoproj.io" "create" "Create task results (REQUIRED FOR WORKFLOWS TO WORK!)"
check_perm "workflowtaskresults.argoproj.io" "get" "Get task results"
check_perm "workflowtaskresults.argoproj.io" "list" "List task results"
check_perm "workflowtaskresults.argoproj.io" "patch" "Patch task results"
check_perm "workflowtaskresults.argoproj.io" "update" "Update task results"
check_perm "workflowtaskresults.argoproj.io" "delete" "Delete task results"
check_perm "workflowtaskresults.argoproj.io" "watch" "Watch task results"
echo ""

################################################################################
# 2. Kubernetes Core Resources
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. KUBERNETES CORE RESOURCES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "--- Pods & Logs ---"
check_perm "pods" "list" "List pods"
check_perm "pods" "get" "Get pod details"
check_perm "pods" "watch" "Watch pods"
check_perm "pods/log" "get" "Read pod logs"
check_perm "pods" "create" "Create pods"
check_perm "pods" "delete" "Delete pods"
check_perm "pods" "patch" "Patch pods"
check_perm "pods" "update" "Update pods"
echo ""

echo "--- ConfigMaps ---"
check_perm "configmaps" "create" "Create config maps"
check_perm "configmaps" "get" "Get config map details"
check_perm "configmaps" "list" "List config maps"
check_perm "configmaps" "patch" "Patch config maps"
check_perm "configmaps" "update" "Update config maps"
check_perm "configmaps" "delete" "Delete config maps"
echo ""

echo "--- PersistentVolumeClaims ---"
check_perm "persistentvolumeclaims" "create" "Create PVCs"
check_perm "persistentvolumeclaims" "get" "Get PVC details"
check_perm "persistentvolumeclaims" "list" "List PVCs"
check_perm "persistentvolumeclaims" "patch" "Patch PVCs"
check_perm "persistentvolumeclaims" "update" "Update PVCs"
check_perm "persistentvolumeclaims" "delete" "Delete PVCs"
echo ""

echo "--- Services ---"
check_perm "services" "create" "Create services"
check_perm "services" "get" "Get service details"
check_perm "services" "list" "List services"
check_perm "services" "patch" "Patch services"
check_perm "services" "update" "Update services"
check_perm "services" "delete" "Delete services"
echo ""

echo "--- Events ---"
check_perm "events" "get" "Get events"
check_perm "events" "list" "List events"
check_perm "events" "create" "Create events"
check_perm "events" "patch" "Patch events"
check_perm "events" "update" "Update events"
check_perm "events" "delete" "Delete events"
echo ""

echo "--- Jobs ---"
check_perm "jobs" "create" "Create jobs"
check_perm "jobs" "get" "Get job details"
check_perm "jobs" "list" "List jobs"
check_perm "jobs" "patch" "Patch jobs"
check_perm "jobs" "update" "Update jobs"
check_perm "jobs" "delete" "Delete jobs"
echo ""

echo "--- Deployments ---"
check_perm "deployments" "create" "Create deployments"
check_perm "deployments" "get" "Get deployment details"
check_perm "deployments" "list" "List deployments"
check_perm "deployments" "patch" "Patch deployments"
check_perm "deployments" "update" "Update deployments"
check_perm "deployments" "delete" "Delete deployments"
echo ""

echo "--- Namespaces ---"
check_perm "namespaces" "get" "Get namespace details"
check_perm "namespaces" "list" "List namespaces"
check_perm "namespaces" "create" "Create namespaces"
check_perm "namespaces" "delete" "Delete namespaces"
echo ""

echo "--- Nodes ---"
check_perm "nodes" "get" "Get node details"
check_perm "nodes" "list" "List nodes"
echo ""

################################################################################
# 3. Things That Should NOT Work (Security Check)
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. SECURITY CHECK (Should be ✗)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "--- Service Accounts (Should NOT have access) ---"
check_perm "serviceaccounts" "get" "Get service account details"
check_perm "serviceaccounts" "list" "List service accounts"
check_perm "serviceaccounts" "impersonate" "Impersonate service accounts"
echo ""

echo "--- RBAC (Should NOT have access) ---"
check_perm "roles" "get" "Get roles"
check_perm "roles" "list" "List roles"
check_perm "rolebindings" "get" "Get role bindings"
check_perm "rolebindings" "list" "List role bindings"
echo ""

################################################################################
# Summary
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check the critical permission
if kubectl auth can-i create workflowtaskresults.argoproj.io -n "$NAMESPACE" &>/dev/null; then
    echo "✅ WORKFLOWS SHOULD WORK"
    echo "   The argo-user has permission to create workflowtaskresults."
else
    echo "❌ WORKFLOWS WILL FAIL"
    echo "   The argo-user CANNOT create workflowtaskresults."
    echo "   Contact your cluster admin to apply the RBAC configuration."
    echo ""
    echo "   See: docs/RBAC_PERMISSIONS_ISSUE.md"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
