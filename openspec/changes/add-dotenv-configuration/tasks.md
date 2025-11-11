# Implementation Tasks: Add Runtime Configuration via Environment Variables

## Overview

This document provides step-by-step implementation tasks for making the GAPIT3 container runtime-configurable through environment variables.

**Estimated Time**: 6-7 hours total

## Phase 1: Container Runtime Updates (3-4 hours)

### Task 1.1: Create entrypoint.sh script (1 hour)

**File**: `scripts/entrypoint.sh`

**Steps**:
1. Create new entrypoint script with environment variable reading
2. Add validation functions for:
   - MODELS (valid options: BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM)
   - PCA_COMPONENTS (range: 0-20)
   - SNP_THRESHOLD (format: scientific notation)
   - MAF_FILTER (range: 0.0-0.5)
   - Required paths exist (DATA_PATH, OUTPUT_PATH)
3. Add configuration logging function
4. Implement command routing (run-single-trait, run-aggregation)
5. Add helpful error messages for validation failures

**Example validation**:
```bash
validate_models() {
    local valid_models="BLINK FarmCPU MLM MLMM SUPER CMLM"
    IFS=',' read -ra model_array <<< "$MODELS"
    for model in "${model_array[@]}"; do
        if [[ ! " $valid_models " =~ " $model " ]]; then
            echo "ERROR: Invalid model '$model'"
            echo "Valid options: $valid_models"
            exit 1
        fi
    done
}
```

**Acceptance Criteria**:
- [ ] Script reads all environment variables with sensible defaults
- [ ] Validation catches invalid models, ranges, and missing paths
- [ ] Error messages are clear and actionable
- [ ] Configuration is logged before execution starts
- [ ] Works with both single-trait and aggregation commands

### Task 1.2: Update run_gwas_single_trait.R (1 hour)

**File**: `scripts/run_gwas_single_trait.R`

**Steps**:
1. Add `optparse` library usage (already installed in container)
2. Define command-line options for all parameters
3. Read from command-line args with env var fallbacks
4. Update GAPIT function calls to use runtime parameters
5. Add parameter logging at script start

**Example parameter parsing**:
```r
library(optparse)

option_list <- list(
  make_option(c("-t", "--trait-index"), type="integer",
              default=as.integer(Sys.getenv("TRAIT_INDEX", "2")),
              help="Trait column index to analyze"),
  make_option(c("-m", "--models"), type="character",
              default=Sys.getenv("MODELS", "BLINK,FarmCPU"),
              help="Comma-separated list of GWAS models"),
  make_option(c("-p", "--pca"), type="integer",
              default=as.integer(Sys.getenv("PCA_COMPONENTS", "3")),
              help="Number of PCA components"),
  make_option(c("--threshold"), type="character",
              default=Sys.getenv("SNP_THRESHOLD", "5e-8"),
              help="Significance threshold (p-value)"),
  make_option(c("--maf"), type="numeric",
              default=as.numeric(Sys.getenv("MAF_FILTER", "0.05")),
              help="Minor allele frequency filter")
)

opt <- parse_args(OptionParser(option_list=option_list))

# Split models and pass to GAPIT
models_list <- strsplit(opt$models, ",")[[1]]
GAPIT(..., model=models_list, PCA.total=opt$pca)
```

**Acceptance Criteria**:
- [ ] All parameters accept command-line args
- [ ] Falls back to environment variables if args not provided
- [ ] Models can be comma-separated list
- [ ] PCA components accepts 0 (disables PCA)
- [ ] Script logs parameters before execution

### Task 1.3: Update Dockerfile (30 min)

**File**: `Dockerfile`

**Steps**:
1. Remove hardcoded ENV directives for runtime parameters
2. Set ENTRYPOINT to use new entrypoint.sh
3. Keep build-time settings (R version, system packages)
4. Add default CMD for documentation

**Changes**:
```dockerfile
# REMOVE these (now runtime config):
# ENV MODELS="BLINK,FarmCPU"
# ENV PCA_COMPONENTS=3

# KEEP these (build-time):
ENV DEBIAN_FRONTEND=noninteractive
ENV R_VERSION=4.3

# ADD:
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
RUN chmod +x /scripts/entrypoint.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["run-single-trait"]
```

