#!/bin/bash
# ==============================================================================
# GAPIT3 Pipeline - Quick Deployment & Test Script
# ==============================================================================
# This script automates the deployment and testing of the GAPIT3 pipeline
# on Argo Workflows with optional RunAI integration.
# ==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (update these!)
NAMESPACE="${NAMESPACE:-default}"
DATA_PATH="${DATA_PATH:-/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data}"
OUTPUT_PATH="${OUTPUT_PATH:-/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs}"
IMAGE="${IMAGE:-ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest}"

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 not found. Please install $1."
        exit 1
    fi
}

# ==============================================================================
# Preflight Checks
# ==============================================================================

preflight_checks() {
    log_info "Running preflight checks..."

    # Check required commands
    check_command kubectl
    check_command argo

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_success "Kubernetes cluster accessible"

    # Check Argo Workflows
    if ! kubectl get namespace argo &> /dev/null; then
        log_warning "Argo namespace not found. Is Argo Workflows installed?"
    else
        log_success "Argo Workflows detected"
    fi

    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace '$NAMESPACE' does not exist. Creating..."
        kubectl create namespace "$NAMESPACE"
    fi
    log_success "Using namespace: $NAMESPACE"

    # Verify Docker image is accessible
    log_info "Verifying Docker image: $IMAGE"
    # Note: Can't actually pull in cluster context, but we can check later

    log_success "Preflight checks complete"
    echo ""
}

# ==============================================================================
# Deploy Workflow Templates
# ==============================================================================

deploy_templates() {
    log_info "Deploying workflow templates..."

    cd "$(dirname "$0")/../cluster/argo/workflow-templates" || exit 1

    for template in *.yaml; do
        log_info "Applying template: $template"
        kubectl apply -f "$template" -n "$NAMESPACE"
    done

    log_success "Workflow templates deployed"

    # Verify templates
    log_info "Verifying templates..."
    kubectl get workflowtemplates -n "$NAMESPACE"

    echo ""
}

# ==============================================================================
# Update Configuration
# ==============================================================================

update_config() {
    log_info "Configuration summary:"
    echo "  Namespace:     $NAMESPACE"
    echo "  Data Path:     $DATA_PATH"
    echo "  Output Path:   $OUTPUT_PATH"
    echo "  Docker Image:  $IMAGE"
    echo ""

    if [[ "$DATA_PATH" == *"YOUR_USERNAME"* ]]; then
        log_warning "DATA_PATH still contains YOUR_USERNAME placeholder!"
        log_warning "Set environment variable: export DATA_PATH=/path/to/your/data"
        echo ""
        read -p "Do you want to continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# ==============================================================================
# Submit Test Workflow
# ==============================================================================

submit_test_workflow() {
    log_info "Submitting test workflow (3 traits)..."

    cd "$(dirname "$0")/../cluster/argo/workflows" || exit 1

    WORKFLOW_NAME=$(argo submit gapit3-test-pipeline.yaml \
        -n "$NAMESPACE" \
        --parameter image="$IMAGE" \
        --parameter data-hostpath="$DATA_PATH" \
        --parameter output-hostpath="$OUTPUT_PATH" \
        --output name)

    log_success "Workflow submitted: $WORKFLOW_NAME"
    echo ""

    # Show workflow info
    log_info "Workflow details:"
    argo get "$WORKFLOW_NAME" -n "$NAMESPACE"
    echo ""

    # Ask if user wants to watch logs
    read -p "Watch workflow logs? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        argo logs "$WORKFLOW_NAME" -n "$NAMESPACE" --follow
    fi

    echo ""
    log_info "To view workflow status later, run:"
    echo "  argo get $WORKFLOW_NAME -n $NAMESPACE"
    echo "  argo logs $WORKFLOW_NAME -n $NAMESPACE --follow"
    echo ""

    log_info "To view in Argo UI:"
    echo "  kubectl port-forward -n argo svc/argo-server 2746:2746"
    echo "  Then open: http://localhost:2746"
    echo ""
}

# ==============================================================================
# Validate Results
# ==============================================================================

validate_results() {
    log_info "Validating results (requires cluster access to output path)..."
    log_warning "This step requires SSH access to cluster nodes or mounted storage"

    read -p "Do you have access to the output path locally? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -d "$OUTPUT_PATH" ]; then
            log_info "Output directory contents:"
            ls -lh "$OUTPUT_PATH"

            # Check for expected files
            if ls "$OUTPUT_PATH"/trait_*/ &> /dev/null; then
                log_success "Found trait output directories"
            else
                log_warning "No trait output directories found yet"
            fi

            if [ -f "$OUTPUT_PATH/traits_manifest.yaml" ]; then
                log_success "Found traits manifest"
            fi
        else
            log_warning "Output path not accessible locally: $OUTPUT_PATH"
        fi
    fi
    echo ""
}

# ==============================================================================
# Cleanup
# ==============================================================================

cleanup() {
    log_info "Cleanup options:"
    echo "  1. Delete workflow templates"
    echo "  2. Delete all workflows"
    echo "  3. Delete everything (templates + workflows)"
    echo "  4. Skip cleanup"
    read -p "Select option (1-4): " -n 1 -r
    echo

    case $REPLY in
        1)
            log_info "Deleting workflow templates..."
            kubectl delete workflowtemplates -l pipeline=gapit3-gwas -n "$NAMESPACE"
            log_success "Templates deleted"
            ;;
        2)
            log_info "Deleting workflows..."
            argo delete --all -n "$NAMESPACE"
            log_success "Workflows deleted"
            ;;
        3)
            log_info "Deleting everything..."
            kubectl delete workflowtemplates -l pipeline=gapit3-gwas -n "$NAMESPACE"
            argo delete --all -n "$NAMESPACE"
            log_success "All resources deleted"
            ;;
        *)
            log_info "Skipping cleanup"
            ;;
    esac
    echo ""
}

