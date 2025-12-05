# Add Claude Development Commands

## Why

The project currently lacks convenient slash commands for common development tasks, which slows down AI-assisted development workflows. Adding Claude commands similar to the sleap-roots-analyze reference repo will enable faster iteration on testing, validation, monitoring, and workflow management tasks specific to this GAPIT3 GWAS pipeline.

## What Changes

- Add `.claude/commands/` directory with development workflow commands
- Create commands for R script testing (`test-r.md`, `test-r-coverage.md`)
- Create commands for Docker workflow (`docker-build.md`, `docker-test.md`)
- Create commands for Argo/RunAI operations (`submit-test-workflow.md`, `monitor-jobs.md`, `aggregate-results.md`, `cleanup-jobs.md`)
- Create commands for validation and linting (`validate-bash.md`, `validate-yaml.md`, `validate-r.md`)
- Create command for PR review (`review-pr.md`) with planning mode, ultrathink, reading PR comments, and posting reviews via gh CLI
- Create command for PR description generation (`pr-description.md`)
- Create command for updating CHANGELOG (`update-changelog.md`)
- OpenSpec commands already exist (`.claude/commands/openspec/*`)

## Impact

**Affected specs:**
- New capability: `claude-commands` (developer experience tooling)

**Affected code:**
- New directory: `.claude/commands/` (already exists with openspec subdirectory)
- New files: 11+ markdown command files
- No changes to existing code or scripts

**User Benefits:**
- Faster test execution with single slash commands
- Comprehensive PR reviews using planning mode and ultrathink
- Automated PR comment reading and response posting via gh CLI
- Reduced context switching between docs and CLI
- Consistent command patterns across development tasks
- Easier onboarding for new contributors
- Better integration with Claude Code assistant

**Non-breaking:** All changes are additive (new documentation only).