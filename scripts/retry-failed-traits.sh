#!/bin/bash
# ===========================================================================
# Retry Failed Traits - Automatically resubmit jobs that failed due to mount errors
# ===========================================================================
# Detects mount failures (exit code 2) and resubmits them with exponential backoff
# ===========================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
DRY_RUN=false
MAX_RETRIES=3
RETRY_DELAY_BASE=30

# ===========================================================================
# Argument Parsing
# ===========================================================================

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Retry jobs that failed due to mount failures.

OPTIONS:
  --dry-run              Show what would be retried without actually retrying
  --max-retries N        Maximum retry attempts per job (default: 3)
  --retry-delay N        Base delay in seconds for exponential backoff (default: 30)
                         Actual delays: N, N*2, N*4, ... between retries
  --help, -h             Show this help message

DESCRIPTION:
  This script:
    1. Finds failed jobs in RunAI matching your JOB_PREFIX
    2. Checks logs for mount failure indicators
    3. Deletes and resubmits jobs that failed due to mounts
    4. Skips configuration errors (not retryable)
    5. Uses exponential backoff between retries

  Configuration is loaded from .env file in project root.

EXIT CODES:
  0  Success (all retries completed or no failed jobs)
  1  Critical error (runai CLI not found, .env missing, etc.)
  2  Invalid arguments

EXAMPLES:
  # Dry-run to see what would be retried
  $0 --dry-run

  # Retry with default settings (3 retries, 30s base delay)
  $0

  # Retry with custom settings
  $0 --max-retries 5 --retry-delay 60

  # Quick retry with shorter delays (for testing)
  $0 --retry-delay 5
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --max-retries)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --max-retries requires a numeric argument"
                exit 2
            fi
            MAX_RETRIES="$2"
            if [[ "$MAX_RETRIES" -lt 1 ]] || [[ "$MAX_RETRIES" -gt 10 ]]; then
                echo "Error: --max-retries must be between 1 and 10"
                exit 2
            fi
            shift 2
            ;;
        --retry-delay)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --retry-delay requires a numeric argument"
                exit 2
            fi
            RETRY_DELAY_BASE="$2"
            if [[ "$RETRY_DELAY_BASE" -lt 1 ]] || [[ "$RETRY_DELAY_BASE" -gt 300 ]]; then
                echo "Error: --retry-delay must be between 1 and 300 seconds"
                exit 2
            fi
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 2
            ;;
    esac
done

# ===========================================================================
# Load Configuration
# ===========================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    echo "Loading configuration from .env..."
    set -a
    # shellcheck disable=SC1090
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r$//')
    set +a
fi

PROJECT="${PROJECT:-talmo-lab}"
JOB_PREFIX="${JOB_PREFIX:-gapit3-trait}"

# ===========================================================================
# Helper Functions
# ===========================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Calculate exponential backoff delay
# Usage: calculate_backoff <attempt_number>
# Returns delay in seconds: BASE * 2^(attempt-1)
calculate_backoff() {
    local attempt=$1
    local delay=$((RETRY_DELAY_BASE * (2 ** (attempt - 1))))
    # Cap at 5 minutes (300 seconds)
    if [[ $delay -gt 300 ]]; then
        delay=300
    fi
    echo $delay
}

# ===========================================================================
# Main Script
# ===========================================================================

echo -e "${GREEN}===========================================================================${NC}"
echo -e "${GREEN}Retry Failed Traits${NC}"
echo -e "${GREEN}===========================================================================${NC}"
echo ""
echo "Configuration:"
echo "  Project:          $PROJECT"
echo "  Job prefix:       $JOB_PREFIX"
echo "  Max retries:      $MAX_RETRIES"
echo "  Base delay:       ${RETRY_DELAY_BASE}s (exponential backoff)"
echo "  Dry run:          $DRY_RUN"
echo ""

# Statistics
RETRIED=0
SKIPPED=0
MOUNT_FAILURES=0
RESUBMIT_FAILED=0

# Get failed jobs
echo "Fetching failed jobs..."
FAILED_JOBS=$(runai workspace list -p "$PROJECT" 2>/dev/null | \
    grep "$JOB_PREFIX" | \
    grep -E "Failed" | \
    awk '{print $1}' || echo "")

if [ -z "$FAILED_JOBS" ]; then
    echo -e "${GREEN}No failed jobs found!${NC}"
    exit 0
fi

FAILED_COUNT=$(echo "$FAILED_JOBS" | wc -l | tr -d ' ')
echo -e "${YELLOW}Found $FAILED_COUNT failed job(s)${NC}"
echo ""