# ==============================================================================
# Main Menu
# ==============================================================================

show_menu() {
    echo "=============================================="
    echo "  GAPIT3 Pipeline - Argo Deployment Tool"
    echo "=============================================="
    echo ""
    echo "Select an action:"
    echo "  1. Run preflight checks"
    echo "  2. Deploy workflow templates"
    echo "  3. Submit test workflow (3 traits)"
    echo "  4. Submit production workflow (184 traits)"
    echo "  5. List workflows"
    echo "  6. Validate results"
    echo "  7. Cleanup resources"
    echo "  8. Full deployment (steps 1-3)"
    echo "  9. Exit"
    echo ""
}

# ==============================================================================
# Main Script
# ==============================================================================

main() {
    # If arguments provided, run in automated mode
    if [ $# -gt 0 ]; then
        case "$1" in
            --full)
                preflight_checks
                update_config
                deploy_templates
                submit_test_workflow
                ;;
            --deploy)
                deploy_templates
                ;;
            --test)
                submit_test_workflow
                ;;
            --cleanup)
                cleanup
                ;;
            *)
                echo "Usage: $0 [--full|--deploy|--test|--cleanup]"
                exit 1
                ;;
        esac
        exit 0
    fi

    # Interactive mode
    while true; do
        show_menu
        read -p "Enter choice (1-9): " choice
        echo ""

        case $choice in
            1)
                preflight_checks
                ;;
            2)
                deploy_templates
                ;;
            3)
                submit_test_workflow
                ;;
            4)
                log_info "Submitting production workflow (184 traits)..."
                cd "$(dirname "$0")/../cluster/argo/workflows" || exit 1
                WORKFLOW_NAME=$(argo submit gapit3-parallel-pipeline.yaml \
                    -n "$NAMESPACE" \
                    --parameter image="$IMAGE" \
                    --parameter data-hostpath="$DATA_PATH" \
                    --parameter output-hostpath="$OUTPUT_PATH" \
                    --output name)
                log_success "Production workflow submitted: $WORKFLOW_NAME"
                echo ""
                ;;
            5)
                log_info "Listing workflows..."
                argo list -n "$NAMESPACE"
                echo ""
                ;;
            6)
                validate_results
                ;;
            7)
                cleanup
                ;;
            8)
                preflight_checks
                update_config
                deploy_templates
                submit_test_workflow
                ;;
            9)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid choice"
                ;;
        esac

        read -p "Press Enter to continue..."
        clear
    done
}

# Run main function
main "$@"
