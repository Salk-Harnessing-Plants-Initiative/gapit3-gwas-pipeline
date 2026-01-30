## Why

When GWAS results are aggregated from multiple workflow runs (e.g., initial run + retry workflow), the pipeline summary report only shows the `batch_id` passed to the aggregation command. This makes it appear that all results came from a single workflow, when in reality they may come from 2+ different Argo workflows.

Currently:
- `source_workflow_uids` is collected in `summary_stats.json` but not surfaced in the markdown report
- The Executive Summary shows a single "Workflow ID" with no indication of multiple sources
- Users have no visibility into which traits came from which workflow
- Computation time metrics are aggregated but not broken down by source workflow

This causes confusion when reviewing results and makes reproducibility tracking incomplete.

## What Changes

1. **Detect multi-workflow scenarios** - When `source_workflow_uids` contains more than one UID, flag this in the report
2. **Report all source workflows** - Add a "Source Workflows" section to the markdown summary showing all contributing workflows with trait counts
3. **Update Executive Summary** - When multiple workflows contributed, show "Multiple Workflows (N)" instead of a single batch_id
4. **Add per-workflow statistics** - Break down trait counts and compute time by source workflow
5. **Console notification** - Print a notice during aggregation when results come from multiple workflows

## Impact

- Affected specs: `results-aggregation/spec.md` (add multi-workflow reporting requirements)
- Affected code:
  - `scripts/collect_results.R` (provenance collection and markdown generation)
  - Test fixtures (add multi-workflow test scenario)

## Design Decisions

### Per-Workflow vs Per-Trait Tracking
We track statistics per source workflow (trait count, compute time) rather than per-trait workflow mapping. This provides useful summary information without bloating the report with per-trait workflow annotations.

### Backwards Compatibility
Single-workflow aggregations continue to work exactly as before. Multi-workflow behavior only activates when `len(source_workflow_uids) > 1`.

### Report Structure
Add a new "Source Workflows" subsection under "Reproducibility" rather than changing the Executive Summary layout significantly. The Executive Summary will show "Multiple Workflows" as a hint, with details in Reproducibility.
