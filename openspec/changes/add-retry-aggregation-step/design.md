## Context

The GAPIT3 GWAS pipeline has an existing aggregation infrastructure:

1. **R Script**: `scripts/collect_results.R` - scans output directory, aggregates GWAS results
2. **WorkflowTemplate**: `gapit3-results-collector` - runs the R script in-cluster
3. **Main Pipeline Integration**: `gapit3-parallel-pipeline.yaml` includes `collect-results` as final DAG step

**Problem 1**: When traits fail, the main pipeline's `collect-results` step is skipped because DAG dependencies require upstream success. Users must manually aggregate after running retries.

**Problem 2**: When a trait is retried, GAPIT creates a NEW output directory with a different timestamp:
- Original: `trait_005_Zn_ICP_20251112_200000/` (partial - missing MLM)
- Retry: `trait_005_Zn_ICP_20251123_120000/` (complete - all models)

The current `collect_results.R` processes ALL directories matching `trait_\d+_*`, resulting in duplicate rows and SNPs.

**Current retry script behavior** (`--aggregate` flag):
```bash
if [[ "$AGGREGATE" == "true" ]]; then
    "$SCRIPT_DIR/aggregate-runai-results.sh" --force --output-dir "$OUTPUT_HOSTPATH"
fi
```
This calls a RunAI-specific script that requires `runai` CLI - doesn't work for pure Argo workflows.

## Goals / Non-Goals

**Goals:**
- Include aggregation as optional final step in retry workflow
- Reuse existing `gapit3-results-collector` template
- Run aggregation in-cluster (no local dependencies)
- Handle duplicate trait directories correctly (pick most complete)
- Aggregate all traits, not just retried ones

**Non-Goals:**
- Modify the main pipeline's DAG structure
- Create separate aggregation-only workflow
- Delete old partial directories automatically

## Decisions

### Decision 1: Include Aggregation in Generated DAG

**Choice**: When `--aggregate` is specified, add a `collect-results` task to the generated retry workflow DAG.

**Alternatives considered**:
1. **Separate aggregation script** - Requires extra step, more commands for user
2. **Local aggregation call** - Requires R and dependencies installed locally
3. **Wait and call standalone workflow** - Complex, hard to track

**Rationale**:
- Single workflow submission handles everything
- Aggregation runs after all retries complete (natural DAG dependency)
- Uses existing, tested template
- No local dependencies required

### Decision 2: Smart Duplicate Handling in collect_results.R

**Choice**: For each trait index, select the directory with the most complete model outputs. If tied, select the newest.

**Algorithm**:
```
For each trait index:
  1. Find all directories matching trait_<index>_*
  2. For each directory, count how many expected models have GWAS_Results files
  3. Pick the directory with the MOST models complete
  4. If tied (same completeness), pick the newest (latest timestamp)
  5. Use only that directory for aggregation
```

**Example scenarios**:

| Scenario | Old Directory | New Directory | Selected |
|----------|---------------|---------------|----------|
| Retry succeeded | 2/3 models (BLINK, FarmCPU) | 3/3 models (all) | New (more complete) |
| Retry failed | 2/3 models | 1/3 models | Old (more complete) |
| Both complete | 3/3 models | 3/3 models | New (tie-breaker: newest) |
| Only old exists | 3/3 models | N/A | Old |

**Rationale**:
- Maximizes data recovery - uses whichever run got furthest
- Handles partial failures gracefully
- Newest is tie-breaker (likely has latest code/fixes)
- No data loss - old directories remain on disk for debugging

### Decision 3: Remove Local Aggregation Call

**Choice**: Remove the existing local `aggregate-runai-results.sh` call from the retry script.

**Rationale**:
- The RunAI-specific script doesn't work without `runai` CLI
- In-cluster aggregation is more reliable
- Reduces local dependencies
- Consistent with Argo-native approach

## Architecture

### Generated Workflow Structure (with --aggregate)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: gapit3-gwas-retry-8nj24-
spec:
  entrypoint: retry-traits

  templates:
  - name: retry-traits
    dag:
      tasks:
      # Retry failed traits
      - name: retry-trait-5
        templateRef:
          name: gapit3-gwas-single-trait-highmem
          template: run-gwas
        arguments: ...

      - name: retry-trait-28
        templateRef:
          name: gapit3-gwas-single-trait-highmem
          template: run-gwas
        arguments: ...

      # ... more retry tasks ...

      # Aggregation step (depends on ALL retry tasks)
      - name: collect-results
        dependencies: [retry-trait-5, retry-trait-28, retry-trait-29, ...]
        templateRef:
          name: gapit3-results-collector
          template: collect-results
        arguments:
          parameters:
          - name: image
            value: "{{workflow.parameters.image}}"
          - name: batch-id
            value: "{{workflow.name}}"
