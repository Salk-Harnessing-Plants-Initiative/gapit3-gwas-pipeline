## Context

The GAPIT3 GWAS pipeline runs containerized R workloads on Kubernetes via Argo Workflows. Runtime configuration (trait index, models, file paths) must be passed from the workflow definition to the container.

### Current State (Problematic)

The WorkflowTemplate passes parameters two ways:

1. **CLI Arguments** (in `container.args`):
```yaml
args:
  - "run-single-trait"
  - "--trait-index"
  - "{{inputs.parameters.trait-index}}"
  - "--models"
  - "{{inputs.parameters.models}}"
  - "--threads"
  - "12"
```

2. **Environment Variables** (in `container.env`):
```yaml
env:
- name: TRAIT_INDEX
  value: "{{inputs.parameters.trait-index}}"
- name: MODELS
  value: "{{inputs.parameters.models}}"
- name: OPENBLAS_NUM_THREADS
  value: "12"
```

### The Bug

The `entrypoint.sh` script ignores CLI arguments and only reads environment variables:

```bash
# entrypoint.sh reads from env vars with defaults
MODELS="${MODELS:-BLINK,FarmCPU}"
TRAIT_INDEX="${TRAIT_INDEX:-2}"
```

When the MODELS env var was missing from the template, the CLI arg `--models BLINK,FarmCPU,MLM` was passed but ignored, and the default `BLINK,FarmCPU` was used instead.

### Why CLI Args Were Added

Historical reasons:
1. Initial design mimicked typical CLI tool patterns
2. Developers expected CLI args to "just work"
3. No one noticed the entrypoint didn't parse them

## Goals / Non-Goals

**Goals:**
- Single, clear mechanism for parameter passing
- Eliminate silent failures from ignored parameters
- Reduce cognitive load for developers
- Make the authoritative source obvious

**Non-Goals:**
- Adding CLI argument parsing to entrypoint (adds complexity)
- Supporting both mechanisms (root cause of the bug)
- Changing the R scripts' parameter handling

## Decisions

### Decision 1: Environment Variables Only

**Choice**: Remove CLI arguments, use environment variables exclusively

**Rationale**:
1. **Already working**: Entrypoint already uses env vars correctly
2. **Kubernetes-native**: Env vars are the standard K8s configuration pattern
3. **Simpler**: One mechanism to understand and maintain
4. **Composable**: Env vars can be set from ConfigMaps, Secrets, or inline
5. **Visible**: `kubectl describe pod` shows all env vars clearly

**Alternatives Considered**:
- **Add CLI parsing**: Would require significant entrypoint changes, dual support adds complexity
- **Keep both, document carefully**: Root cause of the bug; documentation doesn't prevent mistakes

### Decision 2: Keep Minimal Container Args

**Choice**: Container args should only specify the command to run (e.g., `run-single-trait`)

**Rationale**:
- The entrypoint needs to know which mode to execute
- This is a command selector, not a parameter

### Decision 3: Document the Pattern

**Choice**: Add clear comments in templates explaining the pattern

**Rationale**:
- Future developers need to understand why CLI args aren't used
- Prevents re-introduction of the bug

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Breaking existing workflows | Only affects template; running workflows unaffected |
| Developers add CLI args back | Documentation + code review |
| Env var naming conflicts | Use prefixed names (GAPIT_*) if needed in future |

## Migration Plan

1. Remove CLI arguments from WorkflowTemplate (except command selector)
2. Verify all parameters are in env section
3. Apply updated template to cluster
4. Test with new workflow submission
5. Update documentation

**Rollback**: Revert template YAML and re-apply to cluster

## Open Questions

None - the fix is straightforward once the design decision is made.