**Acceptance Criteria**:
- [ ] No runtime config hardcoded in Dockerfile
- [ ] Entrypoint script is executable
- [ ] Build succeeds without errors
- [ ] Image runs with default CMD

### Task 1.4: Remove config.yaml (15 min)

**Files**: `config/config.yaml`, R scripts that read it

**Steps**:
1. Delete `config/config.yaml` file
2. Remove YAML reading code from R scripts
3. Update any tests that reference config.yaml

**Acceptance Criteria**:
- [ ] config.yaml file deleted
- [ ] No code references config.yaml
- [ ] All configuration via environment variables

## Phase 2: Documentation (1 hour)

### Task 2.1: Create .env.example (30 min)

**File**: `.env.example`

**Steps**:
1. Document ALL environment variables with:
   - Clear description
   - Valid options/ranges
   - Default values
   - Performance implications where relevant
2. Organize into logical sections:
   - Job Identity and Paths
   - GAPIT Analysis Parameters
   - Computational Resources
   - Advanced Options
3. Include usage examples for each deployment method
4. Add warnings about what NOT to commit

**Structure** (see design.md for full content):
```bash
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

# Job Identity and Paths
TRAIT_INDEX=2
DATA_PATH=/data
OUTPUT_PATH=/outputs
# ... etc
```

**Acceptance Criteria**:
- [ ] All environment variables documented
- [ ] Examples for all three deployment methods
- [ ] Clear warnings about .env being local-only
- [ ] Sensible defaults shown

### Task 2.2: Update README.md (15 min)

**File**: `README.md`

**Steps**:
1. Add "Runtime Configuration" section
2. Show docker run with --env-file example
3. Link to .env.example for full options
4. Show quick examples for common scenarios

**Example section**:
```markdown
## Runtime Configuration

The container is configured entirely through environment variables. See [.env.example](.env.example) for all options.

### Quick Examples

**Run with BLINK only (faster)**:
```bash
docker run --rm \
  -v /data:/data \
  -v /outputs:/outputs \
  -e TRAIT_INDEX=2 \
  -e MODELS=BLINK \
  gapit3:latest
```

**Change PCA components**:
```bash
docker run --rm \
  -e TRAIT_INDEX=2 \
  -e PCA_COMPONENTS=5 \
  gapit3:latest
```

**Local development with .env file**:
```bash
# Copy example and customize
cp .env.example .env
nano .env

# Run with your config
docker run --rm --env-file .env gapit3:latest
```
```

**Acceptance Criteria**:
- [ ] README clearly explains runtime configuration
- [ ] Examples work as documented
- [ ] Links to .env.example
- [ ] Local development workflow documented

### Task 2.3: Update RunAI documentation (15 min)

**File**: `docs/DEPLOYMENT_TESTING.md` or similar

**Steps**:
1. Update all RunAI submit commands to show --environment flags
2. Document how to change models without rebuild
3. Show examples of A/B testing parameters

**Example**:
```bash
# Before: Had to rebuild image
# Now: Just pass different environment variables

# Test 1: BLINK only
runai workspace submit gapit3-test1 \
  --environment MODELS=BLINK \
  --environment PCA_COMPONENTS=3

# Test 2: FarmCPU only
runai workspace submit gapit3-test2 \
  --environment MODELS=FarmCPU \
  --environment PCA_COMPONENTS=5
```

**Acceptance Criteria**:
- [ ] All examples use --environment flags
- [ ] Shows benefit of runtime config (no rebuilds)
- [ ] A/B testing example included

## Phase 3: RunAI Scripts Integration (1 hour)

### Task 3.1: Update submit-all-traits-runai.sh (30 min)

**File**: `scripts/submit-all-traits-runai.sh`

**Steps**:
1. Add optional flags for runtime parameters:
   - `--models` (default: BLINK,FarmCPU)
   - `--pca` (default: 3)
   - `--threshold` (default: 5e-8)
   - `--maf` (default: 0.05)
2. Pass these as --environment to runai workspace submit
3. Update help text
4. Maintain backward compatibility (use defaults if not specified)

