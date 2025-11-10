# Design: Runtime Configuration via Environment Variables

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Local Development (Optional)                           │
│  .env file for convenience                              │
├─────────────────────────────────────────────────────────┤
│  docker run --env-file .env gapit3:latest               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Production Deployment: RunAI                           │
│  ALL configuration via --environment flags              │
├─────────────────────────────────────────────────────────┤
│  runai workspace submit gapit3-trait-2 \                │
│    --environment TRAIT_INDEX=2 \                        │
│    --environment DATA_PATH=/hpi/hpi_dev/.../data \      │
│    --environment OUTPUT_PATH=/hpi/hpi_dev/.../outputs \ │
│    --environment MODELS=BLINK,FarmCPU \                 │
│    --environment PCA_COMPONENTS=3 \                     │
│    --environment SNP_THRESHOLD=5e-8                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Production Deployment: Argo (Future)                   │
│  ALL configuration via env: specifications              │
├─────────────────────────────────────────────────────────┤
│  env:                                                   │
│    - name: TRAIT_INDEX                                  │
│      value: "2"                                         │
│    - name: DATA_PATH                                    │
│      value: "/data"                                     │
│    - name: OUTPUT_PATH                                  │
│      value: "/outputs"                                  │
│    - name: MODELS                                       │
│      value: "BLINK,FarmCPU"                             │
│    - name: PCA_COMPONENTS                               │
│      value: "3"                                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Container Runtime (scripts/entrypoint.sh)              │
├─────────────────────────────────────────────────────────┤
│  1. Read ALL environment variables                      │
│  2. Apply defaults for any unset vars                   │
│  3. Validate values                                     │
│  4. Log complete configuration                          │
│  5. Pass to R scripts                                   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  R Scripts (run_gwas_single_trait.R)                    │
├─────────────────────────────────────────────────────────┤
│  Execute GAPIT with runtime parameters                  │
└─────────────────────────────────────────────────────────┘
```

## Key Principle

**Environment variables are the PRIMARY configuration mechanism.**

- `.env` file = convenience for local `docker run` only
- RunAI/Argo = pass ALL config as environment variables
- ALL parameters are equally important (paths, traits, models, thresholds)
- Container is completely runtime-configurable, no rebuild needed

## Environment Variable Schema

### Complete Configuration (All via ENV)

```bash
# ===========================================================================
# Job Identity and Paths
# ===========================================================================

# Which trait to analyze (required, varies per job)
TRAIT_INDEX=2

# Input data directory (mounted volume in deployment)
DATA_PATH=/hpi/hpi_dev/users/eberrigan/data

# Output directory (mounted volume in deployment)
OUTPUT_PATH=/hpi/hpi_dev/users/eberrigan/outputs

# ===========================================================================
# GAPIT Analysis Parameters
# ===========================================================================

# GWAS models to run (comma-separated)
MODELS=BLINK,FarmCPU

# Population structure correction
PCA_COMPONENTS=3

# Significance threshold
SNP_THRESHOLD=5e-8

# Minor allele frequency filter
MAF_FILTER=0.05

# ===========================================================================
# Computational Resources
# ===========================================================================

# Thread count (should match CPU allocation)
OPENBLAS_NUM_THREADS=12
OMP_NUM_THREADS=12

# ===========================================================================
# Advanced Options (Optional)
# ===========================================================================

# Override default input file paths (optional)
GENOTYPE_FILE=/data/genotype/custom.hmp.txt
PHENOTYPE_FILE=/data/phenotype/custom.txt
IDS_FILE=/data/metadata/custom_ids.txt

# Kinship calculation method
KINSHIP_METHOD=VanRaden

# Multiple testing correction
CORRECTION_METHOD=FDR

# Maximum iterations for BLINK/FarmCPU
MAX_ITERATIONS=10
```

## Entrypoint Script Design

**File**: `scripts/entrypoint.sh`

```bash
#!/bin/bash
set -euo pipefail

# ===========================================================================
# GAPIT3 Container Entrypoint - Runtime Configuration
# ===========================================================================
# ALL configuration via environment variables
# No config files, no build-time baking
# ===========================================================================

# ---------------------------------------------------------------------------
# Read Environment Variables with Defaults
# ---------------------------------------------------------------------------

# Job identity and paths (usually set by deployment)
TRAIT_INDEX="${TRAIT_INDEX:-2}"
DATA_PATH="${DATA_PATH:-/data}"
OUTPUT_PATH="${OUTPUT_PATH:-/outputs}"

