# Changelog

All notable changes to the GAPIT3 GWAS Pipeline will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Results Aggregation Model Tracking** - Enhanced aggregation script to track which GAPIT model identified each SNP
  - `scripts/collect_results.R` now reads GAPIT Filter files instead of complete GWAS_Results files (500× performance improvement)
  - Model information parsed from `traits` column format: `"MODEL.TraitName"`
  - Output CSV includes `model` column for filtering and comparison
  - Per-model summary statistics show SNP counts and overlaps
  - Test fixtures and unit tests for aggregation functionality
  - Performance: <30 seconds for 186 traits (previously 5-10 minutes)
- **Runtime Configuration via Environment Variables** - Major enhancement allowing container reconfiguration without rebuilds
  - `.env.example` - Comprehensive documentation of all runtime configuration options
  - Environment variable support in entrypoint.sh with validation
  - All GAPIT parameters (models, PCA, thresholds) now configurable at runtime
  - Works with Docker `--env-file`, RunAI `--environment`, and Argo `env:` specifications
- Manual RunAI execution scripts as workaround for RBAC permissions
  - `scripts/submit-all-traits-runai.sh` - Batch submission with concurrency control (updated with runtime config support)
  - `scripts/monitor-runai-jobs.sh` - Live monitoring dashboard
  - `scripts/aggregate-runai-results.sh` - Automatic results aggregation
  - `scripts/cleanup-runai.sh` - Cleanup helper for workspaces and output files
- Comprehensive documentation for RunAI CLI execution
  - `docs/MANUAL_RUNAI_EXECUTION.md` - Complete execution guide
  - `docs/RUNAI_QUICK_REFERENCE.md` - Command cheat sheet
  - `docs/RBAC_PERMISSIONS_ISSUE.md` - Administrator information
- Technical architecture documentation
  - `docs/WORKFLOW_ARCHITECTURE.md` - Deep dive into workflow design
  - `cluster/argo/README.md` - Directory structure guide
- OpenSpec change proposals
  - `openspec/changes/fix-argo-workflow-validation/` - Workflow validation fix
  - `openspec/changes/add-runai-aggregation-script/` - Aggregation automation
  - `openspec/changes/add-cleanup-script/` - Cleanup helper script
  - `openspec/changes/add-dotenv-configuration/` - Runtime configuration proposal

### Fixed
- **Performance**: Eliminated unnecessary GWAS_Results fallback for empty Filter files
  - Filter files without `traits` column now return empty immediately (no significant SNPs)
  - Prevents reading 1.4M row files when Filter already indicates no results
  - For datasets with ~30 empty traits: reduces aggregation time from minutes to seconds
  - Performance improvement: 100-1000× faster for traits with no significant SNPs
  - No breaking changes - output identical, just generated faster
