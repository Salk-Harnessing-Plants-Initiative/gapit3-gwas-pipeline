## Why

When running large-scale GWAS analysis via Argo Workflows, some traits fail due to:
1. **OOM (Out of Memory)** - MLM model requires more memory than allocated for certain traits
2. **Timeout** - MLM convergence takes longer than workflow deadline for some traits
3. **Transient failures** - Node issues, network problems (already handled by built-in retry)

Currently, there is no Argo-specific retry mechanism. The existing `bulk-resubmit-traits.sh` and `retry-failed-traits.sh` scripts only work with RunAI. Users must manually:
1. Identify failed traits from `argo get` output
2. Create a new workflow YAML with hardcoded trait list
3. Potentially increase memory for OOM failures
4. Submit and monitor the new workflow

This is error-prone and time-consuming, especially when dealing with many failed traits.

## What Changes

- **Add** `scripts/retry-argo-traits.sh` - Shell script to retry failed Argo workflow traits
- **Add** `cluster/argo/workflows/gapit3-retry-template.yaml` - Reusable workflow template for retrying specific traits
- **Add** Support for memory override parameter when retrying OOM-failed traits
- **Add** Integration with existing aggregation workflow

### Features
- Auto-detect failed traits from a completed workflow
- Support manual trait list specification
- Memory scaling option for OOM failures (e.g., `--memory 96Gi`)
- Dry-run mode for validation
- Post-completion aggregation trigger option

## Impact

- Affected specs: `openspec/specs/argo-workflow-configuration/spec.md` (to be created)
- Affected code:
  - `scripts/retry-argo-traits.sh` (new)
  - `cluster/argo/workflows/gapit3-retry-template.yaml` (new)
  - `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml` (may need memory parameter)
  - `cluster/argo/README.md` (documentation)
