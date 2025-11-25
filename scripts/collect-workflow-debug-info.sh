#!/usr/bin/env bash
set -euo pipefail

# Uncomment the line below to see every command as it executes
# set -x

################################################################################
# collect-workflow-debug-info.sh
################################################################################
# Collects all debug information for a failed workflow to share with admin
#
# Usage:
#   ./scripts/collect-workflow-debug-info.sh [workflow-name]
#
# If no workflow name provided, uses the most recent workflow
################################################################################

NAMESPACE="${NAMESPACE:-runai-talmo-lab}"
OUTPUT_DIR="workflow-debug-$(date +%Y%m%d-%H%M%S)"

# Get workflow name from argument or find the most recent one
if [ $# -eq 0 ]; then
    echo "No workflow name provided, finding most recent workflow..."
    WORKFLOW_NAME=$(kubectl get workflows -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
    echo "Using workflow: $WORKFLOW_NAME"
else
    WORKFLOW_NAME="$1"
    echo "Using provided workflow: $WORKFLOW_NAME"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo "Collecting debug information into: $OUTPUT_DIR/"
echo ""

################################################################################
# 1. Permissions Check
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Checking RBAC Permissions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "scripts/check-argo-permissions.sh" ]; then
    chmod +x scripts/check-argo-permissions.sh
    ./scripts/check-argo-permissions.sh > "$OUTPUT_DIR/permissions-check.txt" 2>&1 || true
    echo "✓ Saved to: $OUTPUT_DIR/permissions-check.txt"
else
    echo "⚠ Warning: scripts/check-argo-permissions.sh not found, skipping permissions check"
fi
echo ""

################################################################################
# 2. Workflow Details
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Getting Workflow Details"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Full workflow YAML
echo "Getting workflow YAML..."
kubectl get workflow "$WORKFLOW_NAME" -n "$NAMESPACE" -o yaml > "$OUTPUT_DIR/workflow-full.yaml" 2>&1 || true
echo "✓ Saved to: $OUTPUT_DIR/workflow-full.yaml"

# Workflow status summary
echo "Getting workflow status..."
kubectl get workflow "$WORKFLOW_NAME" -n "$NAMESPACE" -o json | jq '{
  name: .metadata.name,
  phase: .status.phase,
  startedAt: .status.startedAt,
  finishedAt: .status.finishedAt,
  message: .status.message,
  nodes: [.status.nodes[] | {
    name: .displayName,
    phase: .phase,
    message: .message,
    exitCode: .outputs.exitCode
  }]
}' > "$OUTPUT_DIR/workflow-status.json" 2>&1 || echo "jq not available, skipping JSON status"

echo "✓ Saved to: $OUTPUT_DIR/workflow-status.json"
echo ""

################################################################################
# 3. Pod Information
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Getting Pod Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# List all pods for this workflow
echo "Listing workflow pods..."
kubectl get pods -n "$NAMESPACE" -l "workflows.argoproj.io/workflow=$WORKFLOW_NAME" > "$OUTPUT_DIR/pods-list.txt" 2>&1 || true
echo "✓ Saved to: $OUTPUT_DIR/pods-list.txt"

# Get detailed pod info for each pod
echo "Getting detailed pod information..."
kubectl get pods -n "$NAMESPACE" -l "workflows.argoproj.io/workflow=$WORKFLOW_NAME" -o yaml > "$OUTPUT_DIR/pods-full.yaml" 2>&1 || true
echo "✓ Saved to: $OUTPUT_DIR/pods-full.yaml"

