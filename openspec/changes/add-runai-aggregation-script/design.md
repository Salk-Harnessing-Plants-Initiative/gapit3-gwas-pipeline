# Design: RunAI Aggregation Script

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  User Workflow                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Submit all traits                                           │
│     $ ./scripts/submit-all-traits-runai.sh                      │
│                                                                 │
│  2. Start aggregation monitor                                   │
│     $ ./scripts/aggregate-runai-results.sh                      │
│                                                                 │
│  3. Script monitors RunAI jobs                                  │
│     ┌────────────────────────────────────────┐                 │
│     │  runai workspace list                  │                 │
│     │  ├─ gapit3-trait-2    Succeeded        │                 │
│     │  ├─ gapit3-trait-3    Running          │                 │
│     │  ├─ gapit3-trait-4    Pending          │                 │
│     │  └─ ...                                │                 │
│     └────────────────────────────────────────┘                 │
│                                                                 │
│  4. All jobs complete → trigger aggregation                     │
│     $ Rscript scripts/collect_results.R \                       │
│         --output-dir /outputs \                                 │
│         --batch-id "runai-20251107"                             │
│                                                                 │
│  5. Aggregated results created                                  │
│     /outputs/aggregated_results/                                │
│     ├─ summary_table.csv                                        │
│     ├─ significant_snps.csv                                     │
│     └─ summary_stats.json                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Script Flow

### Phase 1: Initialization

```bash
# Parse command-line arguments
--output-dir     # Default: /hpi/hpi_dev/.../outputs (from env or config)
--batch-id       # Default: "runai-$(date +%Y%m%d%H%M%S)"
--project        # Default: "talmo-lab"
--start-trait    # Default: 2
--end-trait      # Default: 187
--check-interval # Default: 30 (seconds)
--check-only     # Flag: Exit after status check
--force          # Flag: Skip waiting, run aggregation immediately

# Validate prerequisites
- Check runai CLI is available
- Check runai is authenticated (runai whoami)
- Check output directory exists
- Check collect_results.R exists
```

### Phase 2: Job Discovery

```bash
# Query RunAI for all gapit3-trait-* jobs
runai workspace list -p talmo-lab 2>/dev/null | grep "gapit3-trait-"

# Parse output to extract:
- Job name (e.g., "gapit3-trait-2")
- Status (Running, Succeeded, Failed, Pending, etc.)
- Trait index (extract number from name)

# Filter by trait range if specified
- Keep only jobs where trait index >= START_TRAIT and <= END_TRAIT

# Count jobs by status
TOTAL=$(found jobs matching pattern)
SUCCEEDED=$(jobs with "Succeeded")
FAILED=$(jobs with "Failed" or "Error")
RUNNING=$(jobs with "Running")
PENDING=$(jobs with "Pending" or other non-terminal states)
```

### Phase 3: Monitoring Loop (if not --force)

```bash
while [ $SUCCEEDED + $FAILED < $TOTAL ]; do
    # Display progress
    echo "Progress: $SUCCEEDED succeeded, $RUNNING running, $FAILED failed, $PENDING pending"
    echo "Waiting for $((TOTAL - SUCCEEDED - FAILED)) jobs to complete..."

    # Show progress bar
    COMPLETE=$((SUCCEEDED + FAILED))
    PERCENT=$((COMPLETE * 100 / TOTAL))
    [====================------------------] 55% (103/186)

    # Wait before next check
    sleep $CHECK_INTERVAL

    # Re-query RunAI
    # Update counts
done

# Final status
echo "All jobs complete!"
echo "  Succeeded: $SUCCEEDED"
echo "  Failed: $FAILED"
```

### Phase 4: Aggregation Execution

```bash
# Warn if many jobs failed
if [ $FAILED -gt 10 ]; then
    echo "Warning: $FAILED traits failed. Results will be partial."
    read -p "Continue with aggregation? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run collect_results.R
echo "Running aggregation..."
Rscript scripts/collect_results.R \
    --output-dir "$OUTPUT_DIR" \
    --batch-id "$BATCH_ID" \
    --threshold 5e-8

# Check exit code
if [ $? -eq 0 ]; then
    echo "Aggregation completed successfully!"
    echo "Results at: $OUTPUT_DIR/aggregated_results/"
else
    echo "ERROR: Aggregation failed. Check logs above."
    exit 1
fi
```

