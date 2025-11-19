#!/bin/bash
# ===========================================================================
# Submit All Traits to RunAI
# ===========================================================================
# Submits GAPIT3 GWAS analysis for all traits (2-187) using RunAI CLI
# Implements concurrency control to avoid overwhelming the cluster
# ===========================================================================

set -uo pipefail

# Error handling
trap 'echo ""; echo -e "${RED}[ERROR]${NC} Script failed at line $LINENO. Exit code: $?"; exit 1' ERR

# Parse command line arguments
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Submit GAPIT3 GWAS analysis jobs for all traits to RunAI cluster."
            echo ""
            echo "OPTIONS:"
            echo "  --dry-run    Validate configuration and show submission plan without submitting"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "Configuration is loaded from .env file in project root."
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 2
            ;;
    esac
done

# Load configuration from .env file if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Save any pre-existing environment variable overrides
# These take precedence over values from .env
SAVED_START_TRAIT="${START_TRAIT:-}"
SAVED_END_TRAIT="${END_TRAIT:-}"

if [ -f "$ENV_FILE" ]; then
    echo "Loading configuration from .env file..."
    # Export variables from .env (ignore comments and empty lines)
    set -a
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r$//')
    set +a
fi

# Restore environment variable overrides (they take precedence over .env)
if [ -n "$SAVED_START_TRAIT" ]; then
    START_TRAIT="$SAVED_START_TRAIT"
    echo "  → Using START_TRAIT override: $START_TRAIT"
fi
if [ -n "$SAVED_END_TRAIT" ]; then
    END_TRAIT="$SAVED_END_TRAIT"
    echo "  → Using END_TRAIT override: $END_TRAIT"
fi

# Configuration (Infrastructure) - .env values or fallback defaults
PROJECT="${PROJECT:-talmo-lab}"
IMAGE="${IMAGE:-ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest}"
DATA_PATH="${DATA_PATH_HOST:-${DATA_PATH:-/data}}"
OUTPUT_PATH="${OUTPUT_PATH_HOST:-${OUTPUT_PATH:-/outputs}}"
JOB_PREFIX="${JOB_PREFIX:-gapit3-trait}"
START_TRAIT="${START_TRAIT:-2}"
END_TRAIT="${END_TRAIT:-187}"
MAX_CONCURRENT="${MAX_CONCURRENT:-50}"
CPU="${CPU:-12}"
MEMORY="${MEMORY:-32G}"

# Configuration (GAPIT Runtime Parameters - passed as environment variables to container)
MODELS="${MODELS:-BLINK,FarmCPU}"
PCA_COMPONENTS="${PCA_COMPONENTS:-3}"
SNP_THRESHOLD="${SNP_THRESHOLD:-5e-8}"
MAF_FILTER="${MAF_FILTER:-0.05}"
MULTIPLE_ANALYSIS="${MULTIPLE_ANALYSIS:-TRUE}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===========================================================================${NC}"
echo -e "${GREEN}GAPIT3 GWAS - RunAI Batch Submission${NC}"
echo -e "${GREEN}===========================================================================${NC}"
echo ""
echo "Configuration:"
echo "  Project:           $PROJECT"
echo "  Image:             $IMAGE"
echo "  Job prefix:        $JOB_PREFIX"
echo "  Traits:            $START_TRAIT to $END_TRAIT ($(($END_TRAIT - $START_TRAIT + 1)) total)"
echo "  Max concurrent:    $MAX_CONCURRENT"
echo "  Resources:         $CPU CPU, $MEMORY memory"
echo ""
echo "GAPIT Parameters (passed as ENV to container):"
echo "  Models:            $MODELS"
echo "  PCA Components:    $PCA_COMPONENTS"
echo "  SNP Threshold:     $SNP_THRESHOLD"
echo "  MAF Filter:        $MAF_FILTER"
echo "  Multiple Analysis: $MULTIPLE_ANALYSIS"
echo ""
echo "Paths:"
echo "  Data path:         $DATA_PATH"
echo "  Output path:       $OUTPUT_PATH"
echo ""

