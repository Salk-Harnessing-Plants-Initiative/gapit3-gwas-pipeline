#!/bin/bash
# ===========================================================================
# Aggregate RunAI GAPIT3 Results
# ===========================================================================
# Monitors RunAI workspace completion and automatically aggregates GWAS results
# Waits for all gapit3-trait-* jobs to finish, then runs collect_results.R
# ===========================================================================

set -euo pipefail

# ===========================================================================
# Configuration and Defaults
# ===========================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
DEFAULT_PROJECT="talmo-lab"
DEFAULT_OUTPUT_DIR="/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs"
DEFAULT_START_TRAIT=2
DEFAULT_END_TRAIT=187
DEFAULT_CHECK_INTERVAL=30
DEFAULT_THRESHOLD="5e-8"

# Parse from environment or use defaults
PROJECT="${RUNAI_PROJECT:-$DEFAULT_PROJECT}"
OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"
START_TRAIT=$DEFAULT_START_TRAIT
END_TRAIT=$DEFAULT_END_TRAIT
CHECK_INTERVAL=$DEFAULT_CHECK_INTERVAL
THRESHOLD=$DEFAULT_THRESHOLD
BATCH_ID=""
CHECK_ONLY=false
FORCE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===========================================================================
# Functions
# ===========================================================================

show_help() {
    cat << EOF
${GREEN}GAPIT3 GWAS - RunAI Results Aggregation${NC}

Monitor RunAI job completion and automatically aggregate GWAS results.

${BLUE}Usage:${NC}
  $0 [OPTIONS]

${BLUE}Options:${NC}
  --output-dir DIR      Output directory containing trait results
                        Default: $DEFAULT_OUTPUT_DIR
  --batch-id ID         Batch identifier for tracking
                        Default: runai-TIMESTAMP
  --project NAME        RunAI project name
                        Default: $DEFAULT_PROJECT
  --start-trait NUM     First trait index to consider
                        Default: $DEFAULT_START_TRAIT
  --end-trait NUM       Last trait index to consider
                        Default: $DEFAULT_END_TRAIT
  --check-interval SEC  Polling interval in seconds
                        Default: $DEFAULT_CHECK_INTERVAL
  --threshold FLOAT     Significance threshold for SNPs
                        Default: $DEFAULT_THRESHOLD
  --check-only          Check status and exit, don't wait for completion
  --force               Skip waiting, run aggregation immediately
  --help                Show this help message

${BLUE}Examples:${NC}
  # Wait for all jobs, then aggregate
  $0

  # Custom output directory and batch ID
  $0 --output-dir /custom/path --batch-id "iron-traits-v2"

  # Only aggregate traits 2-50
  $0 --start-trait 2 --end-trait 50

  # Check status without waiting
  $0 --check-only

  # Force immediate aggregation
  $0 --force

${BLUE}Environment Variables:${NC}
  RUNAI_PROJECT    Override default project name
  OUTPUT_DIR       Override default output directory

EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Trap Ctrl+C gracefully
trap 'echo ""; log_warn "Interrupted. Jobs continue running in RunAI."; exit 130' INT

# ===========================================================================
# Parse Arguments
# ===========================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --batch-id)
            BATCH_ID="$2"
            shift 2
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --start-trait)
            START_TRAIT="$2"
            shift 2
            ;;
        --end-trait)
            END_TRAIT="$2"
            shift 2
            ;;
        --check-interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Set default batch ID if not provided
if [ -z "$BATCH_ID" ]; then
    BATCH_ID="runai-$(date +%Y%m%d%H%M%S)"
fi

# ===========================================================================
# Validate Prerequisites
# ===========================================================================

log_info "Validating prerequisites..."

# Check runai CLI
if ! command -v runai &> /dev/null; then
    log_error "runai CLI not found. Please install RunAI CLI."
    exit 1
fi

# Check authentication
if ! runai whoami &> /dev/null 2>&1; then
    log_error "Not authenticated to RunAI. Run: runai login"
    exit 1
fi

# Check output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    log_error "Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# Check collect_results.R exists
COLLECT_SCRIPT="$PROJECT_ROOT/scripts/collect_results.R"
if [ ! -f "$COLLECT_SCRIPT" ]; then
    log_error "collect_results.R not found at: $COLLECT_SCRIPT"
    exit 1
fi

log_info "Prerequisites validated"

# ===========================================================================
# Header
# ===========================================================================

