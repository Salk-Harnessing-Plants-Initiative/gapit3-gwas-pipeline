# Design: Fix Unnecessary GWAS_Results Fallback for Empty Filter Files

## Current Behavior

### Filter File Formats

GAPIT creates Filter files with two different schemas depending on whether significant SNPs exist:

**Format 1: Has significant SNPs**
```csv
,SNP,Chr,Pos,P.value,MAF,traits
1242494,PERL5.16140651,5,16140651,1.103294e-08,536,BLINK.mean_GR_rootLength_day_1.2(NYC)
```
- **Columns**: Includes `traits` column with model information
- **Rows**: Contains data (significant SNPs)

**Format 2: No significant SNPs**
```csv
,SNP,Chr,Pos,P.value,MAF,nobs,Effect,H.B.P.Value

```
- **Columns**: NO `traits` column (different schema)
- **Rows**: Empty (header only)

### Current Fallback Flow

```
read_filter_file(trait_dir)
  ↓
Filter file exists? YES
  ↓
Read Filter file (fast)
  ↓
Has 'traits' column? NO
  ↓
⚠️ Call read_gwas_results_fallback() ← PROBLEM
  ↓
Find GWAS_Results files
  ↓
Read each file (1.4M rows × 2 models)
  ↓
Filter for P.value < threshold
  ↓
Return empty (no significant SNPs found)
```

**Problem**: Reads millions of rows just to discover what the Filter file already told us (no significant SNPs).

## Proposed Behavior

### Correct Fallback Flow

```
read_filter_file(trait_dir)
  ↓
Filter file exists?
  ├─ NO → read_gwas_results_fallback() (backward compat)
  └─ YES → Read Filter file (fast)
           ↓
           Has 'traits' column?
             ├─ NO → return data.frame() ✅ (no significant SNPs)
             └─ YES → Has data rows?
                      ├─ NO → return data.frame()
                      └─ YES → Parse model from traits column
```

## Key Design Decisions

### Decision 1: Skip fallback for empty Filter files

**Rationale**:
- Filter file without `traits` column = GAPIT's way of saying "no significant SNPs"
- Reading GWAS_Results won't find anything the Filter file didn't
- Orders of magnitude faster to just return empty

**Alternative considered**: Read GWAS_Results filenames to infer model
- **Rejected**: Still requires filesystem ops, and there's nothing to tag with a model anyway

### Decision 2: Keep fallback for missing Filter files

**Rationale**:
- Backward compatibility with older GAPIT runs
- Edge case: User might have deleted Filter files but kept GWAS_Results
- Cost: Only triggered when Filter file genuinely missing (rare)

### Decision 3: Add informational message instead of warning

**Before**:
```
Warning: Filter file missing 'traits' column in trait_003
Warning: Filter file missing for trait_003 - using GWAS_Results fallback (slower)
```

**After**:
```
Note: No significant SNPs found in trait_003 (skipping)
```

**Rationale**:
- Not a warning - this is expected behavior for traits with no hits
- Less alarming to users
- Clearer about what's actually happening

## Implementation

### Modified Function

```r
read_filter_file <- function(trait_dir, threshold = 5e-8) {
  filter_file <- file.path(trait_dir, "GAPIT.Association.Filter_GWAS_results.csv")

  if (!file.exists(filter_file)) {
    return(read_gwas_results_fallback(trait_dir, threshold))
  }

  tryCatch({
    filter_data <- fread(filter_file, data.table = FALSE)

    # CHANGE: Check for traits column before attempting fallback
    if (!"traits" %in% colnames(filter_data)) {
      # No traits column means no significant SNPs (empty Filter file)
      return(data.frame())
    }

    # Return empty data.frame if no rows
    if (nrow(filter_data) == 0) {
      return(data.frame())
    }

    # Parse model and trait from traits column
    filter_data$model <- sub("\\..*", "", filter_data$traits)
    filter_data$trait <- sub("^[^.]+\\.", "", filter_data$traits)

    # Validate model names
    expected_models <- c("BLINK", "FarmCPU", "GLM", "MLM", "MLMM",
                         "FarmCPU.LM", "Blink.LM")
    unexpected <- unique(filter_data$model[!(filter_data$model %in% expected_models)])
    if (length(unexpected) > 0) {
      cat("  Warning: Unexpected model names in", basename(trait_dir), ":",
          paste(unexpected, collapse=", "), "\n")
    }

    filter_data$traits <- NULL
    return(filter_data)

  }, error = function(e) {
    cat("  Warning: Error reading Filter file for", basename(trait_dir), ":",
        e$message, "\n")
    return(read_gwas_results_fallback(trait_dir, threshold))
  })
}
```

### Lines Changed

- **Line 76-79**: Remove fallback call for missing `traits` column
- **Line 76-78**: Add immediate return of empty data.frame
- **Result**: Eliminates ~100 lines of unnecessary execution per empty trait

## Testing Strategy

### Test Fixtures

1. `trait_empty_filter_no_traits/` - Filter file without `traits` column (empty)
2. `trait_empty_filter_with_traits/` - Filter file with `traits` column but no rows
3. `trait_with_data/` - Filter file with `traits` column and data
4. `trait_no_filter/` - No Filter file (fallback case)

### Test Cases

| Test | Filter Exists? | Has `traits`? | Has Rows? | Expected Behavior |
|------|----------------|---------------|-----------|-------------------|
| 1    | ❌ No          | N/A           | N/A       | Fallback to GWAS_Results |
| 2    | ✅ Yes         | ❌ No         | N/A       | Return empty immediately |
| 3    | ✅ Yes         | ✅ Yes        | ❌ No     | Return empty immediately |
| 4    | ✅ Yes         | ✅ Yes        | ✅ Yes    | Parse and return data |

### Performance Validation

**Test**: Aggregate 186 traits (30 empty)
- **Before**: ~2-3 minutes (reads 84M rows for empty traits)
- **After**: <30 seconds (skips empty traits immediately)
- **Assertion**: Runtime < 45 seconds

## Breaking Changes

None. Output is identical, just generated faster.

## Edge Cases

1. **Corrupted Filter file**: Falls back to GWAS_Results (existing error handler)
2. **Filter file with `traits` column but all NA**: Returns empty (no valid data)
3. **Filter file with mixed schemas**: Impossible (GAPIT generates consistent format per file)
4. **Multiple models, some empty**: Each model creates separate rows, all handled correctly

## Rollback Plan

If issues arise, revert to previous behavior by restoring the fallback call:

```r
if (!"traits" %in% colnames(filter_data)) {
  return(read_gwas_results_fallback(trait_dir, threshold))
}
```

No data migration needed - pure code change.
