## Why

The current aggregation script (`collect_results.R`) has two issues:

1. **Inconsistent deduplication logic**: When multiple directories exist for the same trait, deduplication counts `GWAS_Results` files to pick the "best" directory, but the completeness check uses `Filter_GWAS_results.csv`. This can cause selection of an incomplete directory over a complete one when the incomplete one has more partial model outputs.

2. **No workflow awareness**: The script aggregates all matching directories regardless of which workflow produced them. When traits span multiple workflows (original + retries), there's no way to explicitly specify which workflows to include, and no audit trail of which directories were used.

## What Changes

- **Filter-first deduplication**: Change dedup logic to prioritize directories WITH Filter file, then fall back to model count and timestamp only when multiple directories have Filter files
- **Multi-workflow ID filter**: Add `--workflow-id` parameter accepting comma-separated workflow IDs to filter directories by workflow name extracted from `metadata.json`
  - Backward compatible: Extract workflow name from `execution.hostname` field (pattern: `<workflow-name>-run-gwas-<hash>`)
  - Future: Will also check for explicit `workflow.name` field if present
- **Deduplication audit log**: Report which directories were selected/discarded and why in the aggregation output
- **Source manifest**: Write list of selected directories to `aggregated_results/source_directories.txt` for reproducibility

## Impact

- Affected specs: `results-aggregation`
- Affected code: `scripts/collect_results.R` (deduplication logic in `select_best_trait_dirs`)
- Non-breaking change: New `--workflow-id` parameter is optional; existing behavior preserved when not specified
- Dedup behavior change is a correctness fix (will never select incomplete over complete)
