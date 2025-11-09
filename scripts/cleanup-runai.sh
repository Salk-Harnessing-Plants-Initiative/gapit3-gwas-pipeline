#!/bin/bash
# ===========================================================================
# Cleanup RunAI GAPIT3 Resources
# ===========================================================================
# Deletes RunAI workspaces and/or output files for GAPIT3 GWAS pipeline
# Provides dry-run mode and interactive confirmation for safety
# ===========================================================================

set -uo pipefail

# Error handling
trap 'echo ""; echo -e "${RED}[ERROR]${NC} Script failed at line $LINENO. Exit code: $?"; exit 1' ERR

# Configuration
PROJECT="${PROJECT:-talmo-lab}"
OUTPUT_PATH="${OUTPUT_PATH:-/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs}"
DEFAULT_START_TRAIT=2
DEFAULT_END_TRAIT=187

# Parsed options
CLEANUP_ALL=false
START_TRAIT=$DEFAULT_START_TRAIT
END_TRAIT=$DEFAULT_END_TRAIT
WORKSPACES_ONLY=false
OUTPUTS_ONLY=false
DRY_RUN=false
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
${GREEN}GAPIT3 GWAS - RunAI Cleanup Helper${NC}

Delete RunAI workspaces and output files for GAPIT3 GWAS pipeline.

${BLUE}Usage:${NC}
  $0 [OPTIONS]

${BLUE}Options:${NC}
  --all                 Clean up all traits (2-187)
  --start-trait NUM     First trait to clean up (default: 2)
  --end-trait NUM       Last trait to clean up (default: 187)
  --workspaces-only     Only delete RunAI workspaces (keep output files)
  --outputs-only        Only delete output files (keep workspaces)
  --dry-run, -n         Preview what would be deleted without deleting
  --force, -f           Skip confirmation prompts
  --help, -h            Show this help message

${BLUE}Examples:${NC}
  # Preview what would be deleted (all traits)
  $0 --all --dry-run

  # Clean everything (with confirmation)
  $0 --all

  # Clean specific range
  $0 --start-trait 2 --end-trait 4

  # Only delete RunAI workspaces
  $0 --all --workspaces-only

  # Only delete output files
  $0 --all --outputs-only

  # Force deletion without confirmation (for automation)
  $0 --start-trait 42 --end-trait 42 --force

${BLUE}Environment Variables:${NC}
  PROJECT       RunAI project name (default: talmo-lab)
  OUTPUT_PATH   Output directory path

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
trap 'echo ""; log_warn "Interrupted by user"; exit 130' INT

# ===========================================================================
# Parse Arguments
# ===========================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEANUP_ALL=true
            shift
            ;;
        --start-trait)
            START_TRAIT="$2"
            shift 2
            ;;
        --end-trait)
            END_TRAIT="$2"
            shift 2
            ;;
        --workspaces-only)
            WORKSPACES_ONLY=true
            shift
            ;;
        --outputs-only)
            OUTPUTS_ONLY=true
            shift
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
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

# ===========================================================================
# Validate Arguments
# ===========================================================================

# Check mutually exclusive flags
if [ "$CLEANUP_ALL" = true ] && { [ "$START_TRAIT" != "$DEFAULT_START_TRAIT" ] || [ "$END_TRAIT" != "$DEFAULT_END_TRAIT" ]; }; then
    log_error "--all cannot be used with --start-trait or --end-trait"
    exit 1
fi

if [ "$WORKSPACES_ONLY" = true ] && [ "$OUTPUTS_ONLY" = true ]; then
    log_error "--workspaces-only and --outputs-only cannot both be specified"
    exit 1
fi

# Validate trait range
if [ "$START_TRAIT" -gt "$END_TRAIT" ]; then
    log_error "START_TRAIT ($START_TRAIT) must be <= END_TRAIT ($END_TRAIT)"
    exit 1
fi

if [ "$START_TRAIT" -lt 2 ] || [ "$END_TRAIT" -gt 187 ]; then
    log_error "Trait range must be between 2 and 187"
    exit 1
fi

# ===========================================================================
# Validate Prerequisites
# ===========================================================================

log_info "Validating prerequisites..."

