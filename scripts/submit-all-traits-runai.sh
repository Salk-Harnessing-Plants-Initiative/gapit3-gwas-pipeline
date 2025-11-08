#!/bin/bash
# ===========================================================================
# Submit All Traits to RunAI
# ===========================================================================
# Submits GAPIT3 GWAS analysis for all traits (2-187) using RunAI CLI
# Implements concurrency control to avoid overwhelming the cluster
# ===========================================================================

set -euo pipefail

# Configuration
PROJECT="talmo-lab"
IMAGE="ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test"
DATA_PATH="/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data"
OUTPUT_PATH="/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs"
START_TRAIT="${START_TRAIT:-2}"
END_TRAIT="${END_TRAIT:-187}"
MAX_CONCURRENT="${MAX_CONCURRENT:-50}"
CPU="${CPU:-12}"
MEMORY="${MEMORY:-32G}"
MODELS="${MODELS:-BLINK,FarmCPU}"

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
echo "  Traits:            $START_TRAIT to $END_TRAIT ($(($END_TRAIT - $START_TRAIT + 1)) total)"
echo "  Max concurrent:    $MAX_CONCURRENT"
echo "  Resources:         $CPU CPU, $MEMORY memory"
echo "  Models:            $MODELS"
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
    JOB_NAME="gapit3-trait-$trait_idx"

    # Check if job already exists
    if runai workspace list -p $PROJECT 2>/dev/null | awk '{print $1}' | grep -q "^$JOB_NAME$"; then
        echo -e "${YELLOW}[SKIP]${NC} Trait $trait_idx - job already exists"
        ((SKIPPED++))
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

    if runai workspace submit $JOB_NAME \
        --project $PROJECT \
        --image $IMAGE \
        --cpu-core-request $CPU \
        --cpu-memory-request $MEMORY \
        --host-path path=$DATA_PATH,mount=/data,mount-propagation=HostToContainer \
        --host-path path=$OUTPUT_PATH,mount=/outputs,mount-propagation=HostToContainer,readwrite \
        --environment OPENBLAS_NUM_THREADS=$CPU \
        --environment OMP_NUM_THREADS=$CPU \
        --environment TRAIT_INDEX=$trait_idx \
        --command -- /scripts/entrypoint.sh run-single-trait \
          --trait-index $trait_idx \
          --config /config/config.yaml \
          --output-dir /outputs \
          --models $MODELS \
          --threads $CPU \
        > /dev/null 2>&1; then
        ((SUBMITTED++))
    else
        echo -e "${RED}[FAILED]${NC} Trait $trait_idx - submission failed"
        ((FAILED++))
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