**Example**:
```bash
# Parse new options
while [[ $# -gt 0 ]]; do
    case $1 in
        --models)
            MODELS="$2"
            shift 2
            ;;
        --pca)
            PCA_COMPONENTS="$2"
            shift 2
            ;;
        # ... etc
    esac
done

# In submission loop
runai workspace submit $JOB_NAME \
    --project $PROJECT \
    --image $IMAGE \
    --environment TRAIT_INDEX=$trait_idx \
    --environment DATA_PATH="$DATA_PATH" \
    --environment OUTPUT_PATH="$OUTPUT_PATH" \
    --environment MODELS="$MODELS" \
    --environment PCA_COMPONENTS="$PCA_COMPONENTS" \
    --environment SNP_THRESHOLD="$SNP_THRESHOLD" \
    --environment MAF_FILTER="$MAF_FILTER"
```

**Acceptance Criteria**:
- [ ] Script accepts optional parameter flags
- [ ] Uses sensible defaults if not specified
- [ ] Passes all config as --environment flags
- [ ] Help text documents new options
- [ ] Backward compatible with existing usage

### Task 3.2: Update aggregate-runai-results.sh (15 min) ✅ COMPLETED

**File**: `scripts/aggregate-runai-results.sh`

**Steps**:
1. ✅ Added .env file loading at script start (lines 17-25)
2. ✅ Updated configuration precedence: .env → environment → defaults
3. ✅ Added support for OUTPUT_PATH_HOST from .env
4. ✅ Added support for START_TRAIT, END_TRAIT from .env
5. ✅ Added support for SNP_THRESHOLD from .env

**Implementation**:
```bash
# Load configuration from .env file if it exists
ENV_FILE="$PROJECT_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    # Export variables from .env (ignore comments and empty lines)
    set -a
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r$//')
    set +a
fi

# Parse from environment or use defaults
PROJECT="${PROJECT:-${RUNAI_PROJECT:-$DEFAULT_PROJECT}}"
OUTPUT_DIR="${OUTPUT_PATH_HOST:-${OUTPUT_PATH:-${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}}}"
START_TRAIT="${START_TRAIT:-$DEFAULT_START_TRAIT}"
END_TRAIT="${END_TRAIT:-$DEFAULT_END_TRAIT}"
THRESHOLD="${SNP_THRESHOLD:-$DEFAULT_THRESHOLD}"
```

**Acceptance Criteria**:
- [x] Aggregation script loads .env file
- [x] Uses OUTPUT_PATH_HOST for cluster paths
- [x] Uses SNP_THRESHOLD from .env
- [x] Maintains backward compatibility with env vars and defaults

### Task 3.3: Add .env support to cleanup and monitor scripts (20 min) ✅ COMPLETED

**Files**:
- `scripts/cleanup-runai.sh`
- `scripts/monitor-runai-jobs.sh`

**Steps Completed**:
1. ✅ Added .env file loading to cleanup-runai.sh (lines 14-24)
2. ✅ Added .env file loading to monitor-runai-jobs.sh (lines 10-20)
3. ✅ Both scripts now use OUTPUT_PATH_HOST from .env
4. ✅ Both scripts use PROJECT and JOB_PREFIX from .env
5. ✅ Maintains fallback to defaults if .env not present

**Implementation Pattern** (used in all scripts):
```bash
# Load configuration from .env file if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    # Export variables from .env (ignore comments and empty lines)
    set -a
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r$//')
    set +a
fi

# Configuration - .env values or fallback defaults
PROJECT="${PROJECT:-talmo-lab}"
OUTPUT_PATH="${OUTPUT_PATH_HOST:-${OUTPUT_PATH:-/default/path}}"
JOB_PREFIX="${JOB_PREFIX:-gapit3-trait}"
```

**Acceptance Criteria**:
- [x] cleanup-runai.sh loads .env configuration
- [x] monitor-runai-jobs.sh loads .env configuration
- [x] All four RunAI scripts now have consistent .env support
- [x] Scripts work without .env file (use defaults)
- [x] Scripts properly use OUTPUT_PATH_HOST for cluster paths

### Task 3.4: Fix .env.example accuracy (30 min) ✅ COMPLETED

**File**: `.env.example`

**Critical Issue Found**:
- .env.example documented options (KINSHIP_METHOD, CORRECTION_METHOD, MAX_ITERATIONS) that were NOT actually configurable
- submit-all-traits-runai.sh only passes specific env vars to containers
- This created misleading documentation

