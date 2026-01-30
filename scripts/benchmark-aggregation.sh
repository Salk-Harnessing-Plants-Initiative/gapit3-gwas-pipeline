#!/bin/bash
# Benchmark script to compare aggregation performance before/after fix

set -e

OUTPUT_DIR="${1:-/workspace/20251110_Elohim_Bello_iron_deficiency_GAPIT_GWAS/outputs}"
BATCH_ID="${2:-benchmark_$(date +%Y%m%d_%H%M%S)}"

echo "=========================================="
echo "Aggregation Performance Benchmark"
echo "=========================================="
echo "Output dir: $OUTPUT_DIR"
echo "Batch ID: $BATCH_ID"
echo ""

# Check if we have R
if ! command -v Rscript &> /dev/null; then
    echo "Error: Rscript not found"
    exit 1
fi

# Count total trait directories
total_traits=$(find "$OUTPUT_DIR" -maxdepth 1 -type d -name "trait_*" | wc -l)
echo "Total trait directories: $total_traits"

# Count how many have empty Filter files (no traits column)
empty_count=0
for trait_dir in "$OUTPUT_DIR"/trait_*/; do
    filter_file="$trait_dir/GAPIT.Association.Filter_GWAS_results.csv"
    if [ -f "$filter_file" ]; then
        # Check if file has 'traits' in header
        if ! head -n 1 "$filter_file" | grep -q "traits"; then
            ((empty_count++))
        fi
    fi
done
echo "Empty traits (no 'traits' column): $empty_count"
echo ""

# Run aggregation with timing
echo "Starting aggregation..."
echo "=========================================="
start_time=$(date +%s)

Rscript scripts/collect_results.R \
    --output-dir "$OUTPUT_DIR" \
    --batch-id "$BATCH_ID" \
    --threshold 5e-8 2>&1 | tee "/tmp/aggregation_${BATCH_ID}.log"

end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo ""
echo "=========================================="
echo "Performance Summary"
echo "=========================================="
echo "Total traits: $total_traits"
echo "Empty traits: $empty_count"
echo "Total time: ${elapsed}s"
echo ""

# Calculate per-trait averages
if [ $total_traits -gt 0 ]; then
    avg_per_trait=$(echo "scale=2; $elapsed / $total_traits" | bc)
    echo "Average per trait: ${avg_per_trait}s"
fi

# Check for fallback warnings
fallback_count=$(grep -c "using GWAS_Results fallback" "/tmp/aggregation_${BATCH_ID}.log" || true)
echo "Fallback warnings: $fallback_count"

if [ $fallback_count -eq 0 ] && [ $empty_count -gt 0 ]; then
    echo ""
    echo "✓ SUCCESS: No fallback warnings despite $empty_count empty traits!"
    echo "  The fix is working correctly."
elif [ $fallback_count -gt 0 ]; then
    echo ""
    echo "⚠ WARNING: Found $fallback_count fallback warnings"
    echo "  The fix may not be working as expected."
fi

echo ""
echo "Results saved to: $OUTPUT_DIR/aggregated_results_${BATCH_ID}/"
echo "Log saved to: /tmp/aggregation_${BATCH_ID}.log"
