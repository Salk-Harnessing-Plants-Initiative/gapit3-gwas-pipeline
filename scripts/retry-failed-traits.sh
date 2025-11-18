#!/bin/bash
# ===========================================================================
# Retry Failed Traits - Automatically resubmit jobs that failed due to mount errors
# ===========================================================================
# Detects mount failures (exit code 2) and resubmits them
# ===========================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
DRY_RUN=false
MAX_RETRIES=3

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            cat << EOF
Usage: $0 [OPTIONS]

Retry jobs that failed due to mount failures.

OPTIONS:
  --dry-run    Show what would be retried without actually retrying
  --help, -h   Show this help message

This script:
  1. Finds failed jobs in RunAI
  2. Checks logs for mount failure indicators
  3. Deletes and resubmits jobs that failed due to mounts
  4. Skips configuration errors (not retryable)

Configuration is loaded from .env file in project root.
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    echo "Loading configuration from .env..."
    set -a
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r$//')
    set +a
fi

PROJECT="${PROJECT:-talmo-lab}"
JOB_PREFIX="${JOB_PREFIX:-gapit3-trait}"

echo -e "${GREEN}===========================================================================${NC}"
echo -e "${GREEN}Retry Failed Traits${NC}"
echo -e "${GREEN}===========================================================================${NC}"
echo ""
echo "Project:     $PROJECT"
echo "Job prefix:  $JOB_PREFIX"
echo "Dry run:     $DRY_RUN"
echo ""

# Statistics
RETRIED=0
SKIPPED=0
MOUNT_FAILURES=0

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

FAILED_COUNT=$(echo "$FAILED_JOBS" | wc -l)
echo -e "${YELLOW}Found $FAILED_COUNT failed job(s)${NC}"
echo ""

# Process each failed job
for job_name in $FAILED_JOBS; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Analyzing: $job_name${NC}"

    # Get logs
    JOB_LOGS=$(runai workspace logs "$job_name" -p "$PROJECT" 2>/dev/null || echo "")

    # Check for mount failure
    if echo "$JOB_LOGS" | grep -qi "INFRASTRUCTURE MOUNT FAILURE\|mount.*not.*mount point"; then
        MOUNT_FAILURES=$((MOUNT_FAILURES + 1))
        echo -e "${YELLOW}  → Mount failure detected${NC}"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${BLUE}  → [DRY-RUN] Would retry this job${NC}"
            RETRIED=$((RETRIED + 1))
        else
            # Extract trait index
            TRAIT_IDX=$(echo "$job_name" | sed "s/^${JOB_PREFIX}-//")

            echo -e "${GREEN}  → Deleting failed job...${NC}"
            if runai workspace delete "$job_name" -p "$PROJECT" 2>/dev/null; then
                echo "     Deleted successfully"
            else
                echo -e "${RED}     Failed to delete, skipping${NC}"
                SKIPPED=$((SKIPPED + 1))
                continue
            fi

            # Wait for cleanup
            sleep 3

            echo -e "${GREEN}  → Resubmitting trait $TRAIT_IDX...${NC}"

            # Resubmit by calling submission script with specific trait
            (
                cd "$PROJECT_ROOT"
                export START_TRAIT="$TRAIT_IDX"
                export END_TRAIT="$TRAIT_IDX"
                bash "$SCRIPT_DIR/submit-all-traits-runai.sh" <<< "y" 2>&1 | tail -5
            )

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}     Resubmitted successfully${NC}"
                RETRIED=$((RETRIED + 1))
            else
                echo -e "${RED}     Resubmission failed${NC}"
                SKIPPED=$((SKIPPED + 1))
            fi

            # Brief delay before next
            sleep 2
        fi
    else
        echo -e "${YELLOW}  → Not a mount failure (different error)${NC}"
        echo "     First few log lines:"
        echo "$JOB_LOGS" | head -3 | sed 's/^/       /'
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
echo "  Failed jobs found:    $FAILED_COUNT"
echo "  Mount failures:       $MOUNT_FAILURES"
echo "  Retried:              $RETRIED"
echo "  Skipped:              $SKIPPED"
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
