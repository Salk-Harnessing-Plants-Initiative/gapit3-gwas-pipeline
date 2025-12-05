## Why

The Argo workflow files contain several inconsistencies that cause confusion:

1. **Unused parameters displayed in logs**: `cpu-cores`, `memory-gb`, and `max-parallelism` are defined as workflow parameters but never referenced - they appear in Argo UI/logs but have no effect
2. **Stale default values**: WorkflowTemplate default for `models` is `BLINK,FarmCPU` while workflows use `BLINK,FarmCPU,MLM`
3. **Duplicate parameter passing**: CLI args in WorkflowTemplate duplicate env vars (already addressed in `fix-duplicate-parameter-passing`)
4. **Missing env vars in test pipeline**: `validate` template in test pipeline doesn't set `GENOTYPE_FILE`/`PHENOTYPE_FILE` env vars
5. **Hardcoded paths inconsistency**: Phenotype file path is hardcoded in `extract-traits` args but should match env var pattern
6. **Comment inaccuracies**: Comments reference "184 traits" when actual range is 186 traits (2-187)

These issues lead to:
- Operator confusion when parameter changes don't take effect
- Debugging difficulty when displayed values don't match actual behavior
- Maintenance burden keeping multiple sources in sync

## What Changes

- **BREAKING**: Remove unused parameters (`cpu-cores`, `memory-gb`, `max-parallelism`) from workflow files
- Remove duplicate CLI args from WorkflowTemplate (keep env vars only)
- Update WorkflowTemplate default values to match current usage
- Add missing env vars to test pipeline validate template
- Fix comment inaccuracies (trait counts)
- Add documentation comments explaining parameter flow

## Impact

- Affected specs: `openspec/specs/argo-workflow-configuration/spec.md` (to be created)
- Affected code:
  - `cluster/argo/workflows/gapit3-parallel-pipeline.yaml`
  - `cluster/argo/workflows/gapit3-test-pipeline.yaml`
  - `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`
