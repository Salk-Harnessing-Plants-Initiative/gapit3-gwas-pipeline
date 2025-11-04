# Project Context

## Purpose
Dockerized, parallelized GAPIT3 pipeline for high-throughput genome-wide association studies (GWAS) on GPU/CPU clusters using Argo Workflows. Designed for reproducible, traceable, and FAIR-compliant GWAS analysis in plants (specifically Arabidopsis thaliana) and other organisms.

**Production Use Case**: Analysis of 546 Arabidopsis accessions across 184 iron-related traits with ~1.4M SNPs.

## Tech Stack

### Core Technologies
- **R 4.4.1** - Primary programming language
- **GAPIT3** (GitHub: jiabowang/GAPIT@master) - Genome Association and Prediction Integrated Tool
- **Docker** - Containerization (rocker/r-ver:4.4.1 base image)
- **Argo Workflows** - Kubernetes-native orchestration for parallel execution
- **Kubernetes** - Container orchestration platform

### R Packages
- **Core GWAS**: GAPIT3 (via devtools from GitHub)
- **Data Processing**: data.table, dplyr, tidyr, readr
- **Visualization**: ggplot2, gridExtra
- **Utilities**: matrixStats, optparse, yaml, jsonlite, logging
- **Development**: devtools

### Infrastructure
- **Container Registry**: GitHub Container Registry (GHCR)
- **Storage**: NFS/hostPath for shared data and outputs
- **Compute**: Multi-threaded OpenBLAS (16 threads), optimized for linear algebra operations
- **Development**: VS Code with devcontainer support

## Project Conventions

### Code Style

#### R Scripts
- Use snake_case for variables and functions
- Use descriptive names (e.g., `run_gwas_single_trait.R`, not `run.R`)
- Add header comments with purpose, author, and description blocks
- Use 80-100 character line width where practical
- Comment complex statistical operations
- Use optparse for CLI argument parsing
- Implement logging with meaningful levels (DEBUG, INFO, WARNING, ERROR)

#### YAML Files
- Use kebab-case for Argo Workflow names (`gapit3-gwas-parallel`)
- Include descriptive comments with `# ===` separator blocks for sections
- Document all parameters with inline comments
- Use TODO comments for values that need customization

#### File Naming
- Scripts: `verb_noun.R` (e.g., `validate_inputs.R`, `collect_results.R`)
- Workflows: `project-purpose-type.yaml` (e.g., `gapit3-test-pipeline.yaml`)
- Templates: `purpose-template.yaml` (e.g., `trait-extractor-template.yaml`)

### Architecture Patterns

#### Pipeline Structure (DAG)
```
Validate Inputs → Extract Traits → Parallel GWAS (184 jobs) → Collect Results
```

#### Containerization
- Multi-stage Docker builds for optimization
- Layer caching for R packages (core → visualization → GAPIT3)
- Separate base and runtime stages
- Environment variables for compute resources (OPENBLAS_NUM_THREADS, OMP_NUM_THREADS)

#### Workflow Orchestration
- **Templates**: Reusable WorkflowTemplates for single-trait execution, validation, extraction, collection
- **Workflows**: Concrete workflow instances (test: 3 traits, full: 184 traits)
- **Parallelism**: Controlled via `withSequence` for trait indices, limited by `max-parallelism` parameter
- **Dependencies**: Explicit DAG task dependencies

#### Data Organization
```
/data/
  ├── genotype/    # HapMap format (.hmp.txt)
  ├── phenotype/   # Tab-delimited with "Taxa" column
  └── metadata/    # Accession IDs

/outputs/
  ├── trait_NNN_*/        # Per-trait results (Manhattan, QQ plots, CSV)
  └── aggregated_results/ # Summary tables, significant SNPs
```

#### FAIR Principles Implementation
- **Findable**: Metadata JSON with execution timestamps, versions
- **Accessible**: Standard file formats (CSV, PNG, JSON)
- **Interoperable**: HapMap input format, documented schemas
- **Reusable**: Docker containers, version-pinned dependencies, checksums

### Testing Strategy

#### Unit Testing (testthat)
- **Framework**: R testthat package for automated unit tests
- **Coverage**: Config parsing, input validation, trait extraction logic
- **Fixtures**: Synthetic datasets in `tests/fixtures/` (10 SNPs, 5 samples, 3 traits)
- **Execution**: `Rscript tests/testthat.R` or via GitHub Actions
- **Runtime**: ~1-2 minutes locally

#### Functional Testing (Docker)
- **Scope**: End-to-end testing with Docker container
- **Tests**:
  - Validation command with test fixtures
  - Trait extraction with sample phenotype
  - Environment variable configuration (OPENBLAS_NUM_THREADS)
  - Entrypoint routing for all commands
- **Execution**: Automated in docker-build.yml workflow
- **Runtime**: ~6-10 minutes in CI

#### Devcontainer Testing
- **Purpose**: Ensure local dev environment matches production
- **Validation**:
  - R version 4.4.1 installed
  - GAPIT3 package loadable
  - All required R packages present
  - Container builds without errors
- **Execution**: Automated in test-devcontainer.yml workflow (runs on devcontainer changes only)
- **Runtime**: ~8-12 minutes in CI

#### CI/CD Workflows
1. **R Script Tests** (`.github/workflows/test-r-scripts.yml`)
   - Triggers: Changes to `scripts/**/*.R` or `tests/**`
   - Runs all testthat unit tests
   - Caches R packages for speed