# Check runai CLI (only if not outputs-only)
if [ "$OUTPUTS_ONLY" = false ]; then
    if ! command -v runai &> /dev/null; then
        log_error "runai CLI not found. Please install RunAI CLI."
        exit 1
    fi

    # Check authentication
    if ! runai whoami &> /dev/null 2>&1; then
        log_error "Not authenticated to RunAI. Run: runai login"
        exit 1
    fi
fi

# Check output directory (only if not workspaces-only)
if [ "$WORKSPACES_ONLY" = false ]; then
    if [ ! -d "$OUTPUT_PATH" ]; then
        log_warn "Output directory does not exist: $OUTPUT_PATH"
        if [ "$FORCE" = false ]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Cancelled"
                exit 0
            fi
        fi
    fi
fi

log_info "Prerequisites validated"

# ===========================================================================
# Discover Resources
# ===========================================================================

log_info "Discovering resources..."

# Count existing workspaces
EXISTING_WORKSPACES=0
if [ "$OUTPUTS_ONLY" = false ]; then
    for i in $(seq $START_TRAIT $END_TRAIT); do
        if runai workspace list -p $PROJECT 2>/dev/null | grep -qE "^[[:space:]]*gapit3-trait-$i[[:space:]]"; then
            EXISTING_WORKSPACES=$((EXISTING_WORKSPACES + 1))
        fi
    done
fi

# Count existing output directories
EXISTING_OUTPUTS=0
if [ "$WORKSPACES_ONLY" = false ] && [ -d "$OUTPUT_PATH" ]; then
    for i in $(seq $START_TRAIT $END_TRAIT); do
        if [ -d "$OUTPUT_PATH/trait_$i" ]; then
            EXISTING_OUTPUTS=$((EXISTING_OUTPUTS + 1))
        fi
    done
fi

# Check aggregated results
HAS_AGGREGATED=false
if [ "$WORKSPACES_ONLY" = false ] && [ -d "$OUTPUT_PATH/aggregated_results" ]; then
    HAS_AGGREGATED=true
fi

# ===========================================================================
# Display Summary and Confirm
# ===========================================================================

echo ""
echo -e "${GREEN}===========================================================================${NC}"
echo -e "${GREEN}Cleanup Summary${NC}"
echo -e "${GREEN}===========================================================================${NC}"
echo ""
echo "Trait range: $START_TRAIT to $END_TRAIT"
echo "Project:     $PROJECT"
echo "Output path: $OUTPUT_PATH"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}[DRY RUN MODE] - No changes will be made${NC}"
    echo ""
fi

echo -e "${YELLOW}Resources found:${NC}"
if [ "$OUTPUTS_ONLY" = false ]; then
    echo "  RunAI workspaces: $EXISTING_WORKSPACES"
fi
if [ "$WORKSPACES_ONLY" = false ]; then
    echo "  Output directories: $EXISTING_OUTPUTS"
    if [ "$HAS_AGGREGATED" = true ]; then
        echo "  Aggregated results: Yes"
    fi
fi
echo ""

if [ $EXISTING_WORKSPACES -eq 0 ] && [ $EXISTING_OUTPUTS -eq 0 ]; then
    log_info "No resources found to delete"
    exit 0
fi

# Confirmation
if [ "$DRY_RUN" = false ]; then
    echo -e "${RED}WARNING: This will permanently delete:${NC}"

    if [ "$OUTPUTS_ONLY" = false ] && [ $EXISTING_WORKSPACES -gt 0 ]; then
        echo "  - $EXISTING_WORKSPACES RunAI workspaces"
    fi

    if [ "$WORKSPACES_ONLY" = false ]; then
        if [ $EXISTING_OUTPUTS -gt 0 ]; then
            echo "  - $EXISTING_OUTPUTS trait output directories"
        fi
        if [ "$HAS_AGGREGATED" = true ]; then
            echo "  - Aggregated results directory"
        fi
    fi

    echo ""

    if [ "$FORCE" = false ]; then
        read -p "Type 'yes' to confirm deletion: " confirmation
        if [ "$confirmation" != "yes" ]; then
            log_info "Cancelled"
            exit 0
        fi
        echo ""
    fi
fi

# ===========================================================================
# Delete Workspaces
# ===========================================================================

DELETED_WORKSPACES=0
NOT_FOUND_WORKSPACES=0
FAILED_WORKSPACES=0

