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

# Configuration (Infrastructure)
PROJECT="talmo-lab"
IMAGE="ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test"
DATA_PATH="${DATA_PATH:-/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data}"
OUTPUT_PATH="${OUTPUT_PATH:-/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs}"
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
    if runai workspace list -p $PROJECT 2>/dev/null | grep -qE "^[[:space:]]*$JOB_NAME[[:space:]]"; then
        echo -e "${YELLOW}[SKIP]${NC} Trait $trait_idx - job already exists"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Check number of running jobs
    RUNNING=$(runai workspace list -p $PROJECT 2>/dev/null | grep -c "Running" || echo 0)

    # Wait if at max concurrency
    while [ $RUNNING -ge $MAX_CONCURRENT ]; do
        echo -e "${YELLOW}[WAIT]${NC} $RUNNING jobs running (max: $MAX_CONCURRENT). Waiting 30s..."
        sleep 30
        RUNNING=$(runai workspace list -p $PROJECT 2>/dev/null | grep -c "Running" || echo 0)
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