# DRY-RUN MODE
if [[ "$DRY_RUN" == "true" ]]; then
    echo "==========================================================================="
    echo "DRY-RUN MODE: No jobs will be submitted"
    echo "==========================================================================="
    echo ""

    # Run validation
    echo "Running configuration validation..."
    echo ""

    VALIDATION_SCRIPT="$SCRIPT_DIR/validate-env.sh"
    if [[ -f "$VALIDATION_SCRIPT" ]]; then
        if bash "$VALIDATION_SCRIPT" --env-file "$ENV_FILE"; then
            echo ""
        else
            echo ""
            echo -e "${RED}[ERROR]${NC} Configuration validation failed"
            echo "Please fix the errors above before submitting."
            exit 1
        fi
    else
        echo -e "${YELLOW}[WARNING]${NC} Validation script not found: $VALIDATION_SCRIPT"
        echo "Skipping validation checks..."
        echo ""
    fi

    # Show submission plan
    echo "==========================================================================="
    echo "Job Submission Plan"
    echo "==========================================================================="
    echo ""

    TOTAL_JOBS=$((END_TRAIT - START_TRAIT + 1))
    PEAK_CPU=$((CPU * MAX_CONCURRENT))
    PEAK_MEMORY_NUM=${MEMORY%G}
    PEAK_MEMORY=$((PEAK_MEMORY_NUM * MAX_CONCURRENT))

    echo "Jobs to submit:    $TOTAL_JOBS"
    echo "Job name range:    $JOB_PREFIX-$START_TRAIT to $JOB_PREFIX-$END_TRAIT"
    echo "Max concurrent:    $MAX_CONCURRENT jobs"
    echo ""
    echo "Resources per job: $CPU CPU cores, $MEMORY memory"
    echo "Peak resources:    $PEAK_CPU CPU cores, ~${PEAK_MEMORY}G memory"
    echo ""

    # Show first 5 jobs as examples
    echo "First 5 jobs:"
    for i in $(seq $START_TRAIT $((START_TRAIT + 4))); do
        [[ $i -gt $END_TRAIT ]] && break
        echo "  - $JOB_PREFIX-$i (Trait index: $i)"
    done
    if [[ $TOTAL_JOBS -gt 5 ]]; then
        echo "  ... ($((TOTAL_JOBS - 5)) more jobs)"
    fi
    echo ""

    echo "==========================================================================="
    echo -e "${GREEN}Configuration validated successfully${NC}"
    echo "==========================================================================="
    echo ""
    echo "To submit these jobs, run:"
    echo "  $0"
    echo ""
    exit 0
fi

# Confirmation
read -p "Submit all jobs? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Track statistics
SUBMITTED=0
SKIPPED=0
FAILED=0

echo ""
echo -e "${GREEN}Starting job submission...${NC}"
echo ""

