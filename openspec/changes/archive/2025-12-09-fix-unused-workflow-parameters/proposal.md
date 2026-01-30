## Why

The Argo workflow files and helper scripts contain several inconsistencies that cause confusion:

1. **Unused parameters displayed in logs**: `cpu-cores`, `memory-gb`, and `max-parallelism` are defined as workflow parameters but never referenced - they appear in Argo UI/logs but have no effect
2. **Script passes unused parameters**: `submit_workflow.sh` accepts `--cpu` and `--memory` flags and passes them to workflows, but the workflows never use them (resources are hardcoded in WorkflowTemplate)
3. **Stale default values**: WorkflowTemplate default for `models` is `BLINK,FarmCPU` while workflows use `BLINK,FarmCPU,MLM`
4. **Missing env vars in parallel pipeline**: `validate` template in parallel pipeline doesn't set `ACCESSION_IDS_FILE` env var (test pipeline has it)
5. **Comment inaccuracies**: Comments reference "184 traits" when actual range is 186 traits (2-187)

These issues lead to:
- Operator confusion when parameter changes don't take effect
- Debugging difficulty when displayed values don't match actual behavior
- Maintenance burden keeping multiple sources in sync

## What Changes

- **BREAKING**: Remove unused parameters (`cpu-cores`, `memory-gb`, `max-parallelism`) from workflow files
- **BREAKING**: Remove `--cpu` and `--memory` flags from `submit_workflow.sh` (they never worked)
- Update WorkflowTemplate default `models` to `BLINK,FarmCPU,MLM`
- Add missing `ACCESSION_IDS_FILE` env var to parallel pipeline validate template
- Fix comment inaccuracies (184 → 186 traits)
- Update README.md to remove references to unused parameters
- Add documentation comments explaining where resources are actually configured

## Impact

- Affected specs: `openspec/specs/argo-workflow-configuration/spec.md` (to be created)
- Affected code:
  - `cluster/argo/workflows/gapit3-parallel-pipeline.yaml`
  - `cluster/argo/workflows/gapit3-test-pipeline.yaml`
  - `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`
  - `cluster/argo/scripts/submit_workflow.sh`
  - `cluster/argo/README.md`