echo ""
echo -e "${GREEN}===========================================================================${NC}"
echo -e "${GREEN}GAPIT3 GWAS - RunAI Results Aggregation${NC}"
echo -e "${GREEN}===========================================================================${NC}"
echo ""
echo "Configuration:"
echo "  Project:        $PROJECT"
echo "  Output dir:     $OUTPUT_DIR"
echo "  Batch ID:       $BATCH_ID"
echo "  Trait range:    $START_TRAIT to $END_TRAIT"
echo "  Check interval: ${CHECK_INTERVAL}s"
echo "  Threshold:      $THRESHOLD"
echo "  Check only:     $CHECK_ONLY"
echo "  Force:          $FORCE"
echo ""

# ===========================================================================
# Discover Jobs
# ===========================================================================

log_info "Discovering RunAI workspaces..."

# Query RunAI for all gapit3-trait-* jobs
WORKSPACE_LIST=$(runai workspace list -p "$PROJECT" 2>/dev/null | grep "gapit3-trait-" || true)

if [ -z "$WORKSPACE_LIST" ]; then
    log_warn "No gapit3-trait-* jobs found in project $PROJECT"
    echo "Did you submit jobs with ./scripts/submit-all-traits-runai.sh ?"
    exit 0
fi

# Filter by trait range and count by status
TOTAL=0
SUCCEEDED=0
FAILED=0
RUNNING=0
PENDING=0

while IFS= read -r line; do
    # Extract job name (first column)
    JOB_NAME=$(echo "$line" | awk '{print $1}')

    # Extract trait index from job name (gapit3-trait-XXX)
    if [[ $JOB_NAME =~ gapit3-trait-([0-9]+) ]]; then
        TRAIT_IDX="${BASH_REMATCH[1]}"

        # Check if trait is in range
        if [ "$TRAIT_IDX" -ge "$START_TRAIT" ] && [ "$TRAIT_IDX" -le "$END_TRAIT" ]; then
            TOTAL=$((TOTAL + 1))

            # Check status (varies by position, look for keywords)
            if echo "$line" | grep -qE "Succeeded|Completed"; then
                SUCCEEDED=$((SUCCEEDED + 1))
            elif echo "$line" | grep -qE "Failed|Error"; then
                FAILED=$((FAILED + 1))
            elif echo "$line" | grep -q "Running"; then
                RUNNING=$((RUNNING + 1))
            else
                PENDING=$((PENDING + 1))
            fi
        fi
    fi
done <<< "$WORKSPACE_LIST"

# Calculate expected total based on trait range
EXPECTED=$((END_TRAIT - START_TRAIT + 1))

log_info "Found $TOTAL jobs (expected: $EXPECTED)"
echo "  Succeeded:  $SUCCEEDED"
echo "  Running:    $RUNNING"
echo "  Failed:     $FAILED"
echo "  Pending:    $PENDING"
echo ""

# Check if we found the expected number of jobs
if [ $TOTAL -lt $EXPECTED ]; then
    log_warn "Found fewer jobs ($TOTAL) than expected ($EXPECTED)"
    log_warn "Some traits may not have been submitted"
fi

# ===========================================================================
# Check-Only Mode
# ===========================================================================

if [ "$CHECK_ONLY" = true ]; then
    COMPLETE=$((SUCCEEDED + FAILED))
    PERCENT=0
    if [ $EXPECTED -gt 0 ]; then
        PERCENT=$((COMPLETE * 100 / EXPECTED))
    fi

    echo "Progress: $COMPLETE / $EXPECTED complete ($PERCENT%)"
    echo ""

    if [ $COMPLETE -ge $EXPECTED ]; then
        log_info "All jobs complete! Run without --check-only to aggregate."
    else
        REMAINING=$((EXPECTED - COMPLETE))
        log_info "$REMAINING jobs still in progress"
    fi

    exit 0
fi

# ===========================================================================
# Monitoring Loop (unless --force)
# ===========================================================================

