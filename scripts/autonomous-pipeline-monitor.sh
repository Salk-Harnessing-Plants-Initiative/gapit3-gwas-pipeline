#!/bin/bash
# ===========================================================================
# Autonomous Pipeline Monitor
# ===========================================================================
# Monitors Argo workflow until completion, validates outputs, runs aggregation,
# and uploads results to Box - all without user intervention.
#
# Usage:
#   nohup ./scripts/autonomous-pipeline-monitor.sh \
#     --workflow gapit3-gwas-retry-h5nzl-n7qs5 \
#     --output-dir /mnt/hpi_dev/users/eberrigan/20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized/outputs \
#     --expected-traits 186 \
#     --dataset-name 20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized \
#     --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:feat-add-ci-testing-workflows-test \
#     > /dev/null 2>&1 &
#
# All output logged to: $OUTPUT_DIR/pipeline_monitor.log
# ===========================================================================

set -uo pipefail

# ===========================================================================
# Configuration
# ===========================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults
POLL_INTERVAL=300        # 5 minutes
TIMEOUT_HOURS=48
SUCCESS_THRESHOLD=95     # Percent of expected traits required
KUBECONFIG="$HOME/.kube/kubeconfig-runai-talmo-lab.yaml"
NAMESPACE="runai-talmo-lab"
BOX_DEST="Phenotyping_team_GH/sleap-roots-pipeline-results"
RCLONE_PATH="C:\\Users\\Elizabeth\\Desktop\\rclone_exe\\rclone.exe"

# Required parameters (set via arguments)
WORKFLOW=""
OUTPUT_DIR=""
EXPECTED_TRAITS=""
DATASET_NAME=""
IMAGE=""

# ===========================================================================
# Logging
# ===========================================================================
LOG_FILE=""

log() {
    local level="$1"
    shift
    local timestamp=$(date -Iseconds)
    echo "[$timestamp] [$level] $*" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# ===========================================================================
# Usage
# ===========================================================================
show_help() {
    cat << 'EOF'
Autonomous Pipeline Monitor - Unattended GWAS workflow completion handler

USAGE:
    autonomous-pipeline-monitor.sh [OPTIONS]

REQUIRED OPTIONS:
    --workflow NAME         Argo workflow name to monitor
    --output-dir PATH       WSL path to outputs directory
    --expected-traits N     Number of expected complete traits
    --dataset-name NAME     Dataset folder name for Box upload
    --image IMAGE           Docker image for aggregation workflow

OPTIONAL OPTIONS:
    --poll-interval SEC     Polling interval in seconds (default: 300)
    --timeout HOURS         Maximum wait time in hours (default: 48)
    --box-dest PATH         Box destination path (default: Phenotyping_team_GH/sleap-roots-pipeline-results)
    --success-threshold PCT Percent of traits required for success (default: 95)
    --help                  Show this help message

EXAMPLE:
    nohup ./scripts/autonomous-pipeline-monitor.sh \
      --workflow gapit3-gwas-retry-h5nzl-n7qs5 \
      --output-dir /mnt/hpi_dev/users/eberrigan/dataset/outputs \
      --expected-traits 186 \
      --dataset-name 20260104_dataset_name \
      --image ghcr.io/org/image:tag \
      > /dev/null 2>&1 &

EOF
}

# ===========================================================================
# Argument Parsing
# ===========================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --workflow)
            WORKFLOW="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --expected-traits)
            EXPECTED_TRAITS="$2"
            shift 2
            ;;
        --dataset-name)
            DATASET_NAME="$2"
            shift 2
            ;;
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --poll-interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_HOURS="$2"
            shift 2
            ;;
        --box-dest)
            BOX_DEST="$2"
            shift 2
            ;;
        --success-threshold)
            SUCCESS_THRESHOLD="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$WORKFLOW" || -z "$OUTPUT_DIR" || -z "$EXPECTED_TRAITS" || -z "$DATASET_NAME" || -z "$IMAGE" ]]; then
    echo "ERROR: Missing required parameters"
    show_help
    exit 1
fi

