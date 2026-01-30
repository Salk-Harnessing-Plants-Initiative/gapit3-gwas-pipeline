# Implementation Tasks

## 1. Create Claude RunAI v2 Skill

- [x] 1.1 Create `.claude/skills/runai/` directory
- [x] 1.2 Create `skill.md` with comprehensive v2 command reference
  - [x] Document workspace commands (submit, list, describe, exec)
  - [x] Document workspace management commands (logs, delete)
  - [x] Include all v2 flags (cpu-core-request, cpu-memory-request, host-path syntax)
  - [x] Add v1 to v2 migration table
  - [x] Include common patterns (submit, monitor, cleanup workflows)
- [x] 1.3 Create `examples.md` with GAPIT3-specific usage examples
  - [x] Example: Submit single trait workspace
  - [x] Example: Monitor workspace status and logs
  - [x] Example: Delete completed workspaces
  - [x] Example: Batch operations with shell loops
  - [x] Example: Troubleshooting failed workspaces

## 2. Update Documentation Files

- [x] 2.1 Update `docs/MANUAL_RUNAI_EXECUTION.md`
  - [x] Section "Validation step" (lines 52-71): Update list and describe commands
  - [x] Section "Single trait test" (lines 79-105): Update submit commands with v2 flags
  - [x] Section "Multiple traits" (lines 129-170): Update submit commands with v2 flags
  - [x] Section "Batch submission" (lines 194-226): Update script examples
  - [x] Section "Monitoring" (lines 238-258): Update list, describe, logs commands
  - [x] Section "Cleanup" (lines 482-492): Update delete commands
  - [x] Section "Troubleshooting" (lines 500-530): Update all diagnostic commands
- [x] 2.2 Update `docs/DEMO_COMMANDS.md`
  - [x] Line 17: Replace `runai list jobs` with `runai workspace list`
  - [x] Line 100: Replace `runai list jobs` with `runai workspace list`
  - [x] Line 265: Replace `runai describe job` with `runai workspace describe`
  - [x] Line 270: Replace `runai logs` with `runai workspace logs`
- [x] 2.3 Update `docs/QUICK_DEMO.md`
  - [x] Line 29: Replace `runai list jobs` with `runai workspace list`
  - [x] Line 213: Replace `runai list jobs` with `runai workspace list`
  - [x] Line 216: Replace `runai describe job` with `runai workspace describe`
  - [x] Line 231: Replace `runai describe job` with `runai workspace describe`
- [x] 2.4 Update `docs/DEPLOYMENT_TESTING.md`
  - [x] Lines 399-400: Update resource check commands
  - [x] Line 700: Update submit command example
  - [x] Line 784: Verify v1/v2 documentation is accurate
- [x] 2.5 Update `docs/RUNAI_QUICK_REFERENCE.md`
  - [x] Fixed incorrect `runai workload logs workspace` syntax to `runai workspace logs`
  - [x] Fixed incorrect `runai workload delete workspace` syntax to `runai workspace delete`
  - [x] Updated migration table with correct v2 commands

## 3. Update Claude Commands

- [x] 3.1 Update `.claude/commands/monitor-jobs.md`
  - [x] Replace `runai list jobs` with `runai workspace list`
  - [x] Replace `runai describe job` with `runai workspace describe`
  - [x] Replace `runai logs` with `runai workspace logs`
  - [x] Update all code block examples with v2 syntax
- [x] 3.2 Update `.claude/commands/cleanup-jobs.md`
  - [x] Replace `runai list jobs` with `runai workspace list`
  - [x] Replace `runai delete job` with `runai workspace delete`
  - [x] Update all code block examples with v2 syntax

## 4. Verification and Quality Assurance

- [x] 4.1 Cross-reference all changes against `docs/RUNAI_QUICK_REFERENCE.md`
- [x] 4.2 Verify consistency of command syntax across all files
- [x] 4.3 Check that all `--project` flags use correct namespace (talmo-lab, not runai-talmo-lab)
- [x] 4.4 Verify all `--host-path` flags use new syntax (path=,mount=,mount-propagation=)
- [x] 4.5 Verify all resource flags use new names (--cpu-core-request, --cpu-memory-request)
- [x] 4.6 Confirm shell scripts already use v2 (no changes needed)

## 5. Documentation

- [x] 5.1 Update CHANGELOG.md with entry for documentation update
- [x] 5.2 Ensure all examples include project flag where applicable
- [x] 5.3 Commands verified against actual RunAI CLI v2 help output
