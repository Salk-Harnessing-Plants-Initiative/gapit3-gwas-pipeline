# Add RunAI CLI v2 Skill and Update Documentation

## Why

The RunAI CLI v2 introduces breaking changes from v1, including new command structure (`workspace` and `workload` subcommands) and different flag syntax (`--cpu-core-request` vs `--cpu`, new `--host-path` syntax). The codebase currently contains:

- 4 documentation files with outdated v1 command syntax
- 2 Claude command files with v1 syntax that will fail on v2 CLI
- No centralized Claude skill for RunAI CLI assistance

This creates confusion for users, leads to command failures, and makes it difficult to maintain consistency across documentation. Users must manually reference the quick reference guide and translate commands, slowing down development workflows.

## What Changes

**NEW: Claude Skill for RunAI v2**
- Create `.claude/skills/runai/` directory with RunAI v2 CLI skill
- Add `skill.md` with comprehensive v2 command reference, flag documentation, and v1→v2 migration guide
- Add `examples.md` with real-world GAPIT3 pipeline usage patterns

**UPDATE: Documentation Files (4 files)**
- `docs/MANUAL_RUNAI_EXECUTION.md` - Replace all v1 commands with v2 syntax (~40 command updates across 7 sections)
- `docs/DEMO_COMMANDS.md` - Update quick reference commands (~10 updates)
- `docs/QUICK_DEMO.md` - Update demo workflow commands (~8 updates)
- `docs/DEPLOYMENT_TESTING.md` - Update troubleshooting commands (~5 updates)

**UPDATE: Claude Commands (2 files)**
- `.claude/commands/monitor-jobs.md` - Replace v1 with v2 syntax (~15 command updates)
- `.claude/commands/cleanup-jobs.md` - Replace v1 with v2 syntax (~10 command updates)

**VERIFIED: Shell Scripts**
- All 6 shell scripts already use v2 syntax correctly (no changes needed)

**REFERENCE SOURCE**
- `docs/RUNAI_QUICK_REFERENCE.md` serves as the authoritative v2 syntax reference

## Impact

**Affected specs:**
- New capability: `claude-skills` (RunAI v2 CLI assistance)

**Affected code:**
- 4 documentation files in `docs/`
- 2 Claude command files in `.claude/commands/`
- New skill files in `.claude/skills/runai/`

**User Benefits:**
- Consistent, correct v2 command syntax across all documentation
- Claude skill provides real-time assistance with RunAI commands
- Reduced errors from using deprecated v1 syntax
- Faster onboarding for new users
- Future-proofed documentation

**Non-breaking:** This is a documentation-only update. No code changes to scripts, workflows, or container images.