# Get pod names
POD_NAMES=$(kubectl get pods -n "$NAMESPACE" -l "workflows.argoproj.io/workflow=$WORKFLOW_NAME" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

echo ""

################################################################################
# 4. Pod Logs
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Collecting Pod Logs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$POD_NAMES" ]; then
    for POD_NAME in $POD_NAMES; do
        echo "Getting logs from pod: $POD_NAME"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" --all-containers > "$OUTPUT_DIR/logs-${POD_NAME}.txt" 2>&1 || true
        echo "✓ Saved to: $OUTPUT_DIR/logs-${POD_NAME}.txt"

        # Also get previous logs if pod restarted
        kubectl logs -n "$NAMESPACE" "$POD_NAME" --all-containers --previous > "$OUTPUT_DIR/logs-${POD_NAME}-previous.txt" 2>&1 || true
    done
else
    echo "⚠ No pods found for workflow: $WORKFLOW_NAME"
fi
echo ""

################################################################################
# 5. Events
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Getting Kubernetes Events"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Getting events for workflow..."
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$WORKFLOW_NAME" > "$OUTPUT_DIR/events-workflow.txt" 2>&1 || true
echo "✓ Saved to: $OUTPUT_DIR/events-workflow.txt"

if [ -n "$POD_NAMES" ]; then
    for POD_NAME in $POD_NAMES; do
        echo "Getting events for pod: $POD_NAME"
        kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$POD_NAME" > "$OUTPUT_DIR/events-${POD_NAME}.txt" 2>&1 || true
    done
fi
echo ""

################################################################################
# 6. Context Information
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Collecting Context Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > "$OUTPUT_DIR/context-info.txt" <<EOF
Kubernetes Context Information
===============================

Current Context:
$(kubectl config current-context)

Current Namespace:
$(kubectl config view --minify -o jsonpath='{..namespace}')

Kubectl Version:
$(kubectl version --client --short 2>/dev/null || kubectl version --client)

Workflow Name:
$WORKFLOW_NAME

Namespace:
$NAMESPACE

Timestamp:
$(date -u +"%Y-%m-%d %H:%M:%S UTC")

EOF
echo "✓ Saved to: $OUTPUT_DIR/context-info.txt"
echo ""

################################################################################
# 7. Critical Permission Test
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Testing Critical Permission"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > "$OUTPUT_DIR/critical-permission-test.txt" <<EOF
Critical Permission Test
========================

Testing: kubectl auth can-i create workflowtaskresults.argoproj.io -n $NAMESPACE

Result:
EOF

if kubectl auth can-i create workflowtaskresults.argoproj.io -n "$NAMESPACE" >> "$OUTPUT_DIR/critical-permission-test.txt" 2>&1; then
    echo "yes" >> "$OUTPUT_DIR/critical-permission-test.txt"
    echo "✓ Permission GRANTED"
else
    echo "no" >> "$OUTPUT_DIR/critical-permission-test.txt"
    echo "✗ Permission DENIED (this is the problem!)"
fi
echo "✓ Saved to: $OUTPUT_DIR/critical-permission-test.txt"
echo ""

################################################################################
# 8. Create Summary
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. Creating Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > "$OUTPUT_DIR/README.txt" <<EOF
Argo Workflow Debug Information
================================

This directory contains debug information for workflow: $WORKFLOW_NAME

Files:
------
- context-info.txt                : Kubectl context and environment info
- permissions-check.txt           : Complete RBAC permissions audit
- critical-permission-test.txt    : Test of the workflowtaskresults permission
- workflow-full.yaml              : Complete workflow YAML definition
- workflow-status.json            : Workflow status summary (requires jq)
- pods-list.txt                   : List of pods created by workflow
- pods-full.yaml                  : Detailed pod specifications
- logs-<pod-name>.txt             : Logs from each pod
- events-workflow.txt             : Kubernetes events for workflow
- events-<pod-name>.txt           : Kubernetes events for each pod

Key Information for Admin:
--------------------------
1. Check critical-permission-test.txt to see if workflowtaskresults permission is granted
2. Check workflow-full.yaml for the error message in status.nodes[].message
3. Check logs-*.txt for pod execution logs (pods may succeed even if workflow fails)
4. Check permissions-check.txt for complete RBAC audit

Common Issue:
-------------
If the workflow shows "Error (exit code 64)" but the pod shows "exitCode: 0",
this means the pod succeeded but Argo couldn't save the task results due to
missing RBAC permission for workflowtaskresults.argoproj.io.

Required RBAC fix is documented in: docs/RBAC_PERMISSIONS_ISSUE.md

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF

echo "✓ Saved to: $OUTPUT_DIR/README.txt"
echo ""

################################################################################
# Summary
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "COLLECTION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All debug information saved to: $OUTPUT_DIR/"
echo ""
echo "To share with admin:"
echo "  tar -czf ${OUTPUT_DIR}.tar.gz $OUTPUT_DIR/"
echo "  # Then send ${OUTPUT_DIR}.tar.gz"
echo ""
echo "Quick check:"
if kubectl auth can-i create workflowtaskresults.argoproj.io -n "$NAMESPACE" &>/dev/null; then
    echo "  ✅ workflowtaskresults permission: GRANTED"
else
    echo "  ❌ workflowtaskresults permission: DENIED"
fi
echo ""