**Steps Completed**:
1. ✅ Verified what submit script actually passes to containers (lines 106-123 of submit script)
2. ✅ Removed invalid options from .env.example
3. ✅ Added clear documentation section explaining non-configurable options
4. ✅ Updated OPENBLAS/OMP_NUM_THREADS notes (auto-set by script)
5. ✅ Added deployment-specific configuration documentation

**What's Actually Passed to Containers**:
```bash
--environment TRAIT_INDEX=$trait_idx \
--environment DATA_PATH=/data \
--environment OUTPUT_PATH=/outputs \
--environment MODELS=$MODELS \
--environment PCA_COMPONENTS=$PCA_COMPONENTS \
--environment SNP_THRESHOLD=$SNP_THRESHOLD \
--environment MAF_FILTER=$MAF_FILTER \
--environment MULTIPLE_ANALYSIS=$MULTIPLE_ANALYSIS \
--environment OPENBLAS_NUM_THREADS=$CPU \
--environment OMP_NUM_THREADS=$CPU
```

**Added Documentation Section**:
```bash
# ===========================================================================
# Advanced GAPIT Options (NOT configurable via environment variables)
# ===========================================================================
# These options exist in the R scripts with hardcoded defaults but are NOT
# passed as environment variables by submit-all-traits-runai.sh
# To change these, you must modify the R scripts directly:
#   - KINSHIP_METHOD=VanRaden (default in entrypoint.sh)
#   - CORRECTION_METHOD=FDR (default in entrypoint.sh)
#   - MAX_ITERATIONS=10 (default in entrypoint.sh)
# ===========================================================================
```

**Acceptance Criteria**:
- [x] .env.example only documents actually configurable options
- [x] Clear section explaining non-configurable options
- [x] Accurate notes about auto-set values (OPENBLAS/OMP threads)
- [x] Deployment-specific configuration clearly marked

## Phase 4: Testing (1 hour)

### Task 4.1: Local Docker testing (30 min)

**Test cases**:
1. Run with all defaults (no env vars set)
2. Run with .env file (docker run --env-file)
3. Run with individual -e flags
4. Test invalid model name (should fail with clear error)
5. Test invalid PCA range (should fail with clear error)
6. Test missing paths (should fail with clear error)

**Commands**:
```bash
# Test 1: Defaults
docker run --rm gapit3:test

# Test 2: .env file
cp .env.example .env
docker run --rm --env-file .env gapit3:test

# Test 3: Individual flags
docker run --rm \
  -e TRAIT_INDEX=2 \
  -e MODELS=BLINK \
  -e PCA_COMPONENTS=5 \
  gapit3:test

# Test 4: Invalid model
docker run --rm -e MODELS=INVALID gapit3:test
# Should show: ERROR: Invalid model 'INVALID'

# Test 5: Invalid PCA
docker run --rm -e PCA_COMPONENTS=100 gapit3:test
# Should show: ERROR: PCA_COMPONENTS must be between 0 and 20
```

**Acceptance Criteria**:
- [ ] All test cases pass
- [ ] Error messages are clear and helpful
- [ ] Configuration logging shows correct values
- [ ] R script receives correct parameters

### Task 4.2: RunAI testing (20 min)

**Test cases**:
1. Submit single job with custom models
2. Submit batch with different PCA settings
3. Verify environment variables in running container

**Commands**:
```bash
# Test 1: Single job
runai workspace submit gapit3-config-test \
  --project talmo-lab \
  --image gapit3:test \
  --environment TRAIT_INDEX=2 \
  --environment MODELS=BLINK \
  --environment PCA_COMPONENTS=5

# Verify config in logs
runai logs gapit3-config-test -p talmo-lab

# Test 2: Batch with script
./scripts/submit-all-traits-runai.sh \
  --start-trait 2 --end-trait 3 \
  --models BLINK \
  --pca 5
```

**Acceptance Criteria**:
- [ ] Jobs start successfully with custom config
- [ ] Logs show correct configuration
- [ ] Results reflect parameter changes (e.g., BLINK-only faster)

### Task 4.3: Validation testing (10 min)

**Test edge cases**:
1. Empty MODELS string
2. PCA_COMPONENTS=0 (should disable PCA)
3. Very small SNP_THRESHOLD (1e-10)
4. MAF_FILTER=0 (should disable filtering)

