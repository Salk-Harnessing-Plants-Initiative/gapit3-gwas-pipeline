## Why

The GAPIT3 pipeline has a design flaw where runtime parameters (like `MODELS`) are passed to containers via **both** CLI arguments and environment variables, but the entrypoint only reads environment variables. This caused a production bug where `--models BLINK,FarmCPU,MLM` was ignored because the entrypoint read `MODELS` env var which had a different default value.

This dual-path design creates:
1. **Silent failures** - CLI args appear to work but are ignored
2. **Confusion** - Developers don't know which mechanism is authoritative
3. **Maintenance burden** - Two places to update when adding parameters
4. **Testing gaps** - Hard to test all parameter passing paths

## What Changes

- **BREAKING**: Remove CLI argument passing from Argo WorkflowTemplate container args
- Consolidate all parameter passing to environment variables only
- Update documentation to clarify the single source of truth
- Remove dead code paths in entrypoint that parse CLI arguments

## Impact

- Affected specs: `openspec/specs/argo-workflow-configuration/spec.md` (new)
- Affected code:
  - `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`
  - `cluster/argo/workflows/gapit3-parallel-pipeline.yaml`
  - `cluster/argo/workflows/gapit3-test-pipeline.yaml`
  - `scripts/entrypoint.sh` (documentation only, logic already correct)
