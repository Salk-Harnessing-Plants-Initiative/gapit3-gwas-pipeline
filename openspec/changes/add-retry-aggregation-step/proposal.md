# OpenSpec Change Proposal: Add Aggregation Step to Retry Workflow

## Summary

Modify the `retry-argo-traits.sh` script to include an optional aggregation step that runs in-cluster after all retry traits complete, and fix duplicate trait handling in `collect_results.R`.

## Motivation

### Problem
1. The main pipeline's `collect-results` step is skipped when any trait fails (DAG dependency requires upstream success)
2. Users must manually run aggregation after retries complete
3. The current `--aggregate` flag calls a RunAI-specific script that doesn't work for Argo workflows
4. When traits are retried, multiple output directories exist per trait, causing duplicate results in aggregation

### Solution
1. When `--aggregate` flag is used, include a `collect-results` task in the generated retry workflow DAG
2. Update `collect_results.R` to handle duplicate trait directories by selecting the most complete one

## Scope

### In Scope
- Modify `retry-argo-traits.sh` to generate aggregation task when `--aggregate` is specified
- Update `collect_results.R` to deduplicate trait directories (pick most complete, then newest)
- Remove local `aggregate-runai-results.sh` call from retry script
- Update help text to clarify aggregation runs in-cluster

### Out of Scope
- Modifying the main pipeline's DAG structure
- Creating a standalone aggregation submission script
- Deleting old partial trait directories

## Risk Assessment

- **Low Risk**: Reuses existing, tested aggregation template
- **Low Risk**: Optional feature (requires explicit `--aggregate` flag)
- **Medium Risk**: R script changes affect all aggregation runs (but improves correctness)

## Stakeholders

- Pipeline users who need to retry failed traits
- Operators managing Argo Workflows
