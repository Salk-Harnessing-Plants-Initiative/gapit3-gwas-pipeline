#!/bin/bash
# ===========================================================================
# Monitor RunAI GAPIT3 Jobs
# ===========================================================================
# Monitors status of GAPIT3 GWAS jobs and provides summary statistics
# ===========================================================================

set -euo pipefail

PROJECT="${PROJECT:-talmo-lab}"
OUTPUT_PATH="${OUTPUT_PATH:-/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs}"
WATCH_MODE="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

get_job_stats() {
    local jobs_output=$(runai workspace list -p $PROJECT 2>/dev/null | grep "gapit3-trait-" || echo "")

    if [ -z "$jobs_output" ]; then
        echo "0 0 0 0 0"
        return
    fi

    local running=$(echo "$jobs_output" | grep -c "Running" || echo 0)
    local pending=$(echo "$jobs_output" | grep -c "Pending" || echo 0)
    local succeeded=$(echo "$jobs_output" | grep -cE "Succeeded|Completed" || echo 0)
    local failed=$(echo "$jobs_output" | grep -c "Failed" || echo 0)
    local total=$(echo "$jobs_output" | wc -l)

    echo "$running $pending $succeeded $failed $total"
}

get_output_stats() {
    if [ ! -d "$OUTPUT_PATH" ]; then
        echo "0 0"
        return
    fi

    local trait_dirs=$(ls -d "$OUTPUT_PATH"/trait_*/ 2>/dev/null | wc -l || echo 0)
    local result_files=$(find "$OUTPUT_PATH" -name "GAPIT.Association.GWAS_Results.csv" 2>/dev/null | wc -l || echo 0)

    echo "$trait_dirs $result_files"
}

show_status() {
    clear
    echo -e "${GREEN}===========================================================================${NC}"
    echo -e "${GREEN}GAPIT3 GWAS - RunAI Job Monitor${NC}"
    echo -e "${GREEN}===========================================================================${NC}"
    echo ""
    echo -e "${BLUE}Project:${NC} $PROJECT"
    echo -e "${BLUE}Time:${NC}    $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Job statistics
    read running pending succeeded failed total <<< $(get_job_stats)

    echo -e "${GREEN}Job Status:${NC}"
    echo "  Running:    $running"
    echo "  Pending:    $pending"
    echo "  Succeeded:  $succeeded"
    echo "  Failed:     $failed"
    echo "  ─────────────────"
    echo "  Total:      $total"
    echo ""

    # Progress bar
    if [ "${total:-0}" -gt 0 ]; then
        local complete=$((succeeded + failed))
        local percent=$((complete * 100 / 186))  # 186 total traits (2-187)
        local bar_length=50
        local filled=$((percent * bar_length / 100))
        local empty=$((bar_length - filled))

        echo -e "${GREEN}Progress:${NC}"
        printf "  ["
        printf "%${filled}s" | tr ' ' '='
        printf "%${empty}s" | tr ' ' '-'
        printf "] %3d%% (%d/186 complete)\n" $percent $complete
        echo ""
    fi

    # Output statistics
    read trait_dirs result_files <<< $(get_output_stats)

    echo -e "${GREEN}Output Files:${NC}"
    echo "  Trait directories: ${trait_dirs:-0}"
    echo "  Result CSV files:  ${result_files:-0}"
    echo ""

    # Recent failures
    if [ "${failed:-0}" -gt 0 ]; then
        echo -e "${RED}Recent Failures:${NC}"
        runai workspace list -p $PROJECT 2>/dev/null | grep "gapit3-trait-" | grep "Failed" | head -5 | while read line; do
            echo "  $line"
        done
        echo ""
    fi

    # Long-running jobs (over 2 hours)
    echo -e "${YELLOW}Long-Running Jobs (>2h):${NC}"
    local long_running=$(runai workspace list -p $PROJECT 2>/dev/null | grep "gapit3-trait-" | grep "Running" | awk '$4 ~ /[2-9]h|[0-9][0-9]h/ {print "  " $0}' 2>/dev/null || echo "  None")
    if [ -z "$long_running" ]; then
        echo "  None"
    else
        echo "$long_running"
    fi
    echo ""

    # Check if all jobs complete
    if [ $((succeeded + failed)) -ge 186 ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}All jobs complete!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Run aggregation with:"
        echo "  ${GREEN}./scripts/aggregate-runai-results.sh${NC}"
        echo ""
    fi

    # Commands
    echo -e "${BLUE}Commands:${NC}"
    echo "  View specific job:    runai describe job gapit3-trait-2 -p $PROJECT"
    echo "  View logs:            runai logs gapit3-trait-2 -p $PROJECT --follow"
    echo "  Aggregate results:    ./scripts/aggregate-runai-results.sh"
    echo ""
}

# Main loop
if [ "$WATCH_MODE" == "--watch" ] || [ "$WATCH_MODE" == "-w" ]; then
    echo -e "${GREEN}Starting continuous monitoring (Ctrl+C to exit)...${NC}"
    sleep 2

    while true; do
        show_status
        sleep 30
    done
else
    show_status
    echo "Tip: Use '$0 --watch' for continuous monitoring"
    echo ""
fi
