#!/bin/bash
# ==============================================================================
# Bulk Resubmit Traits Script
# ==============================================================================
# Deletes and resubmits multiple trait jobs in batch
# Usage: bash scripts/bulk-resubmit-traits.sh <trait1> <trait2> ...
# ==============================================================================

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration from .env
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo "Error: .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

# Validate required environment variables
if [ -z "${PROJECT:-}" ]; then
    echo "Error: PROJECT not set in .env"
    exit 1
fi

if [ -z "${JOB_PREFIX:-}" ]; then
    echo "Error: JOB_PREFIX not set in .env"
    exit 1
fi

# ==============================================================================
# Parse Arguments
# ==============================================================================

DRY_RUN=false
TRAITS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            TRAITS+=("$1")
            shift
            ;;
    esac
done

# ==============================================================================
# Input Validation
# ==============================================================================

if [ ${#TRAITS[@]} -eq 0 ]; then
    echo "Usage: $0 [--dry-run] <trait1> <trait2> <trait3> ..."
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would be resubmitted without actually doing it"
    echo ""
    echo "Example:"
    echo "  $0 --dry-run 37 50 61 66 70 76"
    echo "  $0 37 50 61 66 70 76"
    echo ""
    echo "Or get failed traits from runai:"
    echo "  failed_traits=\$(runai workspace list -p talmo-lab | grep \"$JOB_PREFIX\" | grep Failed | awk '{print \$1}' | sed 's/${JOB_PREFIX}-//')"
    echo "  $0 \$failed_traits"
    exit 1
fi

# ==============================================================================
# Confirmation
# ==============================================================================

echo "===================================================================="
if [ "$DRY_RUN" = true ]; then
    echo "Bulk Resubmit Traits (DRY RUN)"
else
    echo "Bulk Resubmit Traits"
fi
echo "===================================================================="
echo ""
echo "Configuration:"
echo "  Project:     $PROJECT"
echo "  Job Prefix:  $JOB_PREFIX"
echo "  Traits:      ${TRAITS[*]}"
echo "  Count:       ${#TRAITS[@]} trait(s)"
if [ "$DRY_RUN" = true ]; then
    echo "  Mode:        DRY RUN (no changes will be made)"
fi
echo ""
if [ "$DRY_RUN" = true ]; then
    echo "This would:"
else
    echo "This will:"
fi
echo "  1. Delete each failed job (if it exists)"
echo "  2. Resubmit each trait using submit-all-traits-runai.sh"
echo "  3. Wait 2 seconds between submissions"
echo ""

if [ "$DRY_RUN" = false ]; then
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 1
    fi
fi

# ==============================================================================
# Resubmit Loop
# ==============================================================================

SUCCESS_COUNT=0
FAIL_COUNT=0

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN - Showing what would be done..."
else
    echo "Starting resubmission..."
fi
echo ""

for trait in "${TRAITS[@]}"; do
    job_name="${JOB_PREFIX}-${trait}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Processing trait: $trait"

    if [ "$DRY_RUN" = true ]; then
        # Dry run - just show what would be done
        echo "[DRY-RUN] Would delete: $job_name"
        echo "[DRY-RUN] Would resubmit trait $trait"
        ((SUCCESS_COUNT++))
    else
        # Actual execution
        # Delete existing job (ignore errors if already deleted)
        echo "[DELETE] $job_name"
        if runai workspace delete "$job_name" -p "$PROJECT" 2>/dev/null; then
            echo "  → Deleted successfully"
        else
            echo "  → Already deleted or not found (continuing)"
        fi

        # Resubmit trait
        echo "[SUBMIT] Trait $trait"
        if (
            export START_TRAIT=$trait
            export END_TRAIT=$trait
            bash "$SCRIPT_DIR/submit-all-traits-runai.sh" <<< "y"
        ); then
            echo "  → Submitted successfully"
            ((SUCCESS_COUNT++))
        else
            echo "  → Submission failed"
            ((FAIL_COUNT++))
        fi

        # Wait before next submission
        if [ "${trait}" != "${TRAITS[-1]}" ]; then
            echo "  → Waiting 2 seconds..."
            sleep 2
        fi
    fi

    echo ""
done

# ==============================================================================
# Summary
# ==============================================================================

echo "===================================================================="
if [ "$DRY_RUN" = true ]; then
    echo "Dry Run Summary"
else
    echo "Resubmission Summary"
fi
echo "===================================================================="
echo ""
echo "Total traits:       ${#TRAITS[@]}"
if [ "$DRY_RUN" = true ]; then
    echo "Would resubmit:     $SUCCESS_COUNT"
else
    echo "Successfully submitted: $SUCCESS_COUNT"
    echo "Failed submissions: $FAIL_COUNT"
fi
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "This was a dry run. To actually resubmit, run without --dry-run flag."
    exit 0
elif [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ All traits resubmitted successfully!"
    exit 0
else
    echo "⚠ Some traits failed to resubmit. Check errors above."
    exit 1
fi