for trait_idx in $(seq $START_TRAIT $END_TRAIT); do
    JOB_NAME="$JOB_PREFIX-$trait_idx"

    # Check if job already exists
    # shellcheck disable=SC1087  # False positive: [[:space:]] is a grep regex, not bash array
    if runai workspace list -p $PROJECT 2>/dev/null | grep -qE "^[[:space:]]*$JOB_NAME[[:space:]]"; then
        echo -e "${YELLOW}[SKIP]${NC} Trait $trait_idx - job already exists"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Check number of active jobs in this batch
    # Count jobs matching our prefix that are not in terminal states (Succeeded/Failed/Completed)
    # This ensures we only count OUR jobs, not other users' jobs in the shared project
    # shellcheck disable=SC1087  # False positive: [[:space:]] is a grep regex, not bash array
    ACTIVE=$(runai workspace list -p $PROJECT 2>/dev/null | \
        grep "^[[:space:]]*$JOB_PREFIX-" | \
        grep -vE "Succeeded|Failed|Completed" | \
        wc -l || echo 0)

    # Wait if at max concurrency
    while [ $ACTIVE -ge $MAX_CONCURRENT ]; do
        echo -e "${YELLOW}[WAIT]${NC} $ACTIVE active jobs in batch (max: $MAX_CONCURRENT). Waiting 30s..."
        sleep 30
        # shellcheck disable=SC1087  # False positive: [[:space:]] is a grep regex, not bash array
        ACTIVE=$(runai workspace list -p $PROJECT 2>/dev/null | \
            grep "^[[:space:]]*$JOB_PREFIX-" | \
            grep -vE "Succeeded|Failed|Completed" | \
            wc -l || echo 0)
    done

    # Submit job
    echo -e "${GREEN}[SUBMIT]${NC} Trait $trait_idx (job: $JOB_NAME)"

    # Capture output for debugging (disable error trap temporarily)
    trap - ERR
    set +e
    SUBMIT_OUTPUT=$(runai workspace submit $JOB_NAME \
        --project $PROJECT \
        --image $IMAGE \
        --cpu-core-request $CPU \
        --cpu-memory-request $MEMORY \
        --host-path path=$DATA_PATH,mount=/data,mount-propagation=HostToContainer \
        --host-path path=$OUTPUT_PATH,mount=/outputs,mount-propagation=HostToContainer,readwrite \
        --environment TRAIT_INDEX=$trait_idx \
        --environment DATA_PATH=/data \
        --environment OUTPUT_PATH=/outputs \
        --environment GENOTYPE_FILE=${GENOTYPE_FILE} \
        --environment PHENOTYPE_FILE=${PHENOTYPE_FILE} \
        --environment ACCESSION_IDS_FILE=${ACCESSION_IDS_FILE:-} \
        --environment MODELS=$MODELS \
        --environment PCA_COMPONENTS=$PCA_COMPONENTS \
        --environment SNP_THRESHOLD=$SNP_THRESHOLD \
        --environment MAF_FILTER=$MAF_FILTER \
        --environment MULTIPLE_ANALYSIS=$MULTIPLE_ANALYSIS \
        --environment OPENBLAS_NUM_THREADS=$CPU \
        --environment OMP_NUM_THREADS=$CPU \
        --command -- /scripts/entrypoint.sh run-single-trait 2>&1)
    SUBMIT_EXIT=$?
    set -e
    trap 'echo ""; echo -e "${RED}[ERROR]${NC} Script failed at line $LINENO. Exit code: $?"; exit 1' ERR

    if [ $SUBMIT_EXIT -eq 0 ]; then
        SUBMITTED=$((SUBMITTED + 1))
        echo "  → Success"
    else
        echo -e "${RED}[FAILED]${NC} Trait $trait_idx - submission failed (exit code: $SUBMIT_EXIT)"
        echo "Error output:"
        echo "$SUBMIT_OUTPUT"
        FAILED=$((FAILED + 1))
    fi

    # Small delay to avoid API rate limits
    sleep 2
done

echo ""
echo -e "${GREEN}===========================================================================${NC}"
echo -e "${GREEN}Submission Complete${NC}"
echo -e "${GREEN}===========================================================================${NC}"
echo ""
echo "Statistics:"
echo "  Submitted:  $SUBMITTED"
echo "  Skipped:    $SKIPPED (already exists)"
echo "  Failed:     $FAILED"
echo "  Total:      $(($END_TRAIT - $START_TRAIT + 1))"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Warning: $FAILED jobs failed to submit${NC}"
    echo ""
fi

echo -e "${GREEN}Next steps:${NC}"
echo ""
echo "1. Monitor progress:"
echo "   ./scripts/monitor-runai-jobs.sh --watch"
echo ""
echo "2. Aggregate results when complete:"
echo "   ./scripts/aggregate-runai-results.sh"
echo ""
echo "Other useful commands:"
echo "  - List all jobs:        runai workspace list | grep gapit3-trait"
echo "  - View specific logs:   runai workspace logs gapit3-trait-2 --follow"
echo "  - Check output files:   ls -lh $OUTPUT_PATH/"
echo ""

# Exit successfully
exit 0
