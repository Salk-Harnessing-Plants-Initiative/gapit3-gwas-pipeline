# OpenSpec Change Proposal: Add Workflow Manager Command

## Why

Managing GWAS pipeline workflows requires multiple manual steps: monitoring progress, identifying failures (OOM, stuck pods, timeouts), stopping stalled workloads, cleaning up incomplete outputs, generating retry workflows with correct parameters, and finally running aggregation. This currently requires:

1. Manually running `argo get` to check status
2. Identifying which traits failed and why (OOMKilled vs stuck vs timeout)
3. Running `argo stop` on stalled workflows
4. Manually cleaning incomplete output directories
5. Running `retry-argo-traits.sh` with correct flags (`--highmem` for OOM, `--aggregate`)
6. Monitoring retry workflow until completion

This is error-prone, time-consuming, and requires domain knowledge of failure patterns.

## What Changes

### Add `/manage-workflow` Claude Code Slash Command

A comprehensive slash command that automates the entire workflow management cycle:

1. **Assess** - Monitor workflow status, categorize failures (OOM, stuck, timeout, other)
2. **Report** - Display human-readable summary with recommended actions
3. **Cleanup** - Stop stalled workloads, clean incomplete output directories (with confirmation)
4. **Retry** - Generate and submit retry workflow with intelligent parameter selection
5. **Monitor** - Continuously track retry progress until completion
6. **Aggregate** - Ensure results are aggregated (built into retry workflow)

### Features

- **Intelligent failure categorization**: Distinguishes OOMKilled (needs high-memory), stuck pods (PodInitializing > 10min), timeouts, and other errors
- **Parameter propagation**: Automatically extracts and propagates `snp-fdr`, `models`, paths from original workflow
- **Memory scaling**: Uses high-memory template (96Gi/16 CPU) for OOM-failed traits
- **Safe operations**: Confirms before destructive actions, supports dry-run mode
- **Progress tracking**: Real-time status updates during retry monitoring

### Usage Modes

1. **Interactive** (default): Claude asks for confirmation at each step
2. **Automated**: With `--auto` flag, proceeds without confirmation (for scripting)
3. **Dry-run**: With `--dry-run`, shows what would be done without executing

## Impact

- Affected specs: `slash-commands` (new capability)
- Affected code:
  - `.claude/commands/manage-workflow.md` (new)
  - Leverages existing: `scripts/retry-argo-traits.sh`
- Dependencies: `argo` CLI, `kubectl`, `jq`
- Backward compatible: New command, no changes to existing functionality

## Risk Assessment

- **Low Risk**: Read-only operations (monitoring, assessment) have no side effects
- **Medium Risk**: Cleanup operations require confirmation and support dry-run
- **Low Risk**: Retry submission uses tested `retry-argo-traits.sh` script

## Stakeholders

- Pipeline users running GWAS analyses
- Operators managing cluster workloads
- CI/CD automation (automated mode)
