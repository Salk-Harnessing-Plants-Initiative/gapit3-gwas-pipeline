## Why

Users need to validate GWAS input data before submitting jobs. Currently there's no Claude command for data validation, and the `MANUAL_RUNAI_EXECUTION.md` documentation references the deprecated `--config /config/config.yaml` flag which no longer exists after removing config.yaml. Additionally, several docs incorrectly reference RBAC issues as a "current blocker" which has been resolved.

## What Changes

- Add `/validate-data` Claude command for comprehensive data validation per `docs/DATA_REQUIREMENTS.md`
- Add `/submit-runai-test` Claude command for submitting test jobs to RunAI using correct `runai workspace submit` syntax
- Update `docs/MANUAL_RUNAI_EXECUTION.md` to remove deprecated `--config` flag references
- Update docs to reflect that Argo RBAC issues have been resolved

## Impact

- Affected specs: `claude-commands`
- Affected code:
  - `.claude/commands/validate-data.md` (new file)
  - `.claude/commands/submit-runai-test.md` (new file)
  - `docs/MANUAL_RUNAI_EXECUTION.md` (remove `--config` flag)
  - `docs/WORKFLOW_ARCHITECTURE.md` (update RBAC status)
  - `docs/DEPLOYMENT_TESTING.md` (update RBAC status)
  - `docs/DEMO_COMMANDS.md` (update RBAC status)
- Backward compatible: Existing commands continue to work
