# Design: Cleanup Helper Script

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  cleanup-runai.sh                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  1. Parse Arguments & Validate                       │  │
│  │     - Parse flags (--all, --start-trait, etc.)      │  │
│  │     - Validate trait ranges                          │  │
│  │     - Check prerequisites (runai CLI, paths)         │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  2. Discover Resources                               │  │
│  │     - List existing RunAI workspaces                 │  │
│  │     - List existing output directories               │  │
│  │     - Calculate counts                               │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  3. Preview & Confirm                                │  │
│  │     - Display what will be deleted                   │  │
│  │     - Dry-run: Exit here                             │  │
│  │     - Interactive: Prompt for confirmation           │  │
│  │     - Force: Skip confirmation                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  4. Delete Workspaces (if enabled)                   │  │
│  │     - Loop through trait range                       │  │
│  │     - runai workspace delete <name> -p <project>     │  │
│  │     - Track: deleted, not-found, failed              │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  5. Delete Output Files (if enabled)                 │  │
│  │     - Delete trait_* directories                     │  │
│  │     - Delete aggregated_results directory            │  │
│  │     - Track: deleted directories count               │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  6. Display Summary                                  │  │
│  │     - Show statistics                                │  │
│  │     - Report any errors                              │  │
│  │     - Suggest next steps                             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. Configuration & Defaults

```bash
# Configuration
PROJECT="talmo-lab"
OUTPUT_PATH="/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs"
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
```

### 2. Resource Discovery

```bash
discover_resources() {
    local start=$1
    local end=$2

    # Discover RunAI workspaces
    local existing_workspaces=()
    for i in $(seq $start $end); do
        if runai workspace list -p $PROJECT 2>/dev/null | grep -qE "^[[:space:]]*gapit3-trait-$i[[:space:]]"; then
            existing_workspaces+=("gapit3-trait-$i")
        fi
    done

    # Discover output directories
    local existing_outputs=()
    for i in $(seq $start $end); do
        if [ -d "$OUTPUT_PATH/trait_$i" ]; then
            existing_outputs+=("$OUTPUT_PATH/trait_$i")
        fi
    done

    # Check aggregated results
    local has_aggregated=false
    if [ -d "$OUTPUT_PATH/aggregated_results" ]; then
        has_aggregated=true
    fi

    echo "${#existing_workspaces[@]} ${#existing_outputs[@]} $has_aggregated"
}
```

### 3. Confirmation Logic

```bash
confirm_deletion() {
    local workspace_count=$1
    local output_count=$2
    local has_aggregated=$3

    echo ""
    echo -e "${RED}WARNING: This will delete:${NC}"

    if [ "$WORKSPACES_ONLY" = false ]; then
        echo "  - $output_count trait output directories"
        [ "$has_aggregated" = "true" ] && echo "  - Aggregated results directory"
    fi

    if [ "$OUTPUTS_ONLY" = false ]; then
        echo "  - $workspace_count RunAI workspaces"
    fi

    echo ""
    echo "Trait range: $START_TRAIT to $END_TRAIT"
    echo "Output path: $OUTPUT_PATH"
    echo ""

    if [ "$FORCE" = true ]; then
        return 0
    fi

    read -p "Type 'yes' to confirm deletion: " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
}
```

### 4. Deletion Operations

```bash
delete_workspaces() {
    local start=$1
    local end=$2

    echo ""
    echo -e "${BLUE}Deleting RunAI workspaces...${NC}"

    local deleted=0
    local not_found=0
    local failed=0

    for i in $(seq $start $end); do
        local job_name="gapit3-trait-$i"

        if runai workspace delete $job_name -p $PROJECT 2>/dev/null; then
            echo -e "  ${GREEN}[✓]${NC} Deleted $job_name"
            deleted=$((deleted + 1))
        else
            # Check if it didn't exist or actually failed
            if runai workspace list -p $PROJECT 2>/dev/null | grep -qE "^[[:space:]]*$job_name[[:space:]]"; then
                echo -e "  ${RED}[✗]${NC} Failed to delete $job_name"
                failed=$((failed + 1))
            else
                not_found=$((not_found + 1))
            fi
        fi

        # Small delay to avoid API rate limits
        sleep 0.5
    done

    echo ""
    echo "  Deleted: $deleted"
    echo "  Not found: $not_found"
    if [ $failed -gt 0 ]; then
        echo -e "  ${RED}Failed: $failed${NC}"
    fi
}

delete_outputs() {
    local start=$1
    local end=$2

    echo ""
    echo -e "${BLUE}Deleting output files...${NC}"

    local deleted=0

    for i in $(seq $start $end); do
        local dir="$OUTPUT_PATH/trait_$i"
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            echo -e "  ${GREEN}[✓]${NC} Deleted $dir"
            deleted=$((deleted + 1))
        fi
    done

    # Delete aggregated results
    if [ -d "$OUTPUT_PATH/aggregated_results" ]; then
        rm -rf "$OUTPUT_PATH/aggregated_results"
        echo -e "  ${GREEN}[✓]${NC} Deleted $OUTPUT_PATH/aggregated_results"
    fi

    echo ""
    echo "  Deleted $deleted trait directories"
}
```