- **Critical**: Argo Workflows validation error with parameterized volumes ([#10](https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/pull/10))
  - Moved volume definitions from WorkflowTemplate to Workflow level
  - Changed resources from parameterized to fixed values
  - Workflows now submit successfully without validation errors
- Project name in RunAI scripts changed from `runai-talmo-lab` to `talmo-lab`
- Updated RunAI CLI syntax to new version (workspace commands)

### Changed
- **BREAKING: Aggregated results CSV format updated** - New `model` column added to track which GAPIT model found each SNP
  - Output filename: `significant_snps.csv` → `all_traits_significant_snps.csv`
  - Column order: `SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model`
  - SNPs found by multiple models now appear as separate rows
  - Users should re-run aggregation on existing results to get model information
- **Container now runtime-configurable** - No longer requires config.yaml or image rebuilds for parameter changes
  - Updated `scripts/entrypoint.sh` to read and validate environment variables
  - Updated `scripts/run_gwas_single_trait.R` to accept command-line arguments with env var fallbacks
  - Updated `Dockerfile` to remove hardcoded runtime configuration (thread counts moved to runtime)
  - Updated `scripts/submit-all-traits-runai.sh` to pass all GAPIT parameters as environment variables
  - Removed `yaml` R package dependency (no longer needed)
- Updated README.md with runtime configuration section and examples
- Updated README.md with current status and workaround documentation links
- Updated QUICKSTART.md with RBAC warning and RunAI instructions
- Updated docs/ARGO_SETUP.md with workflow validation fix section
- Updated docs/DEPLOYMENT_TESTING.md with latest test results (2025-11-07)

### Deprecated
- `config/config.yaml` - Configuration now via environment variables (file kept for backward compatibility but not used by new entrypoint)

### Documented
- Workflow validation fix root cause and solution
- RBAC permissions issue blocking Argo execution
- Successful single-trait test with RunAI CLI
- RunAI CLI syntax migration (old vs. new commands)

---

## [0.1.0] - 2025-11-07

### Added
- Initial release of GAPIT3 GWAS Pipeline
- Dockerized GAPIT3 environment with R 4.3.1
- Argo Workflows templates for parallel GWAS execution
  - `gapit3-single-trait-template.yaml` - Single trait analysis
  - `trait-extractor-template.yaml` - Trait manifest generation
  - `results-collector-template.yaml` - Results aggregation
- Test and production workflows
  - `gapit3-test-pipeline.yaml` - 3-trait validation workflow
  - `gapit3-parallel-pipeline.yaml` - Full 186-trait pipeline
- Core R scripts
  - `run_gwas_single_trait.R` - GAPIT3 GWAS analysis
  - `collect_results.R` - Results aggregation
  - `validate_inputs.R` - Input file validation
  - `extract_trait_names.R` - Phenotype parsing
- Helper scripts
  - `scripts/submit_workflow.sh` - Simplified workflow submission
  - `scripts/monitor_workflow.sh` - Live workflow monitoring
  - `entrypoint.sh` - Container entry point
- GitHub Actions CI workflows
  - Docker build and publish to GHCR
  - R script unit tests with testthat
  - Devcontainer functionality tests
- VSCode devcontainer configuration for local development
- Comprehensive documentation
  - README.md - Overview and quick start
  - QUICKSTART.md - Non-technical user guide
  - docs/ARGO_SETUP.md - Cluster deployment guide
  - docs/USAGE.md - Parameter reference
  - docs/DATA_DICTIONARY.md - Trait descriptions
  - docs/DEPLOYMENT_TESTING.md - Testing guide
  - docs/TESTING.md - Test suite documentation
- OpenSpec project structure and conventions

### Features
- Parallel execution of 186 traits with configurable concurrency (max 50)
- Multi-model support: BLINK and FarmCPU
- FAIR-compliant metadata tracking with checksums and provenance
- Optimized performance with multi-threaded OpenBLAS
- Automatic results aggregation with significant SNP identification
- Retry strategies for transient failures
- Resource management with Kubernetes requests/limits

### Configuration
- GAPIT configuration via `config/config.yaml`
- Workflow parameters for data paths, resources, and parallelism
- Docker multi-stage build for optimized image size
- R package caching for faster builds

---

## Release Notes

### [Unreleased] - Current Development

This release focuses on resolving deployment blockers and providing workarounds:

**Key Changes**:
1. **Workflow Validation Fix**: Resolved critical Argo validation error that prevented workflow submission
2. **RBAC Workaround**: Created manual RunAI execution path while waiting for permissions
3. **Documentation Overhaul**: Added comprehensive guides for current execution methods
4. **Testing Validation**: Successfully tested single-trait execution end-to-end

**Status**:
- ✅ Pipeline functionality: Fully working
- ✅ Docker image: Built and tested
- ✅ R scripts: All tests passing
- ✅ Manual RunAI execution: Working
- ⏳ Argo orchestration: Blocked by RBAC permissions (administrator action required)

**Next Steps**:
- Waiting for cluster administrator to grant RBAC permissions
- Once resolved, full Argo orchestration will work automatically
- No code changes required after RBAC fix

### [0.1.0] - Initial Release

First functional release of the GAPIT3 GWAS Pipeline with:
- Complete Dockerized environment
- Argo Workflows orchestration
- Parallel execution capabilities
- Comprehensive test suite
- Full documentation

**Validated on**:
- 546 Arabidopsis thaliana accessions
- ~1.4 million SNPs
- 186 iron-related traits
- Salk Institute HPI cluster with RunAI

---

## Migration Guide

### From Manual R Scripts to Dockerized Pipeline

If migrating from manual GAPIT3 execution:

1. **Data Preparation**:
   - Place genotype file in `data/genotype/`
   - Place phenotype file in `data/phenotype/`
   - Ensure phenotype file has "Taxa" column

2. **Configuration**:
   - Copy your GAPIT parameters to `config/config.yaml`
   - Update model selection: `models: [BLINK, FarmCPU]`

3. **Execution**:
   - Test single trait: `docker run ... run-single-trait --trait-index 2`
   - Run all traits: See [MANUAL_RUNAI_EXECUTION.md](docs/MANUAL_RUNAI_EXECUTION.md)

### Workflow Validation Fix Migration

If using old workflow templates with parameterized volumes:

**Breaking Change**: Volume configuration must be at workflow level

**Before (BROKEN)**:
```yaml
# In WorkflowTemplate
volumes:
- name: nfs-data
  hostPath:
    path: "{{inputs.parameters.data-hostpath}}"
```

**After (WORKING)**:
```yaml
# In Workflow
spec:
  volumes:
  - name: nfs-data
    hostPath:
      path: "{{workflow.parameters.data-hostpath}}"

# In WorkflowTemplate
volumeMounts:
- name: nfs-data
  mountPath: /data
```

**Action Required**: Update custom workflows to use new volume pattern

---

## Known Issues

### RBAC Permissions (High Priority)
**Issue**: Argo Workflows cannot create `workflowtaskresults` due to missing service account permissions

**Impact**: Workflows submit successfully but fail at runtime with exit code 64

**Status**: Waiting for cluster administrator

**Workaround**: Use manual RunAI execution (see [MANUAL_RUNAI_EXECUTION.md](docs/MANUAL_RUNAI_EXECUTION.md))

**Tracking**: See [RBAC_PERMISSIONS_ISSUE.md](docs/RBAC_PERMISSIONS_ISSUE.md)

### RunAI CLI Syntax Changes
**Issue**: RunAI CLI updated with breaking syntax changes

**Impact**: Old `runai submit` commands no longer work

**Solution**: Use new syntax: `runai workspace submit` (see [RUNAI_QUICK_REFERENCE.md](docs/RUNAI_QUICK_REFERENCE.md))

**Status**: Resolved in this release

---

## Versioning Strategy

- **Major version (X.0.0)**: Breaking changes to workflow templates or R script interfaces
- **Minor version (0.X.0)**: New features, non-breaking enhancements
- **Patch version (0.0.X)**: Bug fixes, documentation updates

---

## Links

- **Repository**: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline
- **Issues**: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/issues
- **Pull Requests**: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/pulls
- **Docker Image**: https://ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline

---

**Maintained by**: Salk Institute Harnessing Plants Initiative

**License**: MIT