# Track retry attempts per trait (in-memory for this run)
declare -A RETRY_COUNTS

# Process each failed job
for job_name in $FAILED_JOBS; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Analyzing: $job_name${NC}"

    # Extract trait index for tracking
    TRAIT_IDX=$(echo "$job_name" | sed "s/^${JOB_PREFIX}-//")

    # Check retry count for this trait
    CURRENT_RETRIES=${RETRY_COUNTS[$TRAIT_IDX]:-0}
    if [[ $CURRENT_RETRIES -ge $MAX_RETRIES ]]; then
        log_warn "Trait $TRAIT_IDX has reached max retries ($MAX_RETRIES), skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Get logs
    JOB_LOGS=$(runai workspace logs "$job_name" -p "$PROJECT" 2>/dev/null || echo "")

    # Check for mount failure
    if echo "$JOB_LOGS" | grep -qi "INFRASTRUCTURE MOUNT FAILURE\|mount.*not.*mount point"; then
        MOUNT_FAILURES=$((MOUNT_FAILURES + 1))
        log_info "Mount failure detected"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${BLUE}  → [DRY-RUN] Would retry this job (attempt $((CURRENT_RETRIES + 1))/$MAX_RETRIES)${NC}"
            RETRIED=$((RETRIED + 1))
        else
            # Increment retry count
            RETRY_COUNTS[$TRAIT_IDX]=$((CURRENT_RETRIES + 1))
            ATTEMPT=${RETRY_COUNTS[$TRAIT_IDX]}

            log_info "Deleting failed job..."
            if runai workspace delete "$job_name" -p "$PROJECT" 2>/dev/null; then
                echo "     Deleted successfully"
            else
                log_error "Failed to delete, skipping"
                SKIPPED=$((SKIPPED + 1))
                continue
            fi

            # Wait for cleanup
            sleep 3

            log_info "Resubmitting trait $TRAIT_IDX (attempt $ATTEMPT/$MAX_RETRIES)..."

            # Resubmit by calling submission script with specific trait
            RESUBMIT_EXIT_CODE=0
            (
                cd "$PROJECT_ROOT"
                export START_TRAIT="$TRAIT_IDX"
                export END_TRAIT="$TRAIT_IDX"
                bash "$SCRIPT_DIR/submit-all-traits-runai.sh" <<< "y" 2>&1 | tail -5
            ) || RESUBMIT_EXIT_CODE=$?

            if [ $RESUBMIT_EXIT_CODE -eq 0 ]; then
                echo -e "${GREEN}     Resubmitted successfully${NC}"
                RETRIED=$((RETRIED + 1))
            else
                log_error "Resubmission failed"
                RESUBMIT_FAILED=$((RESUBMIT_FAILED + 1))
            fi

            # Exponential backoff before next retry
            BACKOFF_DELAY=$(calculate_backoff "$ATTEMPT")
            if [[ "$ATTEMPT" -lt "$MAX_RETRIES" ]] && [[ $BACKOFF_DELAY -gt 5 ]]; then
                log_info "Waiting ${BACKOFF_DELAY}s before next operation (exponential backoff)..."
                sleep "$BACKOFF_DELAY"
            else
                # Brief delay before next job
                sleep 2
            fi
        fi
    else
        log_warn "Not a mount failure (different error)"
        if [ -n "$JOB_LOGS" ]; then
            echo "     First few log lines:"
            echo "$JOB_LOGS" | head -3 | sed 's/^/       /'
        else
            echo "     (No logs available)"
        fi
        echo -e "${BLUE}  → Skipping (manual investigation needed)${NC}"
        SKIPPED=$((SKIPPED + 1))
    fi
done

echo ""
echo -e "${GREEN}===========================================================================${NC}"
echo -e "${GREEN}Retry Summary${NC}"
echo -e "${GREEN}===========================================================================${NC}"
echo ""
echo "Statistics:"
echo "  Failed jobs found:      $FAILED_COUNT"
echo "  Mount failures:         $MOUNT_FAILURES"
echo "  Retried:                $RETRIED"
echo "  Resubmission failures:  $RESUBMIT_FAILED"
echo "  Skipped:                $SKIPPED"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BLUE}This was a dry-run. To actually retry, run:${NC}"
    echo "  $0"
    echo ""
else
    echo -e "${GREEN}Retry process complete!${NC}"
    echo ""
    echo "Monitor retried jobs:"
    echo "  ./scripts/monitor-runai-jobs.sh --watch"
    echo ""
fi