## Command-Line Interface

### Arguments

| Flag | Short | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--all` | | Boolean | false | Clean up all traits (2-187) |
| `--start-trait` | | Integer | 2 | First trait to clean up |
| `--end-trait` | | Integer | 187 | Last trait to clean up |
| `--workspaces-only` | | Boolean | false | Only delete RunAI workspaces |
| `--outputs-only` | | Boolean | false | Only delete output files |
| `--dry-run` | `-n` | Boolean | false | Preview without deleting |
| `--force` | `-f` | Boolean | false | Skip confirmation prompts |
| `--help` | `-h` | Boolean | false | Show help message |

### Validation Rules

1. **Mutually exclusive**: `--all` cannot be used with `--start-trait` or `--end-trait`
2. **Mutually exclusive**: `--workspaces-only` and `--outputs-only` cannot both be true
3. **Range validation**: `--start-trait` must be ≤ `--end-trait`
4. **Range bounds**: Traits must be between 2 and 187

### Examples

```bash
# Clean everything (all 186 traits)
./scripts/cleanup-runai.sh --all

# Clean specific range
./scripts/cleanup-runai.sh --start-trait 2 --end-trait 4

# Preview what would be deleted
./scripts/cleanup-runai.sh --all --dry-run

# Only delete RunAI workspaces (keep outputs)
./scripts/cleanup-runai.sh --all --workspaces-only

# Only delete output files (keep workspaces)
./scripts/cleanup-runai.sh --all --outputs-only

# Force deletion without confirmation (for automation)
./scripts/cleanup-runai.sh --start-trait 42 --end-trait 42 --force
```

## Error Handling

### Graceful Failures

```bash
# Continue on individual failures
for i in $(seq $START_TRAIT $END_TRAIT); do
    runai workspace delete gapit3-trait-$i -p $PROJECT 2>/dev/null || {
        echo "Warning: Could not delete workspace gapit3-trait-$i"
        FAILED=$((FAILED + 1))
    }
done

# Report failures at end
if [ $FAILED -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Warning: $FAILED workspaces could not be deleted${NC}"
    echo "This may be due to permissions or non-existent workspaces"
fi
```

### Prerequisites Checks

```bash
# Check RunAI CLI
if ! command -v runai &> /dev/null; then
    echo "ERROR: runai CLI not found"
    exit 1
fi

# Check authentication
if ! runai whoami &> /dev/null 2>&1; then
    echo "ERROR: Not authenticated to RunAI"
    exit 1
fi

# Validate output path
if [ ! -d "$OUTPUT_PATH" ]; then
    echo "WARNING: Output path does not exist: $OUTPUT_PATH"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi
```

## Security Considerations

1. **Confirmation prompts**: Require explicit "yes" (not just "y") for destructive operations
2. **Path validation**: Ensure OUTPUT_PATH doesn't contain wildcards or special characters
3. **Dry-run default**: Consider making dry-run the default, requiring `--execute` flag
4. **Audit logging**: Log all deletions to a file for troubleshooting

## Performance Considerations

1. **Parallel deletion**: Could parallelize workspace deletion (future optimization)
2. **Rate limiting**: Add delay between RunAI API calls to avoid throttling
3. **Batch operations**: RunAI CLI doesn't support bulk delete, must be sequential

## Future Enhancements

1. **Backup before delete**: `--backup` flag to archive outputs before deletion
2. **Selective deletion**: `--failed-only` to delete only failed trait workspaces
3. **Interactive mode**: TUI to select specific traits to delete
4. **Undo capability**: Move to trash instead of permanent deletion
5. **Integration**: `--cleanup` flag in submit script that calls this
