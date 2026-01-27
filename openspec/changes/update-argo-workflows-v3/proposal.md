# Proposal: Update Argo Workflows and Skills for v3.0.0 Parameter Naming

## Problem Statement

The `expose-gapit-parameters` change updated the pipeline to use GAPIT v3.0.0 native parameter naming (MODEL, PCA_TOTAL, SNP_MAF), but several components still use the deprecated v2.0.0 names (MODELS, PCA_COMPONENTS, MAF_FILTER):

1. **Argo Workflows** (`gapit3-test-pipeline.yaml`, `gapit3-parallel-pipeline.yaml`) pass `models` parameter but WorkflowTemplates expect `model`
2. **Claude Skills** (`.claude/commands/submit-runai-test.md`, `docker-test.md`) document old parameter names
3. **RunAI Job Template** (`cluster/runai-job-template.yaml`) uses old env var names
4. **Validation Script** (`scripts/validate-env.sh`) checks old variable names
5. **Hardcoded file paths** in Argo workflows reference old dataset locations

This causes parameter mismatches when running GWAS analyses, leading to workflows using wrong/default values.

## Proposed Solution

Update all workflow files, skills, and validation scripts to use v3.0.0 parameter naming consistently. Add parameterized file paths to make workflows dataset-agnostic.

## Scope

### In Scope
- Update Argo workflows to use v3.0.0 parameter names (`model`, `pca-total`, `snp-maf`)
- Add parameterized genotype/phenotype file paths to workflows
- Update Claude skills documentation for v3.0.0 naming
- Update `validate-env.sh` to accept both old and new names (with deprecation warnings)
- Update `runai-job-template.yaml` to v3.0.0 naming
- Update `cluster/argo/README.md` parameter documentation

### Out of Scope
- Changes to R scripts (already updated in `expose-gapit-parameters`)
- Changes to entrypoint.sh (already handles deprecation)
- New functionality beyond parameter naming alignment

## Impact Analysis

### Files to Modify
| File | Change Type | Risk |
|------|-------------|------|
| `cluster/argo/workflows/gapit3-test-pipeline.yaml` | Parameter rename + add file path params | Medium |
| `cluster/argo/workflows/gapit3-parallel-pipeline.yaml` | Parameter rename | Low |
| `cluster/runai-job-template.yaml` | Env var rename | Low |
| `.claude/commands/submit-runai-test.md` | Documentation update | Low |
| `.claude/commands/docker-test.md` | Documentation update | Low |
| `scripts/validate-env.sh` | Support both old/new names | Medium |
| `cluster/argo/README.md` | Documentation update | Low |

### Breaking Changes
- Users with existing `.env` files using old names will see deprecation warnings but scripts will continue to work (backwards compatible via entrypoint.sh fallbacks)

## Success Criteria

1. All Argo workflows use v3.0.0 parameter names
2. `argo lint` passes on all workflow files
3. Claude skills show correct v3.0.0 parameter names
4. Test workflow can be submitted with new parameter names
5. `validate-env.sh` accepts both old and new names with appropriate warnings