if [ "$OUTPUTS_ONLY" = false ] && [ $EXISTING_WORKSPACES -gt 0 ]; then
    if [ "$DRY_RUN" = false ]; then
        echo ""
        echo -e "${BLUE}Deleting RunAI workspaces...${NC}"
    fi

    # Disable error trap temporarily
    trap - ERR

    for i in $(seq $START_TRAIT $END_TRAIT); do
        JOB_NAME="gapit3-trait-$i"

        if [ "$DRY_RUN" = true ]; then
            if runai workspace list -p $PROJECT 2>/dev/null | grep -qE "^[[:space:]]*$JOB_NAME[[:space:]]"; then
                echo "  [DRY RUN] Would delete: $JOB_NAME"
            fi
        else
            # Try to delete
            if runai workspace delete $JOB_NAME -p $PROJECT >/dev/null 2>&1; then
                echo -e "  ${GREEN}[✓]${NC} Deleted $JOB_NAME"
                DELETED_WORKSPACES=$((DELETED_WORKSPACES + 1))
            else
                # Check if it existed
                if runai workspace list -p $PROJECT 2>/dev/null | grep -qE "^[[:space:]]*$JOB_NAME[[:space:]]"; then
                    echo -e "  ${RED}[✗]${NC} Failed to delete $JOB_NAME"
                    FAILED_WORKSPACES=$((FAILED_WORKSPACES + 1))
                else
                    NOT_FOUND_WORKSPACES=$((NOT_FOUND_WORKSPACES + 1))
                fi
            fi

            # Small delay to avoid API rate limits
            sleep 0.5
        fi
    done

    # Re-enable error trap
    trap 'echo ""; echo -e "${RED}[ERROR]${NC} Script failed at line $LINENO. Exit code: $?"; exit 1' ERR

    if [ "$DRY_RUN" = false ]; then
        echo ""
        echo "  Deleted:   $DELETED_WORKSPACES"
        echo "  Not found: $NOT_FOUND_WORKSPACES"
        if [ $FAILED_WORKSPACES -gt 0 ]; then
            echo -e "  ${RED}Failed:    $FAILED_WORKSPACES${NC}"
        fi
    fi
fi

# ===========================================================================
# Delete Output Files
# ===========================================================================

DELETED_OUTPUTS=0

if [ "$WORKSPACES_ONLY" = false ] && [ -d "$OUTPUT_PATH" ]; then
    if [ "$DRY_RUN" = false ]; then
        echo ""
        echo -e "${BLUE}Deleting output files...${NC}"
    fi

    for i in $(seq $START_TRAIT $END_TRAIT); do
        DIR="$OUTPUT_PATH/trait_$i"
        if [ -d "$DIR" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "  [DRY RUN] Would delete: $DIR"
            else
                rm -rf "$DIR"
                echo -e "  ${GREEN}[✓]${NC} Deleted $DIR"
                DELETED_OUTPUTS=$((DELETED_OUTPUTS + 1))
            fi
        fi
    done

    # Delete aggregated results
    if [ -d "$OUTPUT_PATH/aggregated_results" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY RUN] Would delete: $OUTPUT_PATH/aggregated_results"
        else
            rm -rf "$OUTPUT_PATH/aggregated_results"
            echo -e "  ${GREEN}[✓]${NC} Deleted $OUTPUT_PATH/aggregated_results"
        fi
    fi

    if [ "$DRY_RUN" = false ]; then
        echo ""
        echo "  Deleted $DELETED_OUTPUTS trait directories"
    fi
fi

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo -e "${GREEN}===========================================================================${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}Dry Run Complete${NC}"
else
    echo -e "${GREEN}Cleanup Complete${NC}"
fi
echo -e "${GREEN}===========================================================================${NC}"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo "Summary:"
    if [ "$OUTPUTS_ONLY" = false ]; then
        echo "  Workspaces deleted: $DELETED_WORKSPACES"
    fi
    if [ "$WORKSPACES_ONLY" = false ]; then
        echo "  Output dirs deleted: $DELETED_OUTPUTS"
    fi
    echo ""

    if [ $FAILED_WORKSPACES -gt 0 ]; then
        log_warn "$FAILED_WORKSPACES workspaces could not be deleted"
        echo ""
    fi

    echo "Next steps:"
    echo "  - Submit new jobs: ./scripts/submit-all-traits-runai.sh"
    echo "  - Or rerun failed traits with specific range"
    echo ""
fi

log_info "Done!"
