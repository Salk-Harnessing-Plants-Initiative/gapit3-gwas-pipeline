# Tasks: Update Argo Workflows and Skills for v3.0.0

## Phase 1: Argo Workflow Updates

### 1.1 Update gapit3-test-pipeline.yaml
- [x] Change parameter `models` → `model` in all task arguments
- [x] Add parameterized file paths:
  - `genotype-file` parameter (default: current hardcoded path)
  - `phenotype-file` parameter (default: current hardcoded path)
  - `accession-ids-file` parameter (default: current hardcoded path)
- [x] Update image tag to `sha-539fe5c-test`
- [x] Pass file path parameters to WorkflowTemplate calls (genotype-file, phenotype-file, accession-ids-file)
- [x] Update inline validate/extract-traits templates to use parameters
- [x] YAML syntax validated

### 1.2 Update gapit3-parallel-pipeline.yaml
- [x] Change parameter `models` → `model`
- [x] Change task argument `models` → `model`
- [x] Add parameterized file paths (same as test-pipeline)
- [x] Pass file path parameters to WorkflowTemplate calls
- [x] Update image tag to `sha-539fe5c-test`
- [x] YAML syntax validated

### 1.3 Update WorkflowTemplates
- [x] `gapit3-single-trait-template.yaml` - Already uses v3.0.0 naming
- [x] `gapit3-single-trait-template-highmem.yaml` - Already uses v3.0.0 naming
- [x] Update default image tags to `sha-539fe5c-test`
- [x] Add file path parameters (genotype-file, phenotype-file, accession-ids-file)
- [x] Update env section to use parameterized file paths from inputs

## Phase 2: RunAI Template Updates

### 2.1 Update runai-job-template.yaml
- [x] Change `MODELS` → `MODEL`
- [x] Change `PCA_COMPONENTS` → `PCA_TOTAL`
- [x] Add `SNP_MAF`, `SNP_FDR`, `SNP_THRESHOLD` env vars
- [x] Add `KINSHIP_ALGORITHM`, `SNP_EFFECT`, `SNP_IMPUTE` env vars
- [x] Update comments to reference v3.0.0 naming

## Phase 3: Validation Script Updates

### 3.1 Update validate-env.sh
- [x] Add support for v3.0.0 names: `MODEL`, `PCA_TOTAL`, `SNP_MAF`
- [x] Add deprecation warnings for old names: `MODELS`, `PCA_COMPONENTS`, `MAF_FILTER`
- [x] Update `check_environment_file()` required_vars list
- [x] Update `check_gapit_parameters()` to check both old and new names
- [x] Update `check_cluster_paths()` to use DATA_PATH/OUTPUT_PATH with fallback
- [x] Update `check_data_files()` and `check_phenotype_structure()` to use v3.0.0 paths
- [x] Keep backwards compatibility (accept either)
- [ ] Test with both old and new .env file formats (requires manual test)

## Phase 4: Claude Skills Documentation

### 4.1 Update submit-runai-test.md
- [x] Change `--environment MODELS=` → `--environment MODEL=`
- [x] Change `--environment PCA_COMPONENTS=` → `--environment PCA_TOTAL=`
- [x] Change `--environment MAF_FILTER=` → `--environment SNP_MAF=`
- [x] Add new parameters: `KINSHIP_ALGORITHM`, `SNP_EFFECT`, `SNP_IMPUTE`
- [x] Update example commands

### 4.2 Update docker-test.md
- [x] Change `-e MODELS=` → `-e MODEL=`
- [x] Change `-e PCA_COMPONENTS=` → `-e PCA_TOTAL=`
- [x] Update grep pattern in environment test
- [x] Add examples with new parameters

### 4.3 Update submit-test-workflow.md (if exists)
- [x] N/A - File does not require changes (parameters passed via CLI)

## Phase 5: Documentation Updates

### 5.1 Update cluster/argo/README.md
- [x] Change `models` → `model` in parameter tables
- [x] Add new parameters to documentation
- [x] Update image tag references
- [x] Add parameterized file path documentation

## Phase 6: Validation

### 6.1 Syntax Validation
- [x] Validate all workflow YAML files with Python yaml.safe_load
- [ ] Run shellcheck on validate-env.sh (optional, requires shellcheck)

### 6.2 Functional Validation
- [ ] Test validate-env.sh with old .env format (expect warnings)
- [ ] Test validate-env.sh with new .env format (expect clean pass)
- [ ] Submit test workflow with v3.0.0 parameters
- [ ] Verify correct parameters are passed to container

## File Change Summary

| File | Phase | Changes |
|------|-------|---------|
| `cluster/argo/workflows/gapit3-test-pipeline.yaml` | 1.1 | Parameter rename, add file path params, pass to templateRef |
| `cluster/argo/workflows/gapit3-parallel-pipeline.yaml` | 1.2 | Parameter rename, add file path params, pass to templateRef |
| `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml` | 1.3 | Add file path params, parameterize env, update image tag |
| `cluster/argo/workflow-templates/gapit3-single-trait-template-highmem.yaml` | 1.3 | Add file path params, parameterize env, update image tag |
| `cluster/runai-job-template.yaml` | 2.1 | Env var rename, add new vars |
| `scripts/validate-env.sh` | 3.1 | Support both naming conventions |
| `.claude/commands/submit-runai-test.md` | 4.1 | Documentation update |
| `.claude/commands/docker-test.md` | 4.2 | Documentation update |
| `cluster/argo/README.md` | 5.1 | Documentation update |

## Dependencies

- Requires `expose-gapit-parameters` change to be complete (already done)
- Unblocks `run-elohim-iron-gwas` (can now submit test workflow)
