#!/bin/bash
# ==============================================================================
# GAPIT3 GWAS Pipeline - Container Entrypoint
# ==============================================================================
# Handles runtime configuration via environment variables
# Validates configuration and executes appropriate command
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Environment Variables with Defaults
# ==============================================================================

# Job Identity and Paths
TRAIT_INDEX="${TRAIT_INDEX:-2}"
DATA_PATH="${DATA_PATH:-/data}"
OUTPUT_PATH="${OUTPUT_PATH:-/outputs}"
GENOTYPE_FILE="${GENOTYPE_FILE:-${DATA_PATH}/genotype/all_chromosomes_binary.hmp.txt}"
PHENOTYPE_FILE="${PHENOTYPE_FILE:-${DATA_PATH}/phenotype/traits.txt}"
ACCESSION_IDS_FILE="${ACCESSION_IDS_FILE:-${DATA_PATH}/phenotype/accession_ids.txt}"

# ==============================================================================
# GAPIT Analysis Parameters (v3.0.0 naming convention)
# ==============================================================================
# Parameter names match GAPIT's native naming (dots replaced with underscores)
# Legacy names (MODELS, PCA_COMPONENTS, MAF_FILTER) are supported with warnings

# Core GAPIT Parameters (Tier 1) - Using GAPIT's exact defaults
MODEL="${MODEL:-MLM}"                     # GAPIT default: MLM
PCA_TOTAL="${PCA_TOTAL:-0}"               # GAPIT default: 0 (no PCA)
MULTIPLE_ANALYSIS="${MULTIPLE_ANALYSIS:-TRUE}"  # GAPIT default: TRUE

# SNP Filtering Parameters - Using GAPIT's exact defaults
SNP_MAF="${SNP_MAF:-0}"                   # GAPIT default: 0 (no MAF filtering)
SNP_FDR="${SNP_FDR:-}"                    # GAPIT default: 1 (effectively disabled, empty = disabled here)
SNP_THRESHOLD="${SNP_THRESHOLD:-0.05}"    # GAPIT default cutOff: 0.05

# Advanced GAPIT Parameters (Tier 2) - Using GAPIT's exact defaults
KINSHIP_ALGORITHM="${KINSHIP_ALGORITHM:-Zhang}"  # GAPIT default: Zhang
SNP_EFFECT="${SNP_EFFECT:-Add}"           # GAPIT default: Add
SNP_IMPUTE="${SNP_IMPUTE:-Middle}"        # GAPIT default: Middle

# Legacy parameter names (deprecated, for backward compatibility)
MODELS="${MODELS:-}"
PCA_COMPONENTS="${PCA_COMPONENTS:-}"
MAF_FILTER="${MAF_FILTER:-}"
KINSHIP_METHOD="${KINSHIP_METHOD:-}"
CORRECTION_METHOD="${CORRECTION_METHOD:-FDR}"
MAX_ITERATIONS="${MAX_ITERATIONS:-10}"

# Computational Resources
OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-${CPU_LIMIT:-12}}"
OMP_NUM_THREADS="${OMP_NUM_THREADS:-${CPU_LIMIT:-12}}"

# Export thread settings for R
export OPENBLAS_NUM_THREADS
export OMP_NUM_THREADS

# ==============================================================================
# Validation Functions
# ==============================================================================

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

# ==============================================================================
# Deprecation Handling
# ==============================================================================

