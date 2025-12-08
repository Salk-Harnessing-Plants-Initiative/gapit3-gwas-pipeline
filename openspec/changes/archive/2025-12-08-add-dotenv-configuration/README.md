# Add Runtime Configuration via Environment Variables

## Summary

Make the GAPIT3 Docker container runtime-configurable through environment variables instead of requiring rebuilds for parameter changes. Add `.env.example` to document all available runtime options for local development.

## Status

**Phase**: Proposal
**Created**: 2025-11-09
**Author**: Claude Code (via user request)

## Quick Links

- [Proposal](proposal.md) - Problem statement and solution
- [Design](design.md) - Technical implementation details
- [Tasks](tasks.md) - Step-by-step implementation guide

## Problem

The container currently requires **rebuilding** to change GAPIT parameters (models, PCA components, thresholds). This is:
- ❌ Slow (10-30 min rebuild + push cycle)
- ❌ Inflexible (can't A/B test parameters easily)
- ❌ Error-prone (hard to track which image has which config)

## Solution

**Runtime configuration via environment variables:**

```bash
# Before: Must rebuild image to change models
docker build --build-arg MODELS=BLINK .  # 10+ minutes

# After: Pass at runtime
docker run --env MODELS=BLINK gapit3:latest  # Instant

# RunAI
runai workspace submit job \
  --environment MODELS=BLINK \
  --environment PCA_COMPONENTS=5

# Argo (future)
env:
  - name: MODELS
    value: "BLINK,FarmCPU"
```

## Scope

**In Scope:**
- `.env.example` - Document all runtime configuration options
- Update `scripts/entrypoint.sh` - Read env vars, pass to R
- Update R scripts - Accept parameters from environment
- Remove `config/config.yaml` - Migrate to ENV pattern
- Validation - Check env vars for valid values/ranges
- Documentation - Update guides with env var examples

**Out of Scope:**
- Deployment configuration (RunAI project, data paths) - That's infrastructure
- Build-time settings (OS packages, R version) - Stays in Dockerfile
- Multi-container orchestration - Single container focus

## Timeline

**Estimated**: 6-7 hours

1. Container runtime updates: 3-4 hours
2. Documentation: 1 hour
3. RunAI script integration: 1 hour
4. Testing: 1 hour

## Dependencies

- R `optparse` package (already installed)
- Bash environment variable support (standard)
- Compatible with current RunAI and future Argo deployments

## Success Criteria

- [x] Can change MODELS without rebuilding image
- [x] Can change PCA_COMPONENTS at runtime
- [x] Can change SNP_THRESHOLD at runtime
- [x] `.env.example` documents all options clearly
- [x] Container validates env vars with helpful errors
- [x] Works with RunAI `--environment` flags
- [x] Works with Argo `env:` specifications
- [x] Backward compatible (defaults when vars not set)

## Related Changes

- Complements [add-runai-aggregation-script](../add-runai-aggregation-script/) - Aggregation also configurable
- Enables [future Argo integration](../fix-argo-workflow-validation/) - Same runtime config for both

## Notes

- `.env` file is for **local development only** (docker run --env-file)
- Production uses RunAI `--environment` or Argo `env:` specifications
- `.env` is gitignored - never commit actual configuration
- `.env.example` is tracked - serves as documentation
