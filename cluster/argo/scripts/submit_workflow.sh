#!/bin/bash
# ==============================================================================
# Submit GAPIT3 GWAS Workflow to Argo
# ==============================================================================
# Wrapper script for submitting workflows with parameter validation
# Usage: ./submit_workflow.sh [test|full] [OPTIONS]
# ==============================================================================

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "$SCRIPT_DIR/../workflows" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../workflow-templates" && pwd)"

# Default parameters (override with environment variables)
NAMESPACE="${ARGO_NAMESPACE:-default}"
IMAGE="${GAPIT_IMAGE:-ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest}"
DATA_PATH="${DATA_HOSTPATH:-/hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data}"
OUTPUT_PATH="${OUTPUT_HOSTPATH:-/hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/outputs}"

# ==============================================================================
# Colors
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# ==============================================================================
# Help message
# ==============================================================================
show_help() {
    cat << EOF
GAPIT3 GWAS - Argo Workflow Submission

Usage:
  ./submit_workflow.sh [COMMAND] [OPTIONS]

Commands:
  test              Submit test workflow (3 traits)
  full              Submit full production workflow (186 traits)
  templates         Install WorkflowTemplates to cluster
  list              List running workflows
  help              Show this help message

Options:
  --namespace NAME          Argo namespace [default: $NAMESPACE]
  --image IMAGE             Container image [default: latest]
  --data-path PATH          Host path for data [required]
  --output-path PATH        Host path for outputs [required]
  --dry-run                 Print workflow without submitting

Note: CPU/memory resources are configured in WorkflowTemplate, not via CLI flags.
      Edit: workflow-templates/gapit3-single-trait-template.yaml
      Parallelism is set via spec.parallelism in workflow YAML files.

Environment Variables:
  ARGO_NAMESPACE            Argo namespace
  GAPIT_IMAGE               Container image
  DATA_HOSTPATH             Data directory path
  OUTPUT_HOSTPATH           Output directory path

Examples:
  # Install templates first (one-time setup)
  ./submit_workflow.sh templates

  # Run test workflow
  ./submit_workflow.sh test \\
    --data-path /path/to/data \\
    --output-path /path/to/outputs

  # Run full pipeline
  ./submit_workflow.sh full \\
    --data-path /path/to/data \\
    --output-path /path/to/outputs

  # Dry run
  ./submit_workflow.sh test --dry-run

EOF
}

# ==============================================================================
# Validation
# ==============================================================================
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check argo CLI
    if ! command -v argo &> /dev/null; then
        print_error "Argo CLI not found. Install: https://github.com/argoproj/argo-workflows/releases"
        exit 1
    fi
    print_success "Argo CLI found: $(argo version --short 2>/dev/null | head -n1 || echo 'installed')"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Required for cluster access."
        exit 1
    fi
    print_success "kubectl found"

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_success "Connected to cluster: $(kubectl config current-context)"

    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace '$NAMESPACE' not found"
        read -p "Create namespace? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl create namespace "$NAMESPACE"
            print_success "Namespace created"
        else
            exit 1
        fi
    fi

    echo ""
}

# ==============================================================================
# Install WorkflowTemplates
# ==============================================================================
install_templates() {
    print_info "Installing WorkflowTemplates to namespace: $NAMESPACE"

    TEMPLATES=(
        "$TEMPLATE_DIR/gapit3-single-trait-template.yaml"
        "$TEMPLATE_DIR/trait-extractor-template.yaml"
        "$TEMPLATE_DIR/results-collector-template.yaml"
    )

    for template in "${TEMPLATES[@]}"; do
        if [[ ! -f "$template" ]]; then
            print_error "Template not found: $template"
            exit 1
        fi

        template_name=$(basename "$template" .yaml)
        print_info "Installing $template_name..."

        kubectl apply -f "$template" -n "$NAMESPACE"
        print_success "Installed: $template_name"
    done

    echo ""
    print_success "All templates installed!"
    print_info "Verify with: kubectl get workflowtemplates -n $NAMESPACE"
}

# ==============================================================================
# Submit workflow
# ==============================================================================
submit_workflow() {
    local workflow_type=$1
    shift  # Remove first argument

    # Parse additional options
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --image)
                IMAGE="$2"
                shift 2
                ;;
            --data-path)
                DATA_PATH="$2"
                shift 2
                ;;
            --output-path)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate paths
    if [[ "$DATA_PATH" == *"YOUR_USERNAME"* ]]; then
        print_error "Please set --data-path to your actual NFS path"
        exit 1
    fi

    if [[ "$OUTPUT_PATH" == *"YOUR_USERNAME"* ]]; then
        print_error "Please set --output-path to your actual NFS path"
        exit 1
    fi

    # Select workflow file
    local workflow_file
    case $workflow_type in
        test)
            workflow_file="$WORKFLOW_DIR/gapit3-test-pipeline.yaml"
            ;;
        full)
            workflow_file="$WORKFLOW_DIR/gapit3-parallel-pipeline.yaml"
            ;;
        *)
            print_error "Unknown workflow type: $workflow_type"
            show_help
            exit 1
            ;;
    esac

    # Display configuration
    cat << EOF

================================================================================
GAPIT3 GWAS - Workflow Submission
================================================================================
Workflow Type:     $workflow_type
Namespace:         $NAMESPACE
Container Image:   $IMAGE

Paths:
  Data:            $DATA_PATH
  Outputs:         $OUTPUT_PATH

Dry Run:           $dry_run

Note: Resources (CPU/memory) are configured in WorkflowTemplate YAML.
      Parallelism is configured via spec.parallelism in workflow YAML.
================================================================================

EOF

    # Construct argo submit command
    ARGO_CMD="argo submit $workflow_file \\
        --namespace $NAMESPACE \\
        --parameter image=$IMAGE \\
        --parameter data-hostpath=$DATA_PATH \\
        --parameter output-hostpath=$OUTPUT_PATH \\
        --watch"

    # Dry run or execute
    if [[ "$dry_run" == "true" ]]; then
        print_info "Dry run - would execute:"
        echo "$ARGO_CMD"
    else
        # Confirm submission
        read -p "Submit workflow? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Submission cancelled"
            exit 0
        fi

        print_info "Submitting workflow..."
        eval "$ARGO_CMD"

        print_success "Workflow submitted!"
        echo ""
        print_info "Monitor with: argo list -n $NAMESPACE"
        print_info "View logs: argo logs <workflow-name> -n $NAMESPACE"
    fi
}

# ==============================================================================
# List workflows
# ==============================================================================
list_workflows() {
    print_info "Workflows in namespace: $NAMESPACE"
    echo ""
    argo list -n "$NAMESPACE"
}

# ==============================================================================
# Main
# ==============================================================================
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    COMMAND=$1
    shift

    case $COMMAND in
        test|full)
            check_prerequisites
            submit_workflow "$COMMAND" "$@"
            ;;
        templates)
            check_prerequisites
            install_templates
            ;;
        list)
            list_workflows
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
