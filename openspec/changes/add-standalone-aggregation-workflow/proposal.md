## Why

After retry workflows complete or when the main workflow finishes without aggregation, users need a way to run results aggregation independently. Currently, aggregation only runs as part of the main pipeline DAG or via the `--aggregate` flag in retry workflows. There's no standalone workflow for ad-hoc aggregation.

The new `gapit3-aggregation-standalone.yaml` workflow file was added to support this use case, but it lacks documentation and integration with existing commands.

## What Changes

- **New Argo workflow file**: `cluster/argo/workflows/gapit3-aggregation-standalone.yaml` (already created)
- **Documentation updates**:
  - Update `cluster/argo/README.md` to document the standalone aggregation workflow
  - Update `.claude/commands/aggregate-results.md` to include Argo workflow option
- **Spec updates**: Add requirement for standalone aggregation workflow capability

## Impact

- Affected specs: `argo-workflow-configuration`
- Affected code: Documentation only (workflow file already exists)
- Non-breaking change: Adds new capability without modifying existing behavior
- Enables running aggregation independently of GWAS workflows