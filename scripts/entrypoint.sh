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

# GAPIT Analysis Parameters
MODELS="${MODELS:-BLINK,FarmCPU}"
PCA_COMPONENTS="${PCA_COMPONENTS:-3}"
SNP_THRESHOLD="${SNP_THRESHOLD:-5e-8}"
MAF_FILTER="${MAF_FILTER:-0.05}"
MULTIPLE_ANALYSIS="${MULTIPLE_ANALYSIS:-TRUE}"

# Computational Resources
OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-${CPU_LIMIT:-12}}"
OMP_NUM_THREADS="${OMP_NUM_THREADS:-${CPU_LIMIT:-12}}"

# Advanced Options (rarely changed)
KINSHIP_METHOD="${KINSHIP_METHOD:-VanRaden}"
CORRECTION_METHOD="${CORRECTION_METHOD:-FDR}"
MAX_ITERATIONS="${MAX_ITERATIONS:-10}"

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

validate_models() {
    local valid_models="BLINK FarmCPU MLM MLMM SUPER CMLM"
    local models_array

    # Split comma-separated models
    IFS=',' read -ra models_array <<< "$MODELS"

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

validate_pca_components() {
    if ! [[ "$PCA_COMPONENTS" =~ ^[0-9]+$ ]]; then
        log_error "PCA_COMPONENTS must be an integer, got: '$PCA_COMPONENTS'"
        return 1
    fi

    if [ "$PCA_COMPONENTS" -lt 0 ] || [ "$PCA_COMPONENTS" -gt 20 ]; then
        log_error "PCA_COMPONENTS must be between 0 and 20, got: $PCA_COMPONENTS"
        log_error "Use 0 to disable PCA correction"
        return 1
    fi

    return 0
}

validate_threshold() {
    # Check if it's a valid number in scientific notation
    if ! echo "$SNP_THRESHOLD" | grep -qE '^[0-9]+\.?[0-9]*[eE]?-?[0-9]*$'; then
        log_error "SNP_THRESHOLD must be a number (e.g., 5e-8), got: '$SNP_THRESHOLD'"
        return 1
    fi

    return 0
}

validate_maf_filter() {
    # Check if it's a valid number
    if ! echo "$MAF_FILTER" | grep -qE '^[0-9]+\.?[0-9]*$'; then
        log_error "MAF_FILTER must be a number, got: '$MAF_FILTER'"
        return 1
    fi

    # Check range (using awk for floating point comparison)
    if awk -v maf="$MAF_FILTER" 'BEGIN { exit !(maf < 0.0 || maf > 0.5) }'; then
        log_error "MAF_FILTER must be between 0.0 and 0.5, got: $MAF_FILTER"
        log_error "Use 0.0 to disable filtering"
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

    # Check data path
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
        return 1
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

    log_info "Validating configuration..."

    if ! validate_trait_index; then
        errors=$((errors + 1))
    fi

    if ! validate_models; then
        errors=$((errors + 1))
    fi

    if ! validate_pca_components; then
        errors=$((errors + 1))
    fi

    if ! validate_threshold; then
        errors=$((errors + 1))
    fi

    if ! validate_maf_filter; then
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
    echo "  Models:           $MODELS"
    echo "  PCA Components:   $PCA_COMPONENTS"
    echo "  SNP Threshold:    $SNP_THRESHOLD"
    echo "  MAF Filter:       $MAF_FILTER"
    echo "  Multiple Analysis: $MULTIPLE_ANALYSIS"
    echo ""
    echo -e "${BLUE}Computational Resources:${NC}"
    echo "  OpenBLAS Threads: $OPENBLAS_NUM_THREADS"
    echo "  OMP Threads:      $OMP_NUM_THREADS"
    echo ""
    echo -e "${BLUE}Advanced Options:${NC}"
    echo "  Kinship Method:   $KINSHIP_METHOD"
    echo "  Correction:       $CORRECTION_METHOD"
    echo "  Max Iterations:   $MAX_ITERATIONS"
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

    # Execute R script with parameters
    exec Rscript /scripts/run_gwas_single_trait.R \
        --trait-index "$TRAIT_INDEX" \
        --genotype "$GENOTYPE_FILE" \
        --phenotype "$PHENOTYPE_FILE" \
        --ids "$ACCESSION_IDS_FILE" \
        --output-dir "$OUTPUT_PATH" \
        --models "$MODELS" \
        --pca "$PCA_COMPONENTS" \
        --threads "$OPENBLAS_NUM_THREADS"
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

${BLUE}Environment Variables:${NC}
  See .env.example for complete documentation

  Key variables:
    TRAIT_INDEX         Trait column index (default: 2)
    MODELS              GWAS models (default: BLINK,FarmCPU)
    PCA_COMPONENTS      PCA components (default: 3)
    SNP_THRESHOLD       P-value threshold (default: 5e-8)
    DATA_PATH           Input data directory (default: /data)
    OUTPUT_PATH         Output directory (default: /outputs)

${BLUE}Examples:${NC}
  # Run with defaults
  docker run --rm \\
    -v /data:/data \\
    -v /outputs:/outputs \\
    gapit3:latest

  # Run with custom parameters
  docker run --rm \\
    -e TRAIT_INDEX=2 \\
    -e MODELS=BLINK \\
    -e PCA_COMPONENTS=5 \\
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
    echo "Current Environment Variable Values"
    echo "==========================================================================="
    echo ""
    echo "  TRAIT_INDEX:      $TRAIT_INDEX"
    echo "  MODELS:           $MODELS"
    echo "  PCA_COMPONENTS:   $PCA_COMPONENTS"
    echo "  SNP_THRESHOLD:    $SNP_THRESHOLD"
    echo "  MAF_FILTER:       $MAF_FILTER"
    echo "  DATA_PATH:        $DATA_PATH"
    echo "  OUTPUT_PATH:      $OUTPUT_PATH"
    echo "  GENOTYPE_FILE:    $GENOTYPE_FILE"
    echo "  PHENOTYPE_FILE:   $PHENOTYPE_FILE"
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