```

### R Script Changes (collect_results.R)

**New helper function**:
```r
#' Select best directory for each trait index
#'
#' When multiple directories exist for the same trait (from retries),
#' select the one with the most complete model outputs.
#' If tied, select the newest (by timestamp in directory name).
#'
#' @param trait_dirs Vector of trait directory paths
#' @param expected_models Vector of expected model names (e.g., c("BLINK", "FarmCPU", "MLM"))
#' @return Vector of selected trait directory paths (one per trait index)
select_best_trait_dirs <- function(trait_dirs, expected_models) {
  if (length(trait_dirs) == 0) return(character(0))

  # Extract trait index from directory name
  # Pattern: trait_<index>_<name>_<timestamp>
  trait_info <- data.frame(
    path = trait_dirs,
    basename = basename(trait_dirs),
    stringsAsFactors = FALSE
  )
  trait_info$trait_index <- as.integer(
    sub("trait_(\\d+)_.*", "\\1", trait_info$basename)
  )

  # Count complete models for each directory
  trait_info$n_models <- sapply(trait_info$path, function(dir) {
    sum(sapply(expected_models, function(model) {
      pattern <- paste0("GAPIT.Association.GWAS_Results.", model, ".")
      length(list.files(dir, pattern = pattern)) > 0
    }))
  })

  # Extract timestamp for tie-breaking (last component of directory name)
  # Format: trait_005_TraitName_20251123_120000
  trait_info$timestamp <- sub(".*_(\\d{8}_\\d{6})$", "\\1", trait_info$basename)

  # For each trait index, select best directory
  # Priority: most models complete, then newest timestamp
  selected <- trait_info %>%
    group_by(trait_index) %>%
    arrange(desc(n_models), desc(timestamp)) %>%
    slice(1) %>%
    ungroup()

  # Log duplicates for transparency
  duplicates <- trait_info %>%
    group_by(trait_index) %>%
    filter(n() > 1) %>%
    summarise(
      n_dirs = n(),
      selected = path[which.max(n_models)],
      .groups = "drop"
    )

  if (nrow(duplicates) > 0) {
    cat("  Note: Found multiple directories for", nrow(duplicates), "traits\n")
    cat("  Selecting most complete directory for each:\n")
    for (i in seq_len(nrow(duplicates))) {
      cat("    - Trait", duplicates$trait_index[i], ":",
          duplicates$n_dirs[i], "directories ->",
          basename(duplicates$selected[i]), "\n")
    }
  }

  return(selected$path)
}
```

**Updated scanning logic**:
```r
# Current (problematic):
trait_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = TRUE)
trait_dirs <- trait_dirs[grepl("trait_\\d+_", basename(trait_dirs))]

# New (with deduplication):
all_trait_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = TRUE)
all_trait_dirs <- all_trait_dirs[grepl("trait_\\d+_", basename(all_trait_dirs))]

# Get expected models from workflow or use defaults
expected_models <- c("BLINK", "FarmCPU", "MLM")  # Could be parameterized

# Select best directory per trait
trait_dirs <- select_best_trait_dirs(all_trait_dirs, expected_models)
```

### Shell Script Changes (retry-argo-traits.sh)

**Before** (current):
```bash
if [[ "$AGGREGATE" == "true" ]]; then
    log_info "Running aggregation..."
    "$SCRIPT_DIR/aggregate-runai-results.sh" --force --output-dir "$OUTPUT_HOSTPATH"
fi
```

**After** (proposed):
```bash
# When generating workflow YAML, if --aggregate is set:
if [[ "$AGGREGATE" == "true" ]]; then
    # Build dependencies list
    DEPS_LIST=""
    for trait in "${TRAIT_ARRAY[@]}"; do
        DEPS_LIST+="retry-trait-${trait}, "
    done
    DEPS_LIST="${DEPS_LIST%, }"  # Remove trailing comma

    # Add collect-results task to DAG
    TASKS_YAML+="      - name: collect-results
        dependencies: [${DEPS_LIST}]
        templateRef:
          name: gapit3-results-collector
          template: collect-results
        arguments:
          parameters:
          - name: image
            value: \\\"{{workflow.parameters.image}}\\\"
          - name: batch-id
            value: \\\"{{workflow.name}}\\\"
"
    log_info "Aggregation step will run after all retries complete (in-cluster)"
fi
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Aggregation fails after retries succeed | Aggregation task failure doesn't affect trait outputs; can re-run aggregation manually |
| R script changes break existing aggregation | Extensive testing; changes are additive (dedup logic) |
| Model list not known at aggregation time | Use standard models or add as parameter |
| Old partial results confuse users | Log which directories were selected and why |

## Implementation Order

1. **First**: Update `collect_results.R` with `select_best_trait_dirs()` function
2. **Then**: Update `retry-argo-traits.sh` to generate aggregation task when `--aggregate` is set
3. Remove local `aggregate-runai-results.sh` call from retry script
4. Update help text for `--aggregate` flag
5. Rebuild Docker image with updated R script
6. Test with real retry workflow

## Open Questions

1. Should the expected models be parameterized in the R script?
   - **Proposed answer**: Yes, add `--models` argument to collect_results.R for flexibility.

2. Should we warn if a trait has no complete models across all directories?
   - **Proposed answer**: Yes, log a warning but continue with partial data.

3. Should the main pipeline also benefit from this deduplication?
   - **Proposed answer**: Yes, this fix applies to all aggregation runs.
