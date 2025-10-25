#!/bin/bash
# ==============================================================================
# Monitor GAPIT3 GWAS Workflows
# ==============================================================================
# Real-time monitoring and status tracking for Argo workflows
# Usage: ./monitor_workflow.sh [WORKFLOW_NAME]
# ==============================================================================

set -euo pipefail

NAMESPACE="${ARGO_NAMESPACE:-default}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# ==============================================================================
# Show workflow status
# ==============================================================================
show_status() {
    local workflow=$1

    print_info "Workflow: $workflow"
    echo ""

    # Get workflow status
    argo get "$workflow" -n "$NAMESPACE"

    echo ""
    echo "=========================================="
    echo "Step-by-step status:"
    echo "=========================================="

    # Show node status
    argo get "$workflow" -n "$NAMESPACE" --output json | \
        jq -r '.status.nodes | to_entries[] | "\(.value.displayName): \(.value.phase)"'
}

# ==============================================================================
# Watch workflow logs
# ==============================================================================
watch_logs() {
    local workflow=$1

    print_info "Streaming logs for: $workflow"
    print_warning "Press Ctrl+C to stop"
    echo ""

    argo logs "$workflow" -n "$NAMESPACE" --follow
}

# ==============================================================================
# Show workflow tree
# ==============================================================================
show_tree() {
    local workflow=$1

    print_info "Workflow execution tree:"
    echo ""

    argo get "$workflow" -n "$NAMESPACE" --output tree
}

# ==============================================================================
# List all workflows
# ==============================================================================
list_all() {
    print_info "All workflows in namespace: $NAMESPACE"
    echo ""

    argo list -n "$NAMESPACE"
}

# ==============================================================================
# Monitor progress
# ==============================================================================
monitor_progress() {
    local workflow=$1

    while true; do
        clear
        echo "=========================================="
        echo "GAPIT3 GWAS - Workflow Monitor"
        echo "Workflow: $workflow"
        echo "Namespace: $NAMESPACE"
        echo "Time: $(date)"
        echo "=========================================="
        echo ""

        # Get phase
        phase=$(argo get "$workflow" -n "$NAMESPACE" --output json | jq -r '.status.phase // "Unknown"')

        echo "Status: $phase"
        echo ""

        # Count completed/running/failed nodes
        nodes=$(argo get "$workflow" -n "$NAMESPACE" --output json | jq '.status.nodes // {}')

        succeeded=$(echo "$nodes" | jq '[.[] | select(.phase == "Succeeded")] | length')
        running=$(echo "$nodes" | jq '[.[] | select(.phase == "Running")] | length')
        failed=$(echo "$nodes" | jq '[.[] | select(.phase == "Failed")] | length')
        pending=$(echo "$nodes" | jq '[.[] | select(.phase == "Pending")] | length')

        echo "Progress:"
        echo "  ✓ Succeeded: $succeeded"
        echo "  ⟳ Running:   $running"
        echo "  ⏸ Pending:   $pending"
        echo "  ✗ Failed:    $failed"

        echo ""
        echo "Recent nodes:"
        echo "$nodes" | jq -r 'to_entries | sort_by(.value.finishedAt // .value.startedAt // "") | reverse | .[0:10] | .[] | "  \(.value.displayName): \(.value.phase)"'

        if [[ "$phase" == "Succeeded" || "$phase" == "Failed" || "$phase" == "Error" ]]; then
            echo ""
            print_info "Workflow completed with status: $phase"
            break
        fi

        echo ""
        echo "Refreshing in 10 seconds... (Ctrl+C to stop)"
        sleep 10
    done
}

# ==============================================================================
# Main
# ==============================================================================

if [[ $# -eq 0 ]]; then
    # No arguments - list all workflows
    list_all
    exit 0
fi

COMMAND=$1

case $COMMAND in
    -h|--help|help)
        cat << EOF
GAPIT3 GWAS - Workflow Monitor

Usage:
  ./monitor_workflow.sh                    List all workflows
  ./monitor_workflow.sh <workflow-name>    Monitor specific workflow
  ./monitor_workflow.sh status <workflow>  Show workflow status
  ./monitor_workflow.sh logs <workflow>    Stream workflow logs
  ./monitor_workflow.sh tree <workflow>    Show execution tree
  ./monitor_workflow.sh watch <workflow>   Watch progress (auto-refresh)

Examples:
  ./monitor_workflow.sh
  ./monitor_workflow.sh gapit3-test-abc123
  ./monitor_workflow.sh status gapit3-gwas-parallel-xyz789
  ./monitor_workflow.sh logs gapit3-test-abc123
  ./monitor_workflow.sh watch gapit3-gwas-parallel-xyz789

EOF
        ;;

    status)
        [[ $# -lt 2 ]] && { echo "Error: workflow name required"; exit 1; }
        show_status "$2"
        ;;

    logs)
        [[ $# -lt 2 ]] && { echo "Error: workflow name required"; exit 1; }
        watch_logs "$2"
        ;;

    tree)
        [[ $# -lt 2 ]] && { echo "Error: workflow name required"; exit 1; }
        show_tree "$2"
        ;;

    watch)
        [[ $# -lt 2 ]] && { echo "Error: workflow name required"; exit 1; }
        monitor_progress "$2"
        ;;

    *)
        # Assume it's a workflow name
        monitor_progress "$COMMAND"
        ;;
esac