**Acceptance Criteria**:
- [ ] Edge cases handled gracefully
- [ ] PCA=0 properly disables population correction
- [ ] MAF=0 properly disables filtering

## Phase 5: Documentation Updates (30 min)

### Task 5.1: Update Argo workflow templates (15 min)

**Files**: `cluster/argo/workflows/*.yaml`

**Steps**:
1. Update single-trait template to include env section
2. Update parallel-traits template
3. Add env variable documentation in comments

**Example**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: gapit3-single-trait
spec:
  templates:
  - name: run-gwas
    inputs:
      parameters:
      - name: trait-index
      - name: models
        value: "BLINK,FarmCPU"  # Default
      - name: pca-components
        value: "3"  # Default
    container:
      image: ghcr.io/.../gapit3-gwas-pipeline:latest
      env:
      - name: TRAIT_INDEX
        value: "{{inputs.parameters.trait-index}}"
      - name: MODELS
        value: "{{inputs.parameters.models}}"
      - name: PCA_COMPONENTS
        value: "{{inputs.parameters.pca-components}}"
      - name: DATA_PATH
        value: "/data"
      - name: OUTPUT_PATH
        value: "/outputs"
```

**Acceptance Criteria**:
- [ ] All Argo templates use env specifications
- [ ] Parameters have sensible defaults
- [ ] Comments explain customization options

### Task 5.2: Update QUICKSTART.md (15 min)

**File**: `docs/QUICKSTART.md`

**Steps**:
1. Add section on runtime configuration
2. Show both RunAI and Argo examples
3. Link to .env.example

**Acceptance Criteria**:
- [ ] Quickstart mentions runtime config early
- [ ] Examples show how to customize parameters
- [ ] Clear that no rebuild needed

## Rollout Plan

### Stage 1: Development Testing (Week 1)
- Build new image with entrypoint.sh
- Test locally with docker run
- Validate all test cases pass

### Stage 2: Cluster Testing (Week 1)
- Push test image to registry
- Run small batch on RunAI (traits 2-4)
- Verify logs show correct configuration

### Stage 3: Documentation (Week 1)
- Complete all documentation updates
- Ensure .env.example is comprehensive
- Update all deployment guides

### Stage 4: Production Rollout (Week 2)
- Tag production image (e.g., v2.0.0)
- Update RunAI scripts to use new image
- Run full 186-trait batch with runtime config

### Stage 5: Argo Integration (When RBAC available)
- Update Argo workflow templates
- Test with Argo Workflows
- Document differences if any

## Backward Compatibility

**Breaking Changes**:
- Container now requires ENTRYPOINT to be entrypoint.sh
- Old images without entrypoint.sh won't work with new scripts

**Migration Path**:
1. Keep old image tag (e.g., v1.x) for emergency rollback
2. Update all RunAI commands to specify new image tag
3. Only after validation, update :latest tag

**For Users**:
```bash
# Old way (still works with old image)
runai workspace submit job \
  --image gapit3:v1.0

# New way (required for runtime config)
runai workspace submit job \
  --image gapit3:v2.0 \
  --environment MODELS=BLINK
```

## Success Metrics

- [ ] Can run with BLINK only without rebuilding (2x faster)
- [ ] Can change PCA components between jobs (5 min vs 30 min)
- [ ] Same Docker image works for RunAI and Argo
- [ ] .env.example is comprehensive and clear
- [ ] Zero configuration-related rebuild requests after rollout
- [ ] Validation catches 100% of invalid configurations before R execution

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| Typos in env var names | Comprehensive validation in entrypoint.sh |
| Invalid parameter values | Range/option checking before R execution |
| Missing required paths | Existence check in entrypoint.sh |
| Confusion about .env usage | Clear documentation: .env = local dev only |
| Backward compatibility | Keep old image tags, gradual rollout |

## References

- [Design Document](design.md) - Technical implementation details
- [Proposal](proposal.md) - Problem statement and solution overview
- [12-Factor App: Config](https://12factor.net/config) - Industry best practices
- [Docker Environment Variables](https://docs.docker.com/compose/environment-variables/)
- [Kubernetes ConfigMaps and Secrets](https://kubernetes.io/docs/concepts/configuration/)