# GAPIT analysis parameters (user-configurable)
MODELS="${MODELS:-BLINK,FarmCPU}"
PCA_COMPONENTS="${PCA_COMPONENTS:-3}"
SNP_THRESHOLD="${SNP_THRESHOLD:-5e-8}"
MAF_FILTER="${MAF_FILTER:-0.05}"

# Computational (matches cluster allocation)
CPU="${CPU:-12}"
OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-$CPU}"
OMP_NUM_THREADS="${OMP_NUM_THREADS:-$CPU}"
export OPENBLAS_NUM_THREADS
export OMP_NUM_THREADS

# Advanced options (rarely changed)
KINSHIP_METHOD="${KINSHIP_METHOD:-VanRaden}"
CORRECTION_METHOD="${CORRECTION_METHOD:-FDR}"
MAX_ITERATIONS="${MAX_ITERATIONS:-10}"

# File path overrides (optional)
GENOTYPE_FILE="${GENOTYPE_FILE:-}"
PHENOTYPE_FILE="${PHENOTYPE_FILE:-}"
IDS_FILE="${IDS_FILE:-}"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

validate_config() {
    local errors=0

    # Validate required paths exist
    if [ ! -d "$DATA_PATH" ]; then
        echo "ERROR: DATA_PATH directory does not exist: $DATA_PATH"
        errors=$((errors + 1))
    fi

    if [ ! -d "$OUTPUT_PATH" ]; then
        echo "WARNING: OUTPUT_PATH does not exist, creating: $OUTPUT_PATH"
        mkdir -p "$OUTPUT_PATH" || {
            echo "ERROR: Failed to create OUTPUT_PATH"
            errors=$((errors + 1))
        }
    fi

    # Validate MODELS
    IFS=',' read -ra MODEL_ARRAY <<< "$MODELS"
    for model in "${MODEL_ARRAY[@]}"; do
        model=$(echo "$model" | xargs)  # trim whitespace
        if [[ ! "$model" =~ ^(BLINK|FarmCPU|MLM|MLMM|SUPER|CMLM)$ ]]; then
            echo "ERROR: Invalid model '$model'. Allowed: BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM"
            errors=$((errors + 1))
        fi
    done

    # Validate PCA_COMPONENTS (integer 0-20)
    if [[ ! "$PCA_COMPONENTS" =~ ^[0-9]+$ ]] || [ "$PCA_COMPONENTS" -lt 0 ] || [ "$PCA_COMPONENTS" -gt 20 ]; then
        echo "ERROR: PCA_COMPONENTS must be integer 0-20 (got: $PCA_COMPONENTS)"
        errors=$((errors + 1))
    fi

    # Validate SNP_THRESHOLD (scientific notation)
    if ! echo "$SNP_THRESHOLD" | grep -qE '^[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$'; then
        echo "ERROR: SNP_THRESHOLD must be numeric (got: $SNP_THRESHOLD)"
        errors=$((errors + 1))
    fi

    # Validate MAF_FILTER (0.0-0.5)
    if ! awk -v maf="$MAF_FILTER" 'BEGIN {exit !(maf >= 0 && maf <= 0.5)}'; then
        echo "ERROR: MAF_FILTER must be 0.0-0.5 (got: $MAF_FILTER)"
        errors=$((errors + 1))
    fi

    # Validate TRAIT_INDEX (positive integer)
    if [[ ! "$TRAIT_INDEX" =~ ^[0-9]+$ ]] || [ "$TRAIT_INDEX" -lt 2 ]; then
        echo "ERROR: TRAIT_INDEX must be integer >= 2 (got: $TRAIT_INDEX)"
        errors=$((errors + 1))
    fi

    if [ $errors -gt 0 ]; then
        echo ""
        echo "Configuration validation failed with $errors error(s)"
        echo "Please check your environment variables"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log_config() {
    echo "==========================================================================="
    echo "GAPIT3 GWAS Pipeline - Runtime Configuration"
    echo "==========================================================================="
    echo ""
    echo "Job Configuration:"
    echo "  Trait Index:      $TRAIT_INDEX"
    echo "  Data Path:        $DATA_PATH"
    echo "  Output Path:      $OUTPUT_PATH"
    echo ""
    echo "Analysis Parameters:"
    echo "  Models:           $MODELS"
    echo "  PCA Components:   $PCA_COMPONENTS"
    echo "  SNP Threshold:    $SNP_THRESHOLD"
    echo "  MAF Filter:       $MAF_FILTER"
    echo ""
    echo "Computational:"
    echo "  CPU Cores:        $CPU"
    echo "  OpenBLAS Threads: $OPENBLAS_NUM_THREADS"
    echo "  OMP Threads:      $OMP_NUM_THREADS"
    echo ""
    echo "Advanced Options:"
    echo "  Kinship Method:   $KINSHIP_METHOD"
    echo "  Correction:       $CORRECTION_METHOD"
    echo "  Max Iterations:   $MAX_ITERATIONS"
    echo ""
    if [ -n "$GENOTYPE_FILE" ]; then
        echo "File Overrides:"
        echo "  Genotype:         $GENOTYPE_FILE"
        [ -n "$PHENOTYPE_FILE" ] && echo "  Phenotype:        $PHENOTYPE_FILE"
        [ -n "$IDS_FILE" ] && echo "  IDs:              $IDS_FILE"
        echo ""
    fi
    echo "==========================================================================="
    echo ""
}

# ---------------------------------------------------------------------------
# Command Routing
# ---------------------------------------------------------------------------

case "$1" in
    run-single-trait)
        validate_config
        log_config

        exec Rscript /scripts/run_gwas_single_trait.R \
            --trait-index "$TRAIT_INDEX" \
            --data-dir "$DATA_PATH" \
            --output-dir "$OUTPUT_PATH" \
            --models "$MODELS" \
            --pca "$PCA_COMPONENTS" \
            --threshold "$SNP_THRESHOLD" \
            --maf "$MAF_FILTER" \
            --kinship-method "$KINSHIP_METHOD" \
            --correction "$CORRECTION_METHOD" \
            --max-iter "$MAX_ITERATIONS" \
            ${GENOTYPE_FILE:+--genotype-file "$GENOTYPE_FILE"} \
            ${PHENOTYPE_FILE:+--phenotype-file "$PHENOTYPE_FILE"} \
            ${IDS_FILE:+--ids-file "$IDS_FILE"}
        ;;

    collect-results)
        exec Rscript /scripts/collect_results.R \
            --output-dir "$OUTPUT_PATH" \
            --threshold "$SNP_THRESHOLD"
        ;;

    validate-inputs)
        exec Rscript /scripts/validate_inputs.R \
            --data-dir "$DATA_PATH"
        ;;

    *)
        echo "ERROR: Unknown command: $1"
        echo ""
        echo "Available commands:"
        echo "  run-single-trait  - Run GWAS analysis on single trait"
        echo "  collect-results   - Aggregate results from multiple traits"
        echo "  validate-inputs   - Validate input data files"
        echo ""
        echo "Example:"
        echo "  docker run -e TRAIT_INDEX=2 -e MODELS=BLINK gapit3:latest run-single-trait"
        exit 1
        ;;