handle_deprecated_params() {
    # Handle deprecated parameter names with warnings
    # New names take precedence over deprecated names

    # MODELS -> MODEL
    if [ -n "${MODELS:-}" ]; then
        if [ "$MODEL" = "MLM" ]; then
            # MODEL has default value, use MODELS
            log_warn "MODELS is deprecated, use MODEL instead"
            MODEL="$MODELS"
        fi
        # If MODEL is explicitly set, it takes precedence (no warning)
    fi

    # PCA_COMPONENTS -> PCA_TOTAL
    if [ -n "${PCA_COMPONENTS:-}" ]; then
        if [ "$PCA_TOTAL" = "0" ]; then
            # PCA_TOTAL has default value, use PCA_COMPONENTS
            log_warn "PCA_COMPONENTS is deprecated, use PCA_TOTAL instead"
            PCA_TOTAL="$PCA_COMPONENTS"
        fi
    fi

    # MAF_FILTER -> SNP_MAF
    if [ -n "${MAF_FILTER:-}" ]; then
        if [ "$SNP_MAF" = "0" ]; then
            # SNP_MAF has default value, use MAF_FILTER
            log_warn "MAF_FILTER is deprecated, use SNP_MAF instead"
            SNP_MAF="$MAF_FILTER"
        fi
    fi

    # KINSHIP_METHOD -> KINSHIP_ALGORITHM
    if [ -n "${KINSHIP_METHOD:-}" ]; then
        if [ "$KINSHIP_ALGORITHM" = "Zhang" ]; then
            # KINSHIP_ALGORITHM has default value, use KINSHIP_METHOD
            log_warn "KINSHIP_METHOD is deprecated, use KINSHIP_ALGORITHM instead"
            KINSHIP_ALGORITHM="$KINSHIP_METHOD"
        fi
    fi
}

# ==============================================================================
# Environment Detection
# ==============================================================================

detect_execution_environment() {
    # Detect whether running in Argo Workflows or RunAI environment
    # Returns:
    #   "argo" - Running in Argo Workflows (uses hostPath volumes)
    #   "runai" - Running in RunAI (uses NFS mounts via --host-path)
    #   "unknown" - Cannot determine (default to safer Argo mode)

    # Check for Argo Workflows environment variables
    if [ -n "${ARGO_WORKFLOW_NAME:-}" ] || [ -n "${ARGO_NODE_ID:-}" ]; then
        echo "argo"
        return 0
    fi

    # Check for Argo runtime directory
    if [ -d "/var/run/argo" ]; then
        echo "argo"
        return 0
    fi

    # Check for RunAI specific environment variables
    if [ -n "${RUNAI_JOB_NAME:-}" ] || [ -n "${RUNAI_JOB_UUID:-}" ]; then
        echo "runai"
        return 0
    fi

    # Default to Argo mode (safer - less strict validation)
    # This handles cases like local Docker runs or other orchestrators
    echo "unknown"
    return 0
}

validate_model() {
    local valid_models="BLINK FarmCPU MLM MLMM SUPER CMLM GLM"
    local models_array

    # Split comma-separated models
    IFS=',' read -ra models_array <<< "$MODEL"

    for model in "${models_array[@]}"; do
        # Trim whitespace
        model=$(echo "$model" | xargs)

        if [[ ! " $valid_models " =~ " $model " ]]; then
            log_error "Invalid model: '$model'"
            log_error "Valid options: $valid_models"
            return 1
        fi
    done

    return 0
}

validate_pca_total() {
    if ! [[ "$PCA_TOTAL" =~ ^[0-9]+$ ]]; then
        log_error "PCA_TOTAL must be an integer, got: '$PCA_TOTAL'"
        return 1
    fi

    if [ "$PCA_TOTAL" -lt 0 ] || [ "$PCA_TOTAL" -gt 20 ]; then
        log_error "PCA_TOTAL must be between 0 and 20, got: $PCA_TOTAL"
        log_error "Use 0 to disable PCA correction"
        return 1
    fi

    return 0
}

validate_kinship_algorithm() {
    local valid_algos="VanRaden Zhang Loiselle EMMA"

    if [[ ! " $valid_algos " =~ " $KINSHIP_ALGORITHM " ]]; then
        log_error "Invalid KINSHIP_ALGORITHM: '$KINSHIP_ALGORITHM'"
        log_error "Valid options: $valid_algos"
        return 1
    fi

    return 0
}

validate_snp_effect() {
    local valid_effects="Add Dom"

    if [[ ! " $valid_effects " =~ " $SNP_EFFECT " ]]; then
        log_error "Invalid SNP_EFFECT: '$SNP_EFFECT'"
        log_error "Valid options: $valid_effects"
        return 1
    fi

    return 0
}

validate_snp_impute() {
    local valid_impute="Middle Major Minor"

    if [[ ! " $valid_impute " =~ " $SNP_IMPUTE " ]]; then
        log_error "Invalid SNP_IMPUTE: '$SNP_IMPUTE'"
        log_error "Valid options: $valid_impute"
        return 1
    fi

    return 0
}

