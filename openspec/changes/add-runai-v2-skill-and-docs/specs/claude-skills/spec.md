# Claude Skills Specification

## ADDED Requirements

### Requirement: RunAI CLI v2 Skill

The system SHALL provide a Claude skill for RunAI CLI v2 assistance located at `.claude/skills/runai/`.

#### Scenario: Skill provides v2 command reference

- **WHEN** a user needs RunAI v2 command syntax
- **THEN** the skill SHALL document all v2 commands including:
  - `runai workspace submit` for job submission
  - `runai workspace list` for listing workspaces
  - `runai workspace describe` for workspace details
  - `runai workload logs workspace` for viewing logs
  - `runai workload delete workspace` for deletion
  - `runai exec` for interactive shell access

#### Scenario: Skill documents v2 flag syntax

- **WHEN** a user needs to specify resources or mounts
- **THEN** the skill SHALL document v2-specific flags:
  - `--cpu-core-request` instead of deprecated `--cpu`
  - `--cpu-memory-request` instead of deprecated `--memory`
  - `--host-path path=/src,mount=/dst,mount-propagation=HostToContainer` syntax instead of `--host-path /src:/dst:ro`
  - `--project` with correct namespace name (e.g., `talmo-lab` without `runai-` prefix)

#### Scenario: Skill provides GAPIT3 pipeline usage patterns

- **WHEN** a user needs to perform RunAI tasks for GAPIT3 pipeline
- **THEN** the skill SHALL include examples for:
  - Submitting GAPIT3 trait workspaces with appropriate resource requests
  - Monitoring workspace status and progress with filters
  - Viewing logs with `--follow` flag for real-time updates
  - Cleaning up completed workspaces by status
  - Batch operations across multiple workspaces

#### Scenario: Skill includes v1 to v2 migration guide

- **WHEN** a user encounters v1 syntax in legacy documentation
- **THEN** the skill SHALL provide a translation table mapping:
  - v1 commands to v2 equivalents (e.g., `runai submit` → `runai workspace submit`)
  - v1 flags to v2 flags (e.g., `--cpu 12` → `--cpu-core-request 12`)
  - v1 syntax patterns to v2 patterns (e.g., `--host-path /path:/mount:ro` → `--host-path path=/path,mount=/mount,mount-propagation=HostToContainer`)

### Requirement: Skill File Organization

The skill SHALL be organized in `.claude/skills/runai/` with the following structure.

#### Scenario: Primary skill documentation

- **WHEN** accessing the skill
- **THEN** `skill.md` SHALL contain:
  - Command reference for all v2 commands (workspace, workload, exec)
  - Flag syntax documentation with examples
  - Common patterns and best practices for GAPIT3 workflows
  - v1 to v2 migration guide with translation table

#### Scenario: Practical examples

- **WHEN** accessing skill examples
- **THEN** `examples.md` SHALL contain:
  - Real-world command examples from the GAPIT3 pipeline
  - Multi-step workflows (submit, monitor, cleanup)
  - Error handling patterns for common issues
  - Troubleshooting commands for failed workspaces