esac
```

## .env.example Structure

**Purpose**: Documents ALL environment variables, used for local `docker run --env-file .env`

**File**: `.env.example`

```bash
# ===========================================================================
# GAPIT3 Pipeline - Environment Variable Configuration
# ===========================================================================
#
# This file documents ALL environment variables used by the container.
#
# Usage:
#
#   Local Development:
#     cp .env.example .env
#     # Edit .env with your values
#     docker run --env-file .env gapit3:latest run-single-trait
#
#   RunAI Deployment:
#     runai workspace submit job-name \
#       --environment TRAIT_INDEX=2 \
#       --environment DATA_PATH=/path/to/data \
#       --environment MODELS=BLINK
#
#   Argo Deployment:
#     env:
#       - name: TRAIT_INDEX
#         value: "{{inputs.parameters.trait-index}}"
#       - name: MODELS
#         value: "BLINK,FarmCPPU"
#
# ===========================================================================

# ---------------------------------------------------------------------------
# Job Configuration (Required in Production)
# ---------------------------------------------------------------------------

# Which trait column to analyze
# Value: Integer >= 2 (column 1 is Taxa, column 2+ are traits)
# Example: TRAIT_INDEX=2 analyzes first trait column
TRAIT_INDEX=2

# Input data directory containing: genotype/, phenotype/, metadata/
# Local: Absolute path on your machine
# RunAI/Argo: Path as mounted in container (typically /data)
DATA_PATH=/data

# Output directory for results
# Local: Absolute path on your machine
# RunAI/Argo: Path as mounted in container (typically /outputs)
OUTPUT_PATH=/outputs

# ---------------------------------------------------------------------------
# GAPIT Analysis Parameters (Core Configuration)
# ---------------------------------------------------------------------------