validate_threshold() {
    # Check if it's a valid number in scientific notation
    if ! echo "$SNP_THRESHOLD" | grep -qE '^[0-9]+\.?[0-9]*[eE]?-?[0-9]*$'; then
        log_error "Invalid threshold: SNP_THRESHOLD must be a numeric value (e.g., 5e-8), got: '$SNP_THRESHOLD'"
        return 1
    fi

    return 0
}

validate_snp_maf() {
    # Check if it's a valid number
    if ! echo "$SNP_MAF" | grep -qE '^[0-9]+\.?[0-9]*$'; then
        log_error "SNP_MAF must be a number, got: '$SNP_MAF'"
        return 1
    fi

    # Check range (using awk for floating point comparison)
    if awk -v maf="$SNP_MAF" 'BEGIN { exit !(maf < 0.0 || maf > 0.5) }'; then
        log_error "SNP_MAF must be between 0.0 and 0.5, got: $SNP_MAF"
        log_error "Use 0.0 to disable filtering"
        return 1
    fi

    return 0
}

validate_snp_fdr() {
    # SNP_FDR is optional - empty string means disabled
    if [ -z "$SNP_FDR" ]; then
        return 0
    fi

    # Check if it's a valid number
    if ! echo "$SNP_FDR" | grep -qE '^[0-9]+\.?[0-9]*$'; then
        log_error "SNP_FDR must be a number, got: '$SNP_FDR'"
        return 1
    fi

    # Check range (using awk for floating point comparison)
    if awk -v fdr="$SNP_FDR" 'BEGIN { exit !(fdr <= 0.0 || fdr > 1.0) }'; then
        log_error "SNP_FDR must be between 0.0 and 1.0, got: $SNP_FDR"
        log_error "Common values: 0.05 (5% FDR), 0.1 (10% FDR)"
        return 1
    fi

    return 0
}

validate_trait_index() {
    if ! [[ "$TRAIT_INDEX" =~ ^[0-9]+$ ]]; then
        log_error "TRAIT_INDEX must be an integer, got: '$TRAIT_INDEX'"
        return 1
    fi

    if [ "$TRAIT_INDEX" -lt 2 ]; then
        log_error "TRAIT_INDEX must be >= 2 (column 1 is Taxa), got: $TRAIT_INDEX"
        return 1
    fi

    return 0
}