2. **Devcontainer Tests** (`.github/workflows/test-devcontainer.yml`)
   - Triggers: Changes to `.devcontainer/**` or `Dockerfile`
   - Builds devcontainer and validates R environment
   - Uses devcontainers/cli

3. **Docker Build** (`.github/workflows/docker-build.yml`)
   - Triggers: Changes to `Dockerfile`, `scripts/**`, `config/**`
   - Builds image, runs functional tests
   - Enhanced with test fixtures

#### Local Testing
- Use devcontainer for development environment consistency
- Run unit tests before committing: `Rscript tests/testthat.R`
- Test Docker build: `docker build -t gapit3-test .`
- Test single-trait execution: `docker run ... run-single-trait --trait-index 2`

#### Cluster Testing (Manual)
- **Test pipeline** (`gapit3-test-pipeline.yaml`): Run 3 traits to verify setup
- Monitor with `./scripts/monitor_workflow.sh watch <workflow-name>`
- Validate outputs exist and contain expected files (Manhattan plots, GWAS results CSV)

#### Validation Points
1. **Pre-flight**: File existence, format validation, minimum sample size (50)
2. **Runtime**: Trait index bounds, column counts
3. **Post-execution**: Output file creation, aggregation completeness

#### Performance Benchmarks
- Single trait (BLINK only): ~15 minutes
- 184 traits (BLINK + FarmCPU, 50 parallel): ~4 hours
- Monitor for OOMKilled errors (increase memory if needed)

#### Test Documentation
- Comprehensive testing guide: `docs/TESTING.md`
- Includes local testing procedures, fixture descriptions, troubleshooting
- Contributing section in README.md references testing requirements

### Git Workflow

#### Branching Strategy
- **main**: Production-ready code
- **feature/***: New features (e.g., `feature/add-mlm-model`)
- **fix/***: Bug fixes
- **docs/***: Documentation updates

#### Commit Conventions
- Use conventional commits format: `type: description`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Examples:
  - `feat: Add support for MLM model`
  - `fix: Correct trait index off-by-one error`
  - `docs: Update Argo setup guide`
  - `chore: Bump R version to 4.4.2`

#### Pull Request Process
1. Create feature branch from main
2. Implement changes with descriptive commits
3. Test locally with devcontainer
4. Test on cluster with test pipeline
5. Open PR with checklist: functionality, documentation, testing
6. Merge to main after review

## Domain Context

### GWAS Background
- **Goal**: Identify genetic variants (SNPs) associated with quantitative traits
- **Statistical Models**:
  - **BLINK** (Bayesian-information and Linkage-disequilibrium Iteratively Nested Keyway): Fast, effective for large datasets
  - **FarmCPU** (Fixed and random model Circulating Probability Unification): More accurate, slower, controls false positives
- **Multiple Testing Correction**: Genome-wide significance threshold p < 5e-8
- **Population Structure**: Corrected via PCA (3 components)

### Arabidopsis thaliana
- Model organism for plant biology
- ~135 Mb genome, 5 chromosomes
- 546 accessions (natural genetic variation)
- ~1.4M SNPs after MAF filtering

### Iron Traits
- 184 phenotypic traits related to iron homeostasis
- Measured across controlled conditions
- Critical for plant nutrition and crop improvement

### HapMap Format
- Standard genotype file format for GWAS
- Tab-delimited with SNP metadata (chr, pos, alleles) + accession genotypes
- Diploid encoding (e.g., AA, AT, TT)

## Important Constraints

### Computational
- **Memory**: Minimum 16GB per trait, recommend 32GB (64GB optimal)
- **CPU**: Minimum 8 cores, recommend 12 cores for multi-threading
- **Disk**: ~20GB per trait for outputs (plots, results)
- **Time**: Individual trait runtime 10-45 minutes depending on model

### Cluster-Specific
- NFS/hostPath storage must be accessible from all worker nodes
- Namespace permissions for WorkflowTemplate creation
- Image pull permissions for GHCR (may require authentication)
- Parallelism limits based on cluster capacity (default: 50 concurrent jobs)

### Data Format
- Phenotype file MUST have "Taxa" column matching genotype sample IDs
- Genotype file must be HapMap format (.hmp.txt)
- Trait columns must be numeric (non-numeric values will cause errors)
- Minimum 50 samples required for GWAS

### Reproducibility
- GAPIT3 version pinned via GitHub commit (currently @master)
- R version locked to 4.4.1
- Container images tagged with version numbers
- Random seed not set (GAPIT default behavior - document this limitation)

## External Dependencies

### R Package Repositories
- **CRAN**: https://cloud.r-project.org (for standard packages)
- **GitHub**: jiabowang/GAPIT (for GAPIT3 - not on CRAN)

### Container Registries
- **Base Image**: rocker/r-ver:4.4.1 (Docker Hub)
- **Production Image**: ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest

### System Libraries
- OpenBLAS (libopenblas-dev) - Critical for performance
- LAPACK (liblapack-dev) - Linear algebra
- Graphics libraries: libpng-dev, libjpeg-dev, libfreetype6-dev (for plot generation)

### Kubernetes Dependencies
- **Argo Workflows**: v3.4+ (workflow engine)
- **kubectl**: CLI for Kubernetes interactions
- **argo**: CLI for workflow submission and monitoring

### Storage
- NFS or hostPath storage provisioned on cluster
- Sufficient capacity: ~5GB per trait × 184 traits = ~1TB recommended

### Optional Services
- GitHub Actions (for Docker image builds via .github/workflows/docker-build.yml)
- GitHub Container Registry (for hosting images)