# GWAS models to run (comma-separated, no spaces)
#
# Available models:
#   BLINK    - Fast, effective (recommended for large datasets)
#   FarmCPU  - Accurate, slower (recommended for final analysis)
#   MLM      - Basic mixed linear model
#   MLMM     - Multi-locus mixed model
#   SUPER    - Settlement of MLM Under Progressively Exclusive Relationship
#   CMLM     - Compressed MLM
#
# Recommendations:
#   - Fast testing:      BLINK
#   - Production:        BLINK,FarmCPU
#   - Comprehensive:     BLINK,FarmCPU,MLM
#
# Performance: BLINK alone is ~2x faster than BLINK,FarmCPU
#
# Default: BLINK,FarmCPU
MODELS=BLINK,FarmCPU

# Number of Principal Components for population structure correction
#
# Range: 0-20
#   0     = No population structure correction (not recommended for GWAS)
#   3-5   = Standard for most plant GWAS (recommended)
#   5-10  = Strong population structure
#   >10   = Usually unnecessary, may over-correct
#
# Recommendation: Start with 3, increase if population structure is strong
#
# Default: 3
PCA_COMPONENTS=3

# SNP significance threshold (p-value)
#
# Common values:
#   5e-8  = Genome-wide significance (GWAS standard for humans)
#   1e-6  = Stricter threshold
#   1e-5  = Suggestive threshold (exploratory analysis)
#   1e-4  = Very permissive (not recommended)
#
# Note: Threshold depends on effective number of independent tests
#       Plant genomes with different LD may use different thresholds
#
# Default: 5e-8
SNP_THRESHOLD=5e-8

# Minor Allele Frequency (MAF) filter
#
# Remove SNPs with MAF below this value
# Range: 0.0-0.5
#
# Common values:
#   0.05  = Standard filter (5%, recommended)
#   0.01  = More permissive (keep rarer variants)
#   0.00  = No filtering (not recommended, includes singletons)
#
# Rationale: Low-frequency variants have less power and higher error rates
#
# Default: 0.05
MAF_FILTER=0.05

# ---------------------------------------------------------------------------
# Computational Resources
# ---------------------------------------------------------------------------

# Number of CPU cores allocated to job
# Used to set thread counts if OPENBLAS_NUM_THREADS not specified
# Should match --cpu-core-request in RunAI or resources.requests.cpu in Argo
#
# Default: 12
CPU=12

# OpenBLAS thread count for linear algebra operations
# Should match CPU allocation
# Override only if you need different threading behavior
#
# Default: Matches CPU
# OPENBLAS_NUM_THREADS=12

# OpenMP thread count
# Should match CPU allocation
#
# Default: Matches CPU
# OMP_NUM_THREADS=12

# ---------------------------------------------------------------------------
# File Path Overrides (Advanced, Optional)
# ---------------------------------------------------------------------------

# Override default genotype file path
# Default: Auto-detects *.hmp.txt in DATA_PATH/genotype/
# Use this to specify exact file if multiple genotype files present
# GENOTYPE_FILE=/data/genotype/my_specific_genotype.hmp.txt

# Override default phenotype file path
# Default: Auto-detects *.txt in DATA_PATH/phenotype/
# PHENOTYPE_FILE=/data/phenotype/my_specific_phenotype.txt

# Override default accession IDs file
# Default: DATA_PATH/metadata/ids_gwas.txt
# IDS_FILE=/data/metadata/my_specific_ids.txt

# ---------------------------------------------------------------------------
# Advanced GAPIT Options (Rarely Modified)
# ---------------------------------------------------------------------------

# Kinship matrix calculation method
#
# Options:
#   VanRaden  - Fast, most common (recommended)
#   EMMA      - Efficient Mixed Model Association
#   Loiselle  - Alternative method
#
# Default: VanRaden
# KINSHIP_METHOD=VanRaden

# Multiple testing correction method
#
# Options:
#   FDR         - False Discovery Rate (Benjamini-Hochberg)
#   Bonferroni  - Conservative family-wise error rate
#   None        - No correction (not recommended)
#
# Default: FDR
# CORRECTION_METHOD=FDR

# Maximum iterations for iterative models (BLINK, FarmCPU)
#
# Range: 1-100
# Higher values = more thorough but slower
# Most datasets converge within 10 iterations
#
# Default: 10
# MAX_ITERATIONS=10
```

## RunAI Deployment Example

**Complete job submission:**

```bash
#!/bin/bash
# Submit GAPIT3 job to RunAI cluster
# ALL configuration via --environment flags

TRAIT_INDEX=2
JOB_NAME="gapit3-trait-${TRAIT_INDEX}"

