<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

## Path Mapping Reference

**IMPORTANT**: The user is on a Windows computer. Paths differ by context:

| Context | Base Path | Example |
|---------|-----------|---------|
| Windows (PowerShell/CMD) | `Z:\users\eberrigan\...` | `Z:\users\eberrigan\20251122_...\outputs` |
| WSL (bash) | `/mnt/hpi_dev/users/eberrigan/...` | `/mnt/hpi_dev/users/eberrigan/20251122_...\outputs` |
| GPU Cluster (Argo/RunAI) | `/hpi/hpi_dev/users/eberrigan/...` | `/hpi/hpi_dev/users/eberrigan/20251122_...\outputs` |

The `Z:` drive in Windows maps to `/mnt/hpi_dev` in WSL, which corresponds to `/hpi/hpi_dev` on the cluster.

**Current working dataset**: User-specified (check conversation context)

## GitHub CLI Workaround

The Salk organization restricts fine-grained personal access tokens with lifetimes >366 days. When `gh` commands fail with this error:

```
GraphQL: The 'Salk-Harnessing-Plants-Initiative' organization forbids access via a fine-grained personal access tokens...
```

**Fix**: Run `unset GITHUB_TOKEN` before the `gh` command to use browser-based auth instead:

```bash
unset GITHUB_TOKEN && gh pr create --title "..." --body "..."
```

## Documentation Guidelines

When writing or updating documentation:
- Use species-agnostic language ("plants and other organisms", "any species with HapMap data")
- Avoid hardcoded dataset values (trait counts, sample counts, SNP counts)
- Use ranges or "N" notation instead of specific numbers
- Link to authoritative sources (.env.example for parameters, SCRIPTS_REFERENCE.md for scripts)
- See `docs/CONTRIBUTING_DOCS.md` for full documentation standards