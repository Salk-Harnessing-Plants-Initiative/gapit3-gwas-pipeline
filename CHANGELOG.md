# Changelog

All notable changes to the GAPIT3 GWAS Pipeline will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **CI Testing Workflows** - Comprehensive GitHub Actions CI with testthat unit tests
  - 466 unit tests covering aggregation, metadata, pipeline summary, and GAPIT parameters
  - Bash script validation with shellcheck
  - Docker build and integration tests
  - R code coverage analysis support
- **Multi-Workflow Provenance Tracking** - Track when aggregated results come from multiple Argo workflows
  - `collect_workflow_stats()` function to gather per-workflow statistics
  - `is_multi_workflow()` detection for composite result sets
  - Source Workflows table in pipeline summary markdown report
  - `workflow_stats` object in summary_stats.json with per-workflow breakdown
  - Console notification when multi-workflow results detected
- **Ultra-Highmem Workflow Template** - New 160Gi memory template for large datasets
  - `gapit3-single-trait-template-ultrahighmem.yaml` for MLM with >2M SNPs
  - Documented memory requirements in RESOURCE_SIZING.md
- **Autonomous Pipeline Monitor** - Script for automated workflow monitoring
  - `scripts/autonomous-pipeline-monitor.sh` for unattended monitoring
  - Configurable check intervals and notification thresholds
- **GAPIT v3.0.0 Parameter Naming** - Updated parameter names to match GAPIT native conventions
  - `SNP.FDR` for FDR-controlled significance thresholds
  - All GAPIT parameters now use native GAPIT names
  - Backward-compatible with environment variable configuration
- **Metadata Provenance Tracking** - Pipeline summary reports with execution metadata
  - Executive summary with trait counts, SNP counts, and compute time
  - Reproducibility section with workflow UIDs and parameters
  - JSON output with full statistics for programmatic access
- **Aggregation Refactoring for Testability** - Modular design following OpenSpec TDD
  - `scripts/lib/aggregation_utils.R` with reusable utility functions
  - `scripts/lib/markdown_generator.R` for report generation
  - Clear separation of concerns for easier testing
- **GitHub Issue Templates** - Structured templates for workflow improvements
- **OpenSpec Proposals** - Documented change proposals for future work
  - `add-autonomous-pipeline-monitor/` - Automated monitoring proposal
  - `add-ultra-highmem-template/` - High memory template proposal
  - `update-argo-workflows-v3/` - Argo v3 migration proposal
  - `improve-multi-workflow-provenance/` - Multi-workflow tracking (implemented)

### Fixed
- **V1 Column Type Mismatch** - Fixed `bind_rows()` error when combining Filter files
  - Root cause: Mixed row index types (numeric vs X-prefixed) across different GAPIT runs
  - Fix: Drop V1 column after `fread()` since it's just a row index not needed for analysis
  - Affected aggregation of results from multiple workflow runs
- **NULL Metadata Handling** - Fixed crashes when metadata.json lacks parameters section
  - `get_gapit_param()` now safely handles NULL metadata.parameters
  - Prevents aggregation failures on older result directories
- **Integration Test Stability** - Multiple fixes for reliable CI testing
  - Correct markdown filename detection in test assertions
  - Add `--allow-incomplete` flag for partial result aggregation
  - Proper execute permissions on test scripts
- **BLINK MAF Column Order Issue** - Fixed incorrect MAF values in aggregated results for BLINK model
  - GAPIT's BLINK model outputs columns in wrong order (MAF contains sample count instead of frequency)
  - Aggregation script now detects MAF > 1 and sets to NA with warning
  - MLM and FarmCPU models retain correct MAF values
  - Added test fixtures and unit tests for column handling

### Added
- **Analysis Type Parsing** - Extract NYC/Kansas suffix from trait names into separate column
  - `analysis_type` column added to aggregated output (values: NYC, Kansas, standard)
  - Trait names cleaned of suffix for better readability
  - Documented NYC/Kansas as duplicate outputs (identical data)
- **GAPIT Output Quirks Documentation** - Added reference section to results-aggregation spec
  - BLINK column order issue
  - NYC/Kansas duplicate outputs
  - Filter file column limitations
- **RunAI CLI v2 Skill and Documentation Update** - Complete migration to RunAI CLI v2 syntax
  - `.claude/skills/runai/` - New Claude skill for RunAI CLI v2 assistance
    - `skill.md` - Comprehensive v2 command reference with migration guide
    - `examples.md` - Real-world GAPIT3 pipeline usage examples
  - Updated all documentation to use RunAI CLI v2 commands:
    - `docs/RUNAI_QUICK_REFERENCE.md` - Fixed incorrect command syntax
    - `docs/MANUAL_RUNAI_EXECUTION.md` - 108 command updates
    - `docs/DEMO_COMMANDS.md` - Updated quick reference commands
    - `docs/QUICK_DEMO.md` - Updated demo workflow commands
    - `docs/DEPLOYMENT_TESTING.md` - Updated troubleshooting commands
    - `.claude/commands/monitor-jobs.md` - Updated monitoring commands
    - `.claude/commands/cleanup-jobs.md` - Updated cleanup commands
  - Key v2 syntax changes:
    - `runai submit` → `runai workspace submit`
    - `runai list jobs` → `runai workspace list`
    - `runai describe job` → `runai workspace describe`
    - `runai logs` → `runai workspace logs`
    - `runai delete job` → `runai workspace delete`
    - `--cpu` → `--cpu-core-request`, `--memory` → `--cpu-memory-request`
    - New host-path syntax: `path=/path,mount=/mount,mount-propagation=HostToContainer`
    - Project name: `runai-talmo-lab` → `talmo-lab`
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
- **Duplicate Parameter Passing** - Removed CLI argument passing from Argo WorkflowTemplates
  - Parameters are now passed exclusively via environment variables (env section)
  - Container args contain only the command selector (`run-single-trait`), not runtime parameters
  - Eliminates silent failures where CLI args appeared to work but were ignored by entrypoint.sh
  - Added documentation comments in WorkflowTemplate explaining env-var-only pattern
  - See `openspec/specs/argo-workflow-configuration/spec.md` for requirements
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

### Documented
- **Session Documentation** - Operational notes from January 2026 iron GWAS run
  - `docs/20260104_iron_gwas_normalized_status.md` - Pipeline status report
  - `docs/session_review_20260104.md` - Lessons learned and improvement recommendations
  - `docs/github_issue_pipeline_improvements.md` - Proposed improvements from real-world usage
- Workflow validation fix root cause and solution
- RBAC permissions issue blocking Argo execution
- Successful single-trait test with RunAI CLI
- RunAI CLI syntax migration (old vs. new commands)

### Deprecated
- `config/config.yaml` - Configuration now via environment variables (file kept for backward compatibility but not used by new entrypoint)

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

**License**: GPL-3.0