runai workspace submit "$JOB_NAME" \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest \
  --cpu-core-request 12 \
  --cpu-memory-request 32G \
  \
  `# Mount data volumes` \
  --host-path path=/hpi/hpi_dev/users/eberrigan/data,mount=/data \
  --host-path path=/hpi/hpi_dev/users/eberrigan/outputs,mount=/outputs,readwrite \
  \
  `# Configure job identity and paths` \
  --environment TRAIT_INDEX="$TRAIT_INDEX" \
  --environment DATA_PATH=/data \
  --environment OUTPUT_PATH=/outputs \
  \
  `# Configure GAPIT analysis` \
  --environment MODELS=BLINK,FarmCPU \
  --environment PCA_COMPONENTS=3 \
  --environment SNP_THRESHOLD=5e-8 \
  --environment MAF_FILTER=0.05 \
  \
  `# Configure compute resources` \
  --environment CPU=12 \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  \
  `# Run the analysis` \
  --command -- /scripts/entrypoint.sh run-single-trait
```

## Argo Workflow Example (Future)

**Workflow YAML with env parameters:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: gapit3-gwas-
spec:
  entrypoint: gwas-pipeline

  arguments:
    parameters:
    # User-configurable parameters
    - name: data-path
      value: "/data"
    - name: output-path
      value: "/outputs"
    - name: models
      value: "BLINK,FarmCPU"
    - name: pca-components
      value: "3"
    - name: snp-threshold
      value: "5e-8"
    - name: start-trait
      value: "2"
    - name: end-trait
      value: "187"

  templates:
  - name: gwas-pipeline
    steps:
    - - name: run-traits
        template: single-trait
        arguments:
          parameters:
          - name: trait-index
            value: "{{item}}"
        withSequence:
          start: "{{workflow.parameters.start-trait}}"
          end: "{{workflow.parameters.end-trait}}"

  - name: single-trait
    inputs:
      parameters:
      - name: trait-index
    container:
      image: ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest
      command: ["/scripts/entrypoint.sh"]
      args: ["run-single-trait"]

      # ALL configuration via environment variables
      env:
      - name: TRAIT_INDEX
        value: "{{inputs.parameters.trait-index}}"
      - name: DATA_PATH
        value: "{{workflow.parameters.data-path}}"
      - name: OUTPUT_PATH
        value: "{{workflow.parameters.output-path}}"
      - name: MODELS
        value: "{{workflow.parameters.models}}"
      - name: PCA_COMPONENTS
        value: "{{workflow.parameters.pca-components}}"
      - name: SNP_THRESHOLD
        value: "{{workflow.parameters.snp-threshold}}"
      - name: CPU
        value: "12"
      - name: OPENBLAS_NUM_THREADS
        value: "12"

      resources:
        requests:
          cpu: "12"
          memory: "32Gi"

      volumeMounts:
      - name: data
        mountPath: /data
      - name: outputs
        mountPath: /outputs
```

## Migration Strategy

### Phase 1: Update Container (Backward Compatible)

1. Modify `scripts/entrypoint.sh` to read env vars
2. Update R scripts to accept command-line args
3. Remove `config/config.yaml`
4. Defaults ensure old usage still works

### Phase 2: Update Deployment Scripts

1. Update `scripts/submit-all-traits-runai.sh` to pass env vars
2. Add helper functions for common configurations
3. Document all available env vars

### Phase 3: Update Argo Workflows

1. Update workflow templates with env specifications
2. Add workflow parameters that map to env vars
3. Test generated workflows

### Phase 4: Documentation

1. Create comprehensive `.env.example`
2. Update all guides with env var examples
3. Add troubleshooting for common validation errors

## Testing Strategy

```bash
# Test 1: Default configuration
docker run gapit3:latest run-single-trait --dry-run
# Should use all defaults

# Test 2: Custom MODELS
docker run -e MODELS=BLINK gapit3:latest run-single-trait --dry-run
# Should show MODELS: BLINK

# Test 3: Complete custom config
docker run \
  -e TRAIT_INDEX=5 \
  -e MODELS=BLINK,FarmCPU \
  -e PCA_COMPONENTS=5 \
  -e SNP_THRESHOLD=1e-6 \
  gapit3:latest run-single-trait --dry-run

# Test 4: Invalid values (should fail validation)
docker run -e MODELS=InvalidModel gapit3:latest run-single-trait
# Should show validation error

# Test 5: .env file
echo "MODELS=BLINK" > test.env
echo "PCA_COMPONENTS=5" >> test.env
docker run --env-file test.env gapit3:latest run-single-trait --dry-run
# Should use values from file
```

## Success Criteria

- [ ] Can run with any combination of env vars
- [ ] Validation catches invalid values with helpful errors
- [ ] `.env.example` documents all options clearly
- [ ] Same image works for RunAI and Argo
- [ ] No rebuild needed for configuration changes
- [ ] Backward compatible (defaults when vars unset)