if [ "$FORCE" = false ]; then
    log_info "Monitoring job completion (Ctrl+C to exit)..."
    echo ""

    START_TIME=$(date +%s)

    while true; do
        # Re-query RunAI
        WORKSPACE_LIST=$(runai workspace list -p "$PROJECT" 2>/dev/null | grep "gapit3-trait-" || true)

        # Recount statuses
        SUCCEEDED=0
        FAILED=0
        RUNNING=0
        PENDING=0

        while IFS= read -r line; do
            JOB_NAME=$(echo "$line" | awk '{print $1}')

            if [[ $JOB_NAME =~ gapit3-trait-([0-9]+) ]]; then
                TRAIT_IDX="${BASH_REMATCH[1]}"

                if [ "$TRAIT_IDX" -ge "$START_TRAIT" ] && [ "$TRAIT_IDX" -le "$END_TRAIT" ]; then
                    if echo "$line" | grep -qE "Succeeded|Completed"; then
                        SUCCEEDED=$((SUCCEEDED + 1))
                    elif echo "$line" | grep -qE "Failed|Error"; then
                        FAILED=$((FAILED + 1))
                    elif echo "$line" | grep -q "Running"; then
                        RUNNING=$((RUNNING + 1))
                    else
                        PENDING=$((PENDING + 1))
                    fi
                fi
            fi
        done <<< "$WORKSPACE_LIST"

        # Calculate progress
        COMPLETE=$((SUCCEEDED + FAILED))
        PERCENT=0
        if [ $EXPECTED -gt 0 ]; then
            PERCENT=$((COMPLETE * 100 / EXPECTED))
        fi

        # Calculate elapsed time
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))
        ELAPSED_MIN=$((ELAPSED / 60))

        # Display progress
        echo -ne "\r\033[K"  # Clear line
        echo -ne "Progress: ${GREEN}$SUCCEEDED succeeded${NC}, "
        echo -ne "${BLUE}$RUNNING running${NC}, "
        echo -ne "${RED}$FAILED failed${NC}, "
        echo -ne "${YELLOW}$PENDING pending${NC} | "

        # Progress bar
        BAR_WIDTH=30
        FILLED=$((PERCENT * BAR_WIDTH / 100))
        EMPTY=$((BAR_WIDTH - FILLED))
        echo -ne "["
        printf "%${FILLED}s" | tr ' ' '='
        printf "%${EMPTY}s" | tr ' ' '-'
        echo -ne "] ${PERCENT}% ($COMPLETE/$EXPECTED) | ${ELAPSED_MIN}m elapsed"

        # Check if all complete
        if [ $COMPLETE -ge $EXPECTED ]; then
            echo ""  # New line after progress
            echo ""
            log_info "All jobs complete!"
            break
        fi

        # Wait before next check
        sleep "$CHECK_INTERVAL"
    done
else
    log_info "Skipping monitoring (--force mode)"
fi

# ===========================================================================
# Final Status
# ===========================================================================

echo ""
echo "Final Status:"
echo "  Succeeded:  $SUCCEEDED"
echo "  Failed:     $FAILED"
echo "  Total:      $((SUCCEEDED + FAILED)) / $EXPECTED"
echo ""

# ===========================================================================
# Warn on Many Failures
# ===========================================================================

if [ $FAILED -gt 10 ]; then
    log_warn "$FAILED traits failed. Results will be partial."
    read -p "Continue with aggregation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Aggregation cancelled"
        exit 1
    fi
fi

# ===========================================================================
# Run Aggregation
# ===========================================================================

log_info "Running aggregation..."
echo ""

# Run collect_results.R
if Rscript "$COLLECT_SCRIPT" \
    --output-dir "$OUTPUT_DIR" \
    --batch-id "$BATCH_ID" \
    --threshold "$THRESHOLD"; then

    echo ""
    log_info "Aggregation completed successfully!"
else
    echo ""
    log_error "Aggregation failed"
    echo "Possible causes:"
    echo "  - No successful traits found"
    echo "  - Output directory not writable"
    echo "  - R packages missing"
    echo ""
    echo "Check logs above for details"
    exit 1
fi

# ===========================================================================
# Summary Report
# ===========================================================================

echo ""
echo -e "${GREEN}===========================================================================${NC}"
echo -e "${GREEN}Aggregation Complete${NC}"
echo -e "${GREEN}===========================================================================${NC}"
echo ""
echo "Output directory: $OUTPUT_DIR/aggregated_results/"
echo "Batch ID: $BATCH_ID"
echo ""

# Show generated files
AGGREGATED_DIR="$OUTPUT_DIR/aggregated_results"
if [ -d "$AGGREGATED_DIR" ]; then
    echo "Generated files:"
    ls -lh "$AGGREGATED_DIR/" | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
    echo ""

    # Show summary statistics if available
    SUMMARY_STATS="$AGGREGATED_DIR/summary_stats.json"
    if [ -f "$SUMMARY_STATS" ] && command -v jq &> /dev/null; then
        echo "Summary statistics:"
        jq '.' "$SUMMARY_STATS" 2>/dev/null || cat "$SUMMARY_STATS"
        echo ""
    fi
fi

echo "View results:"
echo "  cd $AGGREGATED_DIR"
echo "  head summary_table.csv"
echo ""

log_info "All done!"