# Validate numeric inputs
if ! [[ "$EXPECTED_TRAITS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --expected-traits must be a positive integer, got: $EXPECTED_TRAITS"
    exit 1
fi
if ! [[ "$POLL_INTERVAL" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --poll-interval must be a positive integer, got: $POLL_INTERVAL"
    exit 1
fi
if ! [[ "$TIMEOUT_HOURS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --timeout must be a positive integer, got: $TIMEOUT_HOURS"
    exit 1
fi
if ! [[ "$SUCCESS_THRESHOLD" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --success-threshold must be a positive integer, got: $SUCCESS_THRESHOLD"
    exit 1
fi

# Sanitize dataset name to prevent command injection
DATASET_NAME=$(echo "$DATASET_NAME" | tr -cd '[:alnum:]._-/')

# Set up logging
LOG_FILE="$OUTPUT_DIR/pipeline_monitor.log"
mkdir -p "$OUTPUT_DIR"

# ===========================================================================
# Phase 1: Monitor Workflow
# ===========================================================================
monitor_workflow() {
    log_info "=========================================="
    log_info "PHASE 1: Monitoring Workflow"
    log_info "=========================================="
    log_info "Workflow: $WORKFLOW"
    log_info "Poll interval: ${POLL_INTERVAL}s"
    log_info "Timeout: ${TIMEOUT_HOURS}h"

    local start_time=$(date +%s)
    local timeout_seconds=$((TIMEOUT_HOURS * 3600))
    local check_count=0

    while true; do
        check_count=$((check_count + 1))
        local elapsed=$(($(date +%s) - start_time))
        local elapsed_min=$((elapsed / 60))

        # Check timeout
        if [[ $elapsed -gt $timeout_seconds ]]; then
            log_error "Timeout reached after ${TIMEOUT_HOURS} hours"
            return 1
        fi

        # Get workflow status
        local status_output
        if ! status_output=$(export KUBECONFIG="$KUBECONFIG" && argo get "$WORKFLOW" -n "$NAMESPACE" 2>&1); then
            log_warn "Failed to get workflow status (attempt $check_count), retrying..."
            sleep "$POLL_INTERVAL"
            continue
        fi

        # Parse status
        local status=$(echo "$status_output" | grep "^Status:" | awk '{print $2}')
        local progress=$(echo "$status_output" | grep "^Progress:" | awk '{print $2}')

        log_info "Check #$check_count (${elapsed_min}m elapsed): Status=$status, Progress=$progress"

        case "$status" in
            Succeeded)
                log_success "Workflow completed successfully!"
                return 0
                ;;
            Failed|Error)
                log_error "Workflow failed with status: $status"
                return 1
                ;;
            Running|Pending)
                # Continue monitoring
                ;;
            *)
                log_warn "Unknown status: $status"
                ;;
        esac

        sleep "$POLL_INTERVAL"
    done
}

# ===========================================================================
# Phase 2: Validate Outputs
# ===========================================================================
validate_outputs() {
    log_info "=========================================="
    log_info "PHASE 2: Validating Outputs"
    log_info "=========================================="
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Expected traits: $EXPECTED_TRAITS"
    log_info "Success threshold: ${SUCCESS_THRESHOLD}%"

    # Count Filter files (definitive completion signal)
    local filter_count
    filter_count=$(find "$OUTPUT_DIR" -name "GAPIT.Association.Filter_GWAS_results.csv" 2>/dev/null | wc -l)

    log_info "Found $filter_count Filter files (complete traits)"

    # Calculate percentage (guard division by zero)
    if [[ "$EXPECTED_TRAITS" -eq 0 ]]; then
        log_error "EXPECTED_TRAITS is 0, cannot calculate completion percentage"
        return 1
    fi
    local percent=$((filter_count * 100 / EXPECTED_TRAITS))
    log_info "Completion: ${percent}% ($filter_count / $EXPECTED_TRAITS)"

    # Check threshold
    if [[ $percent -ge $SUCCESS_THRESHOLD ]]; then
        log_success "Validation PASSED: ${percent}% >= ${SUCCESS_THRESHOLD}% threshold"
        return 0
    else
        log_error "Validation FAILED: ${percent}% < ${SUCCESS_THRESHOLD}% threshold"
        log_info "Missing $((EXPECTED_TRAITS - filter_count)) traits"
        return 1
    fi
}

# ===========================================================================
# Phase 3: Run Aggregation
# ===========================================================================
run_aggregation() {
    log_info "=========================================="
    log_info "PHASE 3: Running Aggregation"
    log_info "=========================================="

    # Convert WSL path to cluster path
    local cluster_output_path="${OUTPUT_DIR/\/mnt\/hpi_dev/\/hpi\/hpi_dev}"
    log_info "Cluster output path: $cluster_output_path"
    log_info "Image: $IMAGE"
    log_info "Batch ID: $WORKFLOW"

    # Submit aggregation workflow
    local submit_output
    if ! submit_output=$(export KUBECONFIG="$KUBECONFIG" && argo submit \
        "$PROJECT_ROOT/cluster/argo/workflows/gapit3-aggregation-standalone.yaml" \
        -p "output-hostpath=$cluster_output_path" \
        -p "batch-id=$WORKFLOW" \
        -p "image=$IMAGE" \
        -n "$NAMESPACE" 2>&1); then
        log_error "Failed to submit aggregation workflow"
        log_error "$submit_output"
        return 1
    fi

    # Extract workflow name
    local agg_workflow
    agg_workflow=$(echo "$submit_output" | grep "Name:" | head -1 | awk '{print $2}')
    log_info "Aggregation workflow submitted: $agg_workflow"

    # Wait for aggregation to complete
    log_info "Waiting for aggregation to complete..."
    local agg_start=$(date +%s)
    local agg_timeout=3600  # 1 hour max for aggregation

    while true; do
        local elapsed=$(($(date +%s) - agg_start))

        if [[ $elapsed -gt $agg_timeout ]]; then
            log_error "Aggregation timeout after 1 hour"
            return 1
        fi

        local agg_status
        if ! agg_status=$(export KUBECONFIG="$KUBECONFIG" && argo get "$agg_workflow" -n "$NAMESPACE" 2>&1 | grep "^Status:" | awk '{print $2}'); then
            log_warn "Failed to get aggregation status, retrying..."
            sleep 30
            continue
        fi

        case "$agg_status" in
            Succeeded)
                log_success "Aggregation completed successfully!"
                return 0
                ;;
            Failed|Error)
                log_error "Aggregation failed with status: $agg_status"
                return 1
                ;;
            *)
                log_info "Aggregation status: $agg_status (${elapsed}s elapsed)"
                sleep 30
                ;;
        esac
    done
}

# ===========================================================================
# Phase 4: Upload to Box
# ===========================================================================
upload_to_box() {
    log_info "=========================================="
    log_info "PHASE 4: Uploading to Box"
    log_info "=========================================="
    log_info "Dataset: $DATASET_NAME"
    log_info "Destination: $BOX_DEST/$DATASET_NAME"

    # Use Z: drive path for rclone (Windows path)
    local windows_source="Z:\\users\\eberrigan\\$DATASET_NAME"
    local box_dest="box:$BOX_DEST/$DATASET_NAME"

    log_info "Source: $windows_source"
    log_info "Executing rclone via PowerShell..."

    # Call rclone via PowerShell from WSL
    local rclone_cmd="& '$RCLONE_PATH' copy --update -P '$windows_source' '$box_dest'"
    log_info "Command: powershell.exe -NoProfile -Command \"$rclone_cmd\""

    if ! powershell.exe -NoProfile -Command "$rclone_cmd" >> "$LOG_FILE" 2>&1; then
        log_error "Box upload failed"
        return 1
    fi

    log_success "Box upload completed!"
    return 0
}

# ===========================================================================
# Main Execution
# ===========================================================================
main() {
    log_info "=========================================="
    log_info "AUTONOMOUS PIPELINE MONITOR STARTED"
    log_info "=========================================="
    log_info "Start time: $(date)"
    log_info "Workflow: $WORKFLOW"
    log_info "Output dir: $OUTPUT_DIR"
    log_info "Expected traits: $EXPECTED_TRAITS"
    log_info "Dataset: $DATASET_NAME"
    log_info "Log file: $LOG_FILE"
    log_info ""

    local exit_code=0

    # Phase 1: Monitor
    if ! monitor_workflow; then
        log_error "Workflow monitoring failed - aborting"
        exit_code=1
    fi

    # Phase 2: Validate (even if monitoring failed, check what we have)
    if [[ $exit_code -eq 0 ]]; then
        if ! validate_outputs; then
            log_warn "Validation failed but continuing with aggregation..."
            # Don't fail here, try to aggregate what we have
        fi
    fi

    # Phase 3: Aggregate (if workflow succeeded)
    if [[ $exit_code -eq 0 ]]; then
        if ! run_aggregation; then
            log_error "Aggregation failed"
            exit_code=1
        fi
    fi

    # Phase 4: Upload (only if previous phases succeeded)
    if [[ $exit_code -eq 0 ]]; then
        if ! upload_to_box; then
            log_error "Box upload failed"
            exit_code=1
        fi
    else
        log_warn "Skipping Phase 4 (upload) due to earlier failures"
    fi

    # Final summary
    log_info ""
    log_info "=========================================="
    if [[ $exit_code -eq 0 ]]; then
        log_success "PIPELINE MONITOR COMPLETED SUCCESSFULLY"
    else
        log_error "PIPELINE MONITOR COMPLETED WITH ERRORS"
    fi
    log_info "End time: $(date)"
    log_info "Log file: $LOG_FILE"
    log_info "=========================================="

    exit $exit_code
}

# Run main
main