### Phase 5: Summary Report

```bash
# Show aggregation results
echo ""
echo "================================================================"
echo "Aggregation Complete"
echo "================================================================"
echo "Output directory: $OUTPUT_DIR/aggregated_results/"
echo "Batch ID: $BATCH_ID"
echo ""
echo "Generated files:"
ls -lh "$OUTPUT_DIR/aggregated_results/"
echo ""
echo "Summary statistics:"
if [ -f "$OUTPUT_DIR/aggregated_results/summary_stats.json" ]; then
    cat "$OUTPUT_DIR/aggregated_results/summary_stats.json" | jq '.'
fi
echo ""
```

## Integration Points

### 1. Integration with submit-all-traits-runai.sh

Add reminder message at the end of submission script:

```bash
# In scripts/submit-all-traits-runai.sh at the end:

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Monitor progress:"
echo "   ./scripts/monitor-runai-jobs.sh --watch"
echo ""
echo "2. Aggregate results when complete:"
echo "   ./scripts/aggregate-runai-results.sh"
echo ""
```

### 2. Integration with monitor-runai-jobs.sh

Add aggregation hint when all jobs complete:

```bash
# In scripts/monitor-runai-jobs.sh when SUCCEEDED + FAILED == TOTAL:

if [ $((SUCCEEDED + FAILED)) -eq 186 ]; then
    echo ""
    echo -e "${GREEN}All jobs complete!${NC}"
    echo "Run aggregation with:"
    echo "  ./scripts/aggregate-runai-results.sh"
fi
```

### 3. Integration with collect_results.R

No changes needed - script already:
- Accepts `--output-dir`, `--batch-id`, `--threshold` parameters
- Handles missing/failed traits gracefully
- Creates `aggregated_results/` directory

## Error Handling

### RunAI CLI Errors

```bash
# Check runai is available
if ! command -v runai &> /dev/null; then
    echo "ERROR: runai CLI not found. Please install RunAI CLI."
    exit 1
fi

# Check authentication
if ! runai whoami &> /dev/null; then
    echo "ERROR: Not authenticated to RunAI. Run: runai login"
    exit 1
fi

# Handle runai command failures
if ! runai workspace list -p $PROJECT &> /dev/null; then
    echo "ERROR: Failed to query RunAI. Check project name and permissions."
    exit 1
fi
```

### No Jobs Found

```bash
if [ $TOTAL -eq 0 ]; then
    echo "WARNING: No gapit3-trait-* jobs found in project $PROJECT"
    echo "Did you submit jobs with ./scripts/submit-all-traits-runai.sh ?"
    exit 0
fi
```

### Aggregation Failures

```bash
# collect_results.R exits with non-zero on errors
if [ $? -ne 0 ]; then
    echo "ERROR: Aggregation failed"
    echo "Possible causes:"
    echo "  - No successful traits found"
    echo "  - Output directory not writable"
    echo "  - R packages missing"
    echo ""
    echo "Check logs above for details"
    exit 1
fi
```

### User Interrupts

```bash
# Trap Ctrl+C gracefully
trap 'echo ""; echo "Interrupted. Jobs continue running in RunAI."; exit 130' INT

# Allow user to exit monitoring and run aggregation later
```

## Configuration

### Environment Variables

Allow overriding defaults via environment variables:

```bash
# User can set before running script
export RUNAI_PROJECT="talmo-lab"
export OUTPUT_DIR="/hpi/hpi_dev/users/eberrigan/outputs"
export BATCH_ID="my-custom-id"

# Script uses these as defaults if not specified via CLI
PROJECT="${RUNAI_PROJECT:-talmo-lab}"
OUTPUT_DIR="${OUTPUT_DIR:-/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs}"
```

### Config File Support (Future)

Could read from `.env` or `config.yaml` if present:

```bash
# Load from .env if exists
if [ -f .env ]; then
    source .env
fi
```

## Performance Considerations

### Polling Frequency

- **Default**: Check every 30 seconds
- **Trade-off**: More frequent = more responsive, but more API calls
- **Rationale**: 30s is reasonable for jobs that run 15-45 minutes

### Resource Usage

