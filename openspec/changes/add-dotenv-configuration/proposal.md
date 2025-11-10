# Proposal: Add Runtime Configuration via Environment Variables

## Problem Statement

The GAPIT3 pipeline configuration is currently hardcoded at **Docker build time** rather than being configurable at **runtime**. This creates inflexibility and requires rebuilding the image for configuration changes.

### Current Issues

**1. Build-Time Configuration (Inflexible)**
```dockerfile
# In Dockerfile or scripts - BAKED IN at build time
ENV MODELS="BLINK,FarmCPU"
ENV PCA_COMPONENTS=3
```

**Problem**: To change models or parameters, must rebuild and push new Docker image

**2. Scattered Configuration**
- `config/config.yaml` - GAPIT parameters (copied into image at build)
- R scripts - Read from config.yaml (fixed at build)
- Container entrypoint - Hardcoded model selection

**3. Both RunAI and Argo Use Same Container**
- RunAI CLI: Manual execution (current workaround)
- Argo Workflows: Automated orchestration (blocked by RBAC, future)
- **Both need same runtime flexibility**

### Real-World Scenario

**Current (Requires Rebuild):**
```bash
# User wants to run with different parameters
# Step 1: Edit config/config.yaml
# Step 2: Rebuild Docker image
docker build -t my-custom-image .
# Step 3: Push to registry
docker push my-custom-image
# Step 4: Update RunAI/Argo to use new image
# This takes 10-30 minutes!
```

**Desired (Runtime Config):**
```bash
# RunAI - just pass environment variables
runai workspace submit my-job \
  --image gapit3:latest \
  --environment MODELS=BLINK \
  --environment PCA_COMPONENTS=5 \
  --environment SNP_THRESHOLD=1e-6

# Argo - same image, different params
env:
  - name: MODELS
    value: "FarmCPU"
  - name: PCA_COMPONENTS
    value: "5"
```

## Proposed Solution

Make the container **runtime-configurable** through environment variables, with `.env.example` documenting all available options.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  User Configuration (.env - local development only)    │
│  ├─ MODELS=BLINK,FarmCPU                               │
│  ├─ PCA_COMPONENTS=3                                    │
│  └─ SNP_THRESHOLD=5e-8                                  │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Deployment Layer (RunAI or Argo)                      │
│  ├─ RunAI: --environment MODELS=BLINK                  │
│  └─ Argo:  env: [{name: MODELS, value: BLINK}]        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Container Runtime                                       │
│  ├─ entrypoint.sh reads ENV vars                       │
│  ├─ Falls back to defaults if not set                  │
│  └─ Passes to R scripts                                 │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  GAPIT3 Execution                                        │
│  └─ run_gwas_single_trait.R with runtime params        │
└─────────────────────────────────────────────────────────┘
```

### Key Changes

**1. Container Entrypoint (Runtime Config)**
```bash
#!/bin/bash
# scripts/entrypoint.sh

# Runtime configuration from environment variables
MODELS="${MODELS:-BLINK,FarmCPU}"
PCA_COMPONENTS="${PCA_COMPONENTS:-3}"
SNP_THRESHOLD="${SNP_THRESHOLD:-5e-8}"
MAF_FILTER="${MAF_FILTER:-0.05}"

# Pass to R script
Rscript /scripts/run_gwas_single_trait.R \
  --models "$MODELS" \
  --pca "$PCA_COMPONENTS" \
  --threshold "$SNP_THRESHOLD" \
  --maf "$MAF_FILTER"
```

**2. .env.example (Documentation + Local Dev)**
```.env
# ===========================================================================
# GAPIT3 Runtime Configuration
# ===========================================================================
# These environment variables configure the GAPIT3 analysis at runtime
#
# Usage:
#   Local Docker:  docker run --env-file .env gapit3:latest
#   RunAI CLI:     --environment MODELS=BLINK --environment PCA_COMPONENTS=5
#   Argo:          env: [{name: MODELS, value: "BLINK"}]
# ===========================================================================

# ---------------------------------------------------------------------------
# GAPIT Analysis Parameters (Container Runtime)
# ---------------------------------------------------------------------------

# GWAS models to run (comma-separated)
# Options: BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM
# Default: BLINK,FarmCPU
# Performance: BLINK only = 2x faster
MODELS=BLINK,FarmCPU

# Number of principal components for population structure correction
# Range: 0-10 (0 = no PCA correction)
# Default: 3
# Recommendation: 3-5 for most datasets
PCA_COMPONENTS=3

# Significance threshold for identifying SNPs (p-value)
# Default: 5e-8 (genome-wide significance)
# Alternatives: 1e-5 (suggestive), 1e-6 (stricter)
SNP_THRESHOLD=5e-8

# Minor allele frequency filter (remove rare variants)
# Range: 0.0-0.5
# Default: 0.05 (keep SNPs with MAF >= 5%)
# Set to 0 to disable filtering
MAF_FILTER=0.05