validate_paths() {
    local missing_paths=()
    local mount_failures=()
    local exec_env

    # Detect execution environment
    exec_env=$(detect_execution_environment)

    # Log validation mode
    case "$exec_env" in
        argo)
            log_info "Validation mode: Argo Workflows (hostPath volumes)"
            log_info "Using directory existence checks (skipping mountpoint validation)"
            ;;
        runai)
            log_info "Validation mode: RunAI (NFS mounts)"
            log_info "Using mountpoint checks to detect infrastructure failures"
            ;;
        unknown)
            log_info "Validation mode: Unknown environment (using Argo-style validation)"
            log_info "Using directory existence checks (skipping mountpoint validation)"
            ;;
    esac

    # Only perform mountpoint checks for RunAI environment
    if [ "$exec_env" = "runai" ]; then
        # Check if mount points are actually mounted (not just directories)
        # This distinguishes infrastructure mount failures from missing files
        if ! mountpoint -q "$DATA_PATH" 2>/dev/null; then
            mount_failures+=("DATA_PATH=$DATA_PATH")
            log_error "INFRASTRUCTURE MOUNT FAILURE: $DATA_PATH is not a mount point"
            log_error "This indicates a Kubernetes/RunAI volume mount failure"
        fi

        if ! mountpoint -q "$OUTPUT_PATH" 2>/dev/null; then
            mount_failures+=("OUTPUT_PATH=$OUTPUT_PATH")
            log_error "INFRASTRUCTURE MOUNT FAILURE: $OUTPUT_PATH is not a mount point"
            log_error "This indicates a Kubernetes/RunAI volume mount failure"
        fi

        # If mounts failed, report infrastructure error and exit with code 2
        if [ ${#mount_failures[@]} -gt 0 ]; then
            log_error "=================================================================="
            log_error "INFRASTRUCTURE FAILURE (NOT A CONFIGURATION ERROR)"
            log_error "=================================================================="
            log_error "The following paths failed to mount from host:"
            for path in "${mount_failures[@]}"; do
                log_error "  - $path"
            done
            log_error ""
            log_error "This is likely due to:"
            log_error "  - Node mount table exhaustion"
            log_error "  - NFS/storage server connection limits"
            log_error "  - Kubernetes volume attach timeout"
            log_error "  - Mount propagation race condition"
            log_error ""
            log_error "Recommended actions:"
            log_error "  1. Check pod events: kubectl describe pod \$POD_NAME"
            log_error "  2. Retry this job (transient infrastructure issue)"
            log_error "  3. Reduce MAX_CONCURRENT to lower mount pressure"
            log_error "  4. Check node health: kubectl describe node \$NODE_NAME"
            return 2  # Exit code 2 = infrastructure failure (retryable)
        fi
    else
        # For Argo Workflows and unknown environments, use directory checks
        # hostPath volumes appear as regular directories, not mount points
        log_info "Skipping mountpoint validation (not applicable for $exec_env)"
    fi

    # Check data path exists
    if [ ! -d "$DATA_PATH" ]; then
        missing_paths+=("DATA_PATH=$DATA_PATH")
    fi

    # Check genotype file
    if [ ! -f "$GENOTYPE_FILE" ]; then
        missing_paths+=("GENOTYPE_FILE=$GENOTYPE_FILE")
    fi

    # Check phenotype file
    if [ ! -f "$PHENOTYPE_FILE" ]; then
        missing_paths+=("PHENOTYPE_FILE=$PHENOTYPE_FILE")
    fi

    # Accession IDs file is optional
    if [ -n "$ACCESSION_IDS_FILE" ] && [ "$ACCESSION_IDS_FILE" != "null" ] && [ ! -f "$ACCESSION_IDS_FILE" ]; then
        log_warn "ACCESSION_IDS_FILE not found (optional): $ACCESSION_IDS_FILE"
    fi

    if [ ${#missing_paths[@]} -gt 0 ]; then
        log_error "Missing required files or directories:"
        for path in "${missing_paths[@]}"; do
            log_error "  - $path"
        done
        return 1  # Exit code 1 = configuration error (not retryable)
    fi

    # Create output directory if it doesn't exist
    if [ ! -d "$OUTPUT_PATH" ]; then
        log_info "Creating output directory: $OUTPUT_PATH"
        mkdir -p "$OUTPUT_PATH"
    fi

    return 0
}

validate_config() {
    local errors=0

    # Handle deprecated parameter names first
    handle_deprecated_params

    log_info "Validating configuration..."

    if ! validate_trait_index; then
        errors=$((errors + 1))
    fi

    if ! validate_model; then
        errors=$((errors + 1))
    fi

    if ! validate_pca_total; then
        errors=$((errors + 1))
    fi

    if ! validate_threshold; then
        errors=$((errors + 1))
    fi

    if ! validate_snp_maf; then
        errors=$((errors + 1))
    fi

    if ! validate_snp_fdr; then
        errors=$((errors + 1))
    fi

    if ! validate_kinship_algorithm; then
        errors=$((errors + 1))
    fi

    if ! validate_snp_effect; then
        errors=$((errors + 1))
    fi

    if ! validate_snp_impute; then
        errors=$((errors + 1))
    fi

    if ! validate_paths; then
        errors=$((errors + 1))
    fi

    if [ $errors -gt 0 ]; then
        log_error "Configuration validation failed with $errors error(s)"
        return 1
    fi

    log_info "Configuration validation passed"
    return 0
}

# ==============================================================================
# Configuration Logging
# ==============================================================================

log_config() {
    echo ""
    echo "==========================================================================="
    echo "GAPIT3 GWAS Pipeline - Runtime Configuration"
    echo "==========================================================================="
    echo ""
    echo -e "${BLUE}Job Identity:${NC}"
    echo "  Trait Index:      $TRAIT_INDEX"
    echo "  Hostname:         $(hostname)"
    echo "  Environment:      $(detect_execution_environment)"
    echo "  Start Time:       $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "${BLUE}Input Paths:${NC}"
    echo "  Data Path:        $DATA_PATH"
    echo "  Genotype File:    $GENOTYPE_FILE"
    echo "  Phenotype File:   $PHENOTYPE_FILE"
    echo "  Accession IDs:    ${ACCESSION_IDS_FILE:-none}"
    echo ""
    echo -e "${BLUE}Output:${NC}"
    echo "  Output Path:      $OUTPUT_PATH"
    echo ""
    echo -e "${BLUE}GAPIT Parameters:${NC}"
    echo "  model:            $MODEL"
    echo "  PCA.total:        $PCA_TOTAL"
    echo "  Multiple_analysis: $MULTIPLE_ANALYSIS"
    echo ""
    echo -e "${BLUE}SNP Filtering:${NC}"
    echo "  SNP.MAF:          $SNP_MAF"
    echo "  SNP.FDR:          ${SNP_FDR:-disabled}"
    echo "  SNP_THRESHOLD:    $SNP_THRESHOLD"
    echo ""
    echo -e "${BLUE}Advanced GAPIT Parameters:${NC}"
    echo "  kinship.algorithm: $KINSHIP_ALGORITHM"
    echo "  SNP.effect:       $SNP_EFFECT"
    echo "  SNP.impute:       $SNP_IMPUTE"
    echo ""
    echo -e "${BLUE}Computational Resources:${NC}"
    echo "  OpenBLAS Threads: $OPENBLAS_NUM_THREADS"
    echo "  OMP Threads:      $OMP_NUM_THREADS"
    echo ""
    echo "==========================================================================="
    echo ""
}

# ==============================================================================
# Command Execution
# ==============================================================================

run_single_trait() {
    log_info "Executing single-trait GWAS analysis..."

    # Validate configuration
    if ! validate_config; then
        log_error "Configuration validation failed. Exiting."
        exit 1
    fi

    # Log configuration
    log_config

    # Build R script command with parameters
    # Note: R script still uses --models and --pca flags for backward compatibility
    local cmd="Rscript /scripts/run_gwas_single_trait.R \
        --trait-index $TRAIT_INDEX \
        --genotype $GENOTYPE_FILE \
        --phenotype $PHENOTYPE_FILE \
        --ids $ACCESSION_IDS_FILE \
        --output-dir $OUTPUT_PATH \
        --models $MODEL \
        --pca $PCA_TOTAL \
        --maf $SNP_MAF \
        --threads $OPENBLAS_NUM_THREADS"

    # Add optional SNP_FDR parameter if set
    if [ -n "$SNP_FDR" ]; then
        cmd="$cmd --snp-fdr $SNP_FDR"
    fi

    # Execute R script
    exec $cmd
}

run_aggregation() {
    log_info "Executing results aggregation..."

    # Validate output path exists
    if [ ! -d "$OUTPUT_PATH" ]; then
        log_error "Output path does not exist: $OUTPUT_PATH"
        exit 1
    fi

    # Log basic config
    echo ""
    echo "==========================================================================="
    echo "GAPIT3 GWAS Pipeline - Results Aggregation"
    echo "==========================================================================="
    echo ""
    echo "  Output Path:      $OUTPUT_PATH"
    echo "  Start Time:       $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "==========================================================================="
    echo ""

    # Execute aggregation R script
    exec Rscript /scripts/aggregate_results.R \
        --output-dir "$OUTPUT_PATH"
}

show_help() {
    cat << EOF
${GREEN}GAPIT3 GWAS Pipeline - Container Entrypoint${NC}

${BLUE}Usage:${NC}
  docker run [OPTIONS] IMAGE [COMMAND]

${BLUE}Available commands:${NC}
  run-single-trait    Run GWAS for a single trait (default)
  run-aggregation     Aggregate results from multiple traits
  help                Show this help message

${BLUE}Environment Variables (v3.0.0):${NC}
  See .env.example for complete documentation
  All defaults match GAPIT's native defaults for consistency.

  Core GAPIT Parameters:
    TRAIT_INDEX         Trait column index (default: 2)
    MODEL               GWAS models (default: MLM)
    PCA_TOTAL           PCA components (default: 0, no PCA)

  SNP Filtering:
    SNP_MAF             MAF threshold (default: 0, no filtering)
    SNP_FDR             FDR threshold (e.g., 0.05; default: disabled)
    SNP_THRESHOLD       P-value threshold (default: 0.05)

  Advanced GAPIT Parameters:
    KINSHIP_ALGORITHM   Kinship algorithm (default: Zhang)
    SNP_EFFECT          SNP effect model (default: Add)
    SNP_IMPUTE          Imputation method (default: Middle)

  Paths:
    DATA_PATH           Input data directory (default: /data)
    OUTPUT_PATH         Output directory (default: /outputs)

  Deprecated (still supported with warnings):
    MODELS -> MODEL, PCA_COMPONENTS -> PCA_TOTAL, MAF_FILTER -> SNP_MAF

${BLUE}Examples:${NC}
  # Run with defaults
  docker run --rm \\
    -v /data:/data \\
    -v /outputs:/outputs \\
    gapit3:latest

  # Run with custom parameters (v3.0.0 naming)
  docker run --rm \\
    -e TRAIT_INDEX=2 \\
    -e MODEL=BLINK \\
    -e PCA_TOTAL=5 \\
    -e SNP_MAF=0.05 \\
    gapit3:latest

  # Run aggregation
  docker run --rm \\
    -v /outputs:/outputs \\
    -e OUTPUT_PATH=/outputs \\
    gapit3:latest run-aggregation

${BLUE}For More Information:${NC}
  See .env.example in the repository for complete documentation
  https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline

EOF
}

# Display current environment variable configuration
show_current_config() {
    echo ""
    echo "==========================================================================="
    echo "Current Environment Variable Values (v3.0.0)"
    echo "==========================================================================="
    echo ""
    echo "  Core GAPIT Parameters:"
    echo "    TRAIT_INDEX:         $TRAIT_INDEX"
    echo "    MODEL:               $MODEL"
    echo "    PCA_TOTAL:           $PCA_TOTAL"
    echo "    MULTIPLE_ANALYSIS:   $MULTIPLE_ANALYSIS"
    echo ""
    echo "  SNP Filtering:"
    echo "    SNP_MAF:             $SNP_MAF"
    echo "    SNP_FDR:             ${SNP_FDR:-disabled}"
    echo "    SNP_THRESHOLD:       $SNP_THRESHOLD"
    echo ""
    echo "  Advanced GAPIT Parameters:"
    echo "    KINSHIP_ALGORITHM:   $KINSHIP_ALGORITHM"
    echo "    SNP_EFFECT:          $SNP_EFFECT"
    echo "    SNP_IMPUTE:          $SNP_IMPUTE"
    echo ""
    echo "  Paths:"
    echo "    DATA_PATH:           $DATA_PATH"
    echo "    OUTPUT_PATH:         $OUTPUT_PATH"
    echo "    GENOTYPE_FILE:       $GENOTYPE_FILE"
    echo "    PHENOTYPE_FILE:      $PHENOTYPE_FILE"
    echo ""
    echo "==========================================================================="
    echo ""
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

COMMAND="${1:-run-single-trait}"

case "$COMMAND" in
    run-single-trait)
        run_single_trait
        ;;
    run-aggregation)
        run_aggregation
        ;;
    help|--help|-h)
        # Handle deprecation warnings first so users see them
        handle_deprecated_params
        show_help
        show_current_config
        exit 0
        ;;
    # Legacy commands for backward compatibility
    validate)
        log_info "Running validation via new entrypoint"
        validate_config
        ;;
    extract-traits)
        log_info "Extracting trait manifest"
        PHENOTYPE="${2:-${PHENOTYPE_FILE}}"
        OUTPUT="${3:-/config/traits_manifest.yaml}"
        exec Rscript /scripts/extract_trait_names.R "$PHENOTYPE" "$OUTPUT"
        ;;
    bash|shell)
        log_warn "Starting interactive bash shell"
        exec /bin/bash
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