- **Script overhead**: Minimal (just shell + runai CLI calls)
- **Network**: One API call per check interval (negligible)
- **Memory**: <1MB for bash script

### Long-Running Sessions

- Jobs may take 3-4 hours total
- Script should not block terminal or require SSH connection
- **Solution**: Run in background or tmux/screen session

```bash
# Background execution
nohup ./scripts/aggregate-runai-results.sh > aggregation.log 2>&1 &

# Or use tmux
tmux new -s aggregation
./scripts/aggregate-runai-results.sh
# Ctrl+B, D to detach
```

## Testing Strategy

### Unit Testing (Manual)

1. **No jobs scenario**:
   ```bash
   # Clean slate - no jobs submitted
   ./scripts/aggregate-runai-results.sh --check-only
   # Expected: "No jobs found" message
   ```

2. **All completed scenario**:
   ```bash
   # All traits already complete
   ./scripts/aggregate-runai-results.sh --force
   # Expected: Immediate aggregation
   ```

3. **Partial completion scenario**:
   ```bash
   # Some jobs still running
   ./scripts/aggregate-runai-results.sh --check-only
   # Expected: Show counts, don't wait
   ```

4. **Trait range filtering**:
   ```bash
   # Only aggregate traits 2-10
   ./scripts/aggregate-runai-results.sh --start-trait 2 --end-trait 10
   # Expected: Only consider those 9 traits
   ```

### Integration Testing

Submit small batch and test end-to-end:

```bash
# 1. Submit 3 traits
START_TRAIT=2 END_TRAIT=4 ./scripts/submit-all-traits-runai.sh

# 2. Run aggregation
./scripts/aggregate-runai-results.sh --start-trait 2 --end-trait 4

# 3. Verify outputs
ls -la /outputs/aggregated_results/
# Should contain: summary_table.csv, significant_snps.csv, summary_stats.json
```

## Documentation Updates

### 1. docs/MANUAL_RUNAI_EXECUTION.md

Add new section after "Step 3: Run Multiple Traits":

```markdown
### Step 4: Aggregate Results

After all traits complete, aggregate results into summary reports:

\```bash
# Wait for all jobs to complete and auto-aggregate
./scripts/aggregate-runai-results.sh

# Or force aggregation immediately (if jobs already done)
./scripts/aggregate-runai-results.sh --force

# Check status without waiting
./scripts/aggregate-runai-results.sh --check-only
\```

This creates:
- `aggregated_results/summary_table.csv` - All traits summary
- `aggregated_results/significant_snps.csv` - Significant SNPs
- `aggregated_results/summary_stats.json` - Overall statistics
```

### 2. docs/RUNAI_QUICK_REFERENCE.md

Add to "Common Workflows" section:

```markdown
### Aggregate Results After Parallel Execution

\```bash
# Wait for all jobs to complete, then aggregate
./scripts/aggregate-runai-results.sh

# Custom output path and batch ID
./scripts/aggregate-runai-results.sh \
  --output-dir /custom/path \
  --batch-id "my-batch-id"

# Specific trait range
./scripts/aggregate-runai-results.sh --start-trait 2 --end-trait 50
\```
```

### 3. README.md

Update "Current workarounds available" section:

```markdown
- ✅ **Manual RunAI CLI** - Working now
- ✅ **Batch submission script** - scripts/submit-all-traits-runai.sh
- ✅ **Aggregation script** - scripts/aggregate-runai-results.sh (NEW)
- ✅ **Monitoring dashboard** - scripts/monitor-runai-jobs.sh
```

## Future Enhancements

### 1. Email Notifications

Add `--notify-email` flag to send email when aggregation completes:

```bash
./scripts/aggregate-runai-results.sh --notify-email user@example.com
```

### 2. Slack Integration

Post to Slack channel when complete:

```bash
./scripts/aggregate-runai-results.sh --slack-webhook $WEBHOOK_URL
```

### 3. Auto-Submit + Aggregate

Combined script that does both:

```bash
./scripts/run-all-traits-runai.sh  # Submit + wait + aggregate
```

### 4. Incremental Aggregation

Aggregate results as they complete (don't wait for all):

```bash
./scripts/aggregate-runai-results.sh --incremental
```

### 5. HTML Report Generation

Generate interactive HTML report with plots:

```bash
./scripts/aggregate-runai-results.sh --html-report
```