# Number of threads for linear algebra operations
# Default: Matches CPU allocation
# Override if needed (usually matches --cpu-core-request)
OPENBLAS_NUM_THREADS=12
OMP_NUM_THREADS=12

# ---------------------------------------------------------------------------
# Input/Output Paths (Set by deployment, not usually in .env)
# ---------------------------------------------------------------------------

# These are typically set by RunAI/Argo volume mounts
# Listed here for documentation only

# TRAIT_INDEX=2                    # Which trait column to analyze (set per job)
# DATA_PATH=/data                  # Mounted data directory
# OUTPUT_PATH=/outputs             # Mounted output directory
# GENOTYPE_FILE=/data/genotype/... # Override genotype file path
# PHENOTYPE_FILE=/data/phenotype/... # Override phenotype file path

# ---------------------------------------------------------------------------
# Advanced GAPIT Options (Rarely Changed)
# ---------------------------------------------------------------------------

# Kinship calculation method
# Options: VanRaden, EMMA, Loiselle
# Default: VanRaden
# KINSHIP_METHOD=VanRaden

# Multiple testing correction method
# Options: FDR, Bonferroni, None
# Default: FDR
# CORRECTION_METHOD=FDR

# Maximum iterations for BLINK/FarmCPU
# Default: 10
# MAX_ITERATIONS=10
```

**3. Updated R Scripts (Read from ENV)**
```r
# scripts/run_gwas_single_trait.R

library(optparse)

# Parse command-line args (from entrypoint.sh)
option_list <- list(
  make_option(c("-m", "--models"), type="character",
              default=Sys.getenv("MODELS", "BLINK,FarmCPU"),
              help="GWAS models (comma-separated)"),
  make_option(c("-p", "--pca"), type="integer",
              default=as.integer(Sys.getenv("PCA_COMPONENTS", "3")),
              help="Number of PCA components"),
  # ... etc
)

# Models now configurable at runtime!
models <- strsplit(opt$models, ",")[[1]]
GAPIT(..., model=models, PCA.total=opt$pca)
```

**4. Remove config.yaml (No Longer Needed)**
- Configuration now via environment variables
- Simpler: one mechanism instead of two
- Documented in `.env.example`

## Benefits

### For Container Runtime
✅ **One image, many configurations** - No rebuilds needed
✅ **Fast iteration** - Change params in seconds, not minutes
✅ **Environment parity** - Same image for dev/test/prod

### For RunAI Users
✅ **Simple parameter changes** - `--environment MODELS=BLINK`
✅ **Job-specific config** - Different params per trait if needed
✅ **No image management** - Always use `:latest`

### For Argo Workflows (Future)
✅ **Parameterized workflows** - Easy to template
✅ **A/B testing** - Run same data with different params
✅ **Reproducibility** - Workflow YAML captures exact config

### For Development
✅ **Local testing** - `docker run --env-file .env`
✅ **Clear documentation** - `.env.example` is self-documenting
✅ **Type safety** - Can validate env vars in entrypoint

## Implementation

### Phase 1: Container Runtime (3-4 hours)
1. Update `scripts/entrypoint.sh` to read environment variables
2. Update R scripts to accept parameters from env/args
3. Remove `config/config.yaml` (migrate to ENV)
4. Add validation for required/valid values

### Phase 2: Documentation (1 hour)
5. Create comprehensive `.env.example`
6. Update README with runtime configuration section
7. Update RunAI docs with `--environment` examples
8. Document Argo env variable mapping

### Phase 3: RunAI Scripts (1 hour)
9. Update submit script to pass env vars
10. Add `--models`, `--pca` flags that set env vars
11. Maintain backward compatibility with defaults

### Phase 4: Testing (1 hour)
12. Test with various env configurations
13. Test missing env vars (use defaults)
14. Test invalid values (validation catches)

## Migration Path

**Backward Compatible:**
- Container works without env vars (uses sensible defaults)
- Existing RunAI commands work unchanged
- Gradual adoption of new parameters

**For Users:**
```bash
# Before (works, uses defaults)
runai workspace submit job-1 --image gapit3:latest

# After (custom config)
runai workspace submit job-1 \
  --image gapit3:latest \
  --environment MODELS=BLINK \
  --environment PCA_COMPONENTS=5
```

## Risks and Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Typos in env var names | Medium | Validation in entrypoint.sh with clear errors |
| Invalid parameter values | Medium | Validate ranges/options before passing to R |
| Missing config.yaml breaks old images | Low | Only change in new image tags |
| Too many env vars to remember | Low | Comprehensive .env.example with examples |

## Success Metrics

- [x] Can run with different models without rebuild
- [x] .env.example documents all runtime options
- [x] Same Docker image works for RunAI and Argo
- [x] Zero configuration-related rebuild requests

## References

- [12-Factor App: Config in Environment](https://12factor.net/config)
- [Docker: Environment Variables](https://docs.docker.com/compose/environment-variables/)
- [Kubernetes: Configure Pods with ENV](https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/)
