#!/bin/bash
# ===========================================================================
# GAPIT3 Environment Validation Script
# ===========================================================================
# Validates .env configuration before submitting jobs to catch errors early
# ===========================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
VERBOSE=false
QUICK=false

# Cache for expensive checks
PHENOTYPE_COLUMNS=""

# ===========================================================================
# Helper Functions
# ===========================================================================

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    ERRORS=$((ERRORS + 1))
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    WARNINGS=$((WARNINGS + 1))
}

success() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${GREEN}OK: $1${NC}"
    fi
}

info() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}INFO: $1${NC}"
    fi
}

section() {
    echo ""
    echo -e "${BLUE}━━━ $1${NC}"
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Validates GAPIT3 GWAS configuration before job submission.

OPTIONS:
    --env-file PATH    Path to .env file (default: .env in project root)
    --verbose, -v      Show detailed output for all checks
    --quick, -q        Skip slow checks (cluster files, image pull)
    --help, -h         Show this help message

EXAMPLES:
    # Validate current .env
    ./scripts/validate-env.sh

    # Validate specific env file
    ./scripts/validate-env.sh --env-file /path/to/.env

    # Quick validation (skip cluster checks)
    ./scripts/validate-env.sh --quick

    # Verbose output
    ./scripts/validate-env.sh --verbose

EXIT CODES:
    0 - Validation passed (no errors, warnings OK)
    1 - Validation failed (errors found)
    2 - Script error (missing file, invalid arguments)

EOF
}

# ===========================================================================
# Validation Functions
# ===========================================================================

check_environment_file() {
    section "Environment File"

    # Check file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        error ".env file not found: $ENV_FILE"
        return
    fi
    success ".env file exists: $ENV_FILE"

    # Check file is readable
    if [[ ! -r "$ENV_FILE" ]]; then
        error ".env file is not readable: $ENV_FILE"
        return
    fi
    success ".env file is readable"

    # Check required variables
    # Note: v3.0.0 uses MODEL/PCA_TOTAL/SNP_MAF, but we accept legacy MODELS/PCA_COMPONENTS/MAF_FILTER
    # DATA_PATH and OUTPUT_PATH are also accepted as alternatives to DATA_PATH_HOST/OUTPUT_PATH_HOST
    local required_vars=(
        "IMAGE"
        "GENOTYPE_FILE" "PHENOTYPE_FILE"
        "START_TRAIT" "END_TRAIT"
        "PROJECT" "JOB_PREFIX"
        "CPU" "MEMORY" "MAX_CONCURRENT"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required variable not set: $var"
        else
            success "$var is set"
        fi
    done

    # Check DATA_PATH (v3.0.0) or DATA_PATH_HOST (legacy)
    if [[ -z "${DATA_PATH:-}" ]] && [[ -z "${DATA_PATH_HOST:-}" ]]; then
        error "DATA_PATH or DATA_PATH_HOST not set"
    elif [[ -n "${DATA_PATH_HOST:-}" ]] && [[ -z "${DATA_PATH:-}" ]]; then
        warning "DATA_PATH_HOST is deprecated, use DATA_PATH instead"
        success "DATA_PATH_HOST is set (legacy)"
    else
        success "DATA_PATH is set"
    fi

    # Check OUTPUT_PATH (v3.0.0) or OUTPUT_PATH_HOST (legacy)
    if [[ -z "${OUTPUT_PATH:-}" ]] && [[ -z "${OUTPUT_PATH_HOST:-}" ]]; then
        error "OUTPUT_PATH or OUTPUT_PATH_HOST not set"
    elif [[ -n "${OUTPUT_PATH_HOST:-}" ]] && [[ -z "${OUTPUT_PATH:-}" ]]; then
        warning "OUTPUT_PATH_HOST is deprecated, use OUTPUT_PATH instead"
        success "OUTPUT_PATH_HOST is set (legacy)"
    else
        success "OUTPUT_PATH is set"
    fi

    # Check MODEL (v3.0.0) or MODELS (legacy)
    if [[ -z "${MODEL:-}" ]] && [[ -z "${MODELS:-}" ]]; then
        error "MODEL or MODELS not set"
    elif [[ -n "${MODELS:-}" ]] && [[ -z "${MODEL:-}" ]]; then
        warning "MODELS is deprecated, use MODEL instead"
        success "MODELS is set (legacy)"
    else
        success "MODEL is set"
    fi

    # Check PCA_TOTAL (v3.0.0) or PCA_COMPONENTS (legacy)
    if [[ -z "${PCA_TOTAL:-}" ]] && [[ -z "${PCA_COMPONENTS:-}" ]]; then
        warning "PCA_TOTAL not set (will use GAPIT default: 0)"
    elif [[ -n "${PCA_COMPONENTS:-}" ]] && [[ -z "${PCA_TOTAL:-}" ]]; then
        warning "PCA_COMPONENTS is deprecated, use PCA_TOTAL instead"
        success "PCA_COMPONENTS is set (legacy)"
    else
        success "PCA_TOTAL is set"
    fi
}

check_docker_image() {
    section "Docker Image"

    if [[ -z "${IMAGE:-}" ]]; then
        error "IMAGE variable not set"
        return
    fi
    success "IMAGE defined: $IMAGE"

    # Validate tag format
    if [[ ! "$IMAGE" =~ ^ghcr\.io/.+:.+$ ]]; then
        warning "IMAGE format unusual (expected: ghcr.io/org/repo:tag)"
    fi

    # Check if image exists (reuse existing validation logic)
    if [[ "$QUICK" == "true" ]]; then
        info "Skipping image validation in quick mode"
        return
    fi

    # Try docker manifest inspect
    if command -v docker >/dev/null 2>&1; then
        if docker manifest inspect "$IMAGE" >/dev/null 2>&1; then
            success "Image exists in registry (verified with docker)"
            return
        fi
    fi

    # Try gh CLI
    if command -v gh >/dev/null 2>&1; then
        local tag="${IMAGE##*:}"
        if gh api user/packages/container/gapit3-gwas-pipeline/versions 2>/dev/null | grep -q "\"$tag\""; then
            success "Image exists in registry (verified with gh CLI)"
            return
        else
            error "Image tag not found in registry: $tag"
            info "Check available tags: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/pkgs/container/gapit3-gwas-pipeline"
            return
        fi
    fi

    warning "Cannot verify image (docker/gh CLI not available)"
    info "Image will be validated when jobs start"
}

check_cluster_paths() {
    section "Cluster Paths"

    # Check DATA_PATH (v3.0.0) or DATA_PATH_HOST (legacy)
    local data_path="${DATA_PATH:-${DATA_PATH_HOST:-}}"
    if [[ -z "$data_path" ]]; then
        error "DATA_PATH or DATA_PATH_HOST not set"
    else
        # Check is absolute path
        if [[ ! "$data_path" =~ ^/ ]]; then
            error "DATA_PATH must be absolute path: $data_path"
        else
            success "DATA_PATH is absolute: $data_path"
        fi

        # Note: We cannot reliably verify cluster paths exist from local machine
        # The container entrypoint will validate paths when jobs start
        info "Cluster path existence will be validated when jobs start"
    fi

    # Check OUTPUT_PATH (v3.0.0) or OUTPUT_PATH_HOST (legacy)
    local output_path="${OUTPUT_PATH:-${OUTPUT_PATH_HOST:-}}"
    if [[ -z "$output_path" ]]; then
        error "OUTPUT_PATH or OUTPUT_PATH_HOST not set"
    else
        # Check is absolute path
        if [[ ! "$output_path" =~ ^/ ]]; then
            error "OUTPUT_PATH must be absolute path: $output_path"
        else
            success "OUTPUT_PATH is absolute: $output_path"
        fi

        info "Output directory will be created by jobs if it doesn't exist"
    fi
}

check_data_files() {
    section "Data Files"

    if [[ "$QUICK" == "true" ]]; then
        info "Skipping data file checks in quick mode"
        return
    fi

    # Helper to check file
    check_file() {
        local var_name=$1
        local file_path=$2
        local min_size=$3

        if [[ -z "$file_path" ]]; then
            error "$var_name not set"
            return
        fi

        # Build full path (use DATA_PATH v3.0.0, fallback to DATA_PATH_HOST legacy)
        local data_path="${DATA_PATH:-${DATA_PATH_HOST:-}}"
        local full_path="$data_path${file_path#/data}"

        # Try to access file (handle Windows mount)
        local check_path="$full_path"
        if [[ ! -f "$full_path" ]]; then
            # Try Windows Z: mount
            local win_path="Z:${full_path#/hpi/hpi_dev}"
            if [[ -f "$win_path" ]]; then
                check_path="$win_path"
            fi
        fi

        if [[ ! -f "$check_path" ]]; then
            error "$var_name not found: $full_path"
            return
        fi

        # Check file size
        local size=$(stat -f%z "$check_path" 2>/dev/null || stat -c%s "$check_path" 2>/dev/null || echo 0)
        if [[ $size -lt $min_size ]]; then
            warning "$var_name seems too small: $(numfmt --to=iec $size 2>/dev/null || echo ${size}B) (expected >$(numfmt --to=iec $min_size 2>/dev/null || echo ${min_size}B))"
        else
            success "$var_name: $(numfmt --to=iec $size 2>/dev/null || echo ${size}B)"
        fi
    }

    check_file "GENOTYPE_FILE" "$GENOTYPE_FILE" 1048576  # 1MB
    check_file "PHENOTYPE_FILE" "$PHENOTYPE_FILE" 1024   # 1KB

    if [[ -n "${ACCESSION_IDS_FILE:-}" ]]; then
        check_file "ACCESSION_IDS_FILE" "$ACCESSION_IDS_FILE" 100  # 100B
    fi
}

check_phenotype_structure() {
    section "Phenotype File Structure"

    if [[ "$QUICK" == "true" ]]; then
        info "Skipping phenotype structure check in quick mode"
        return
    fi

    # Build phenotype file path (use DATA_PATH v3.0.0, fallback to DATA_PATH_HOST legacy)
    local data_path="${DATA_PATH:-${DATA_PATH_HOST:-}}"
    local pheno_path="$data_path${PHENOTYPE_FILE#/data}"

    # Try Windows mount if direct access fails
    if [[ ! -f "$pheno_path" ]]; then
        local win_path="Z:${pheno_path#/hpi/hpi_dev}"
        if [[ -f "$win_path" ]]; then
            pheno_path="$win_path"
        fi
    fi

    if [[ ! -f "$pheno_path" ]]; then
        error "Cannot check phenotype structure: file not accessible"
        return
    fi

    # Count columns
    PHENOTYPE_COLUMNS=$(head -1 "$pheno_path" | awk -F'\t' '{print NF}')
    if [[ -z "$PHENOTYPE_COLUMNS" ]] || [[ "$PHENOTYPE_COLUMNS" -eq 0 ]]; then
        error "Cannot determine phenotype column count"
        return
    fi
    success "Total columns: $PHENOTYPE_COLUMNS"

    # Check first column is Taxa
    local first_col=$(head -1 "$pheno_path" | cut -f1)
    if [[ "$first_col" != "Taxa" ]]; then
        error "First column should be 'Taxa', found: '$first_col'"
    else
        success "First column is 'Taxa'"
    fi

    # Check file has at least 2 rows (header + data)
    local row_count=$(wc -l < "$pheno_path")
    if [[ $row_count -lt 2 ]]; then
        error "Phenotype file has no data rows (only $row_count rows)"
    else
        success "Data rows: $((row_count - 1))"
    fi
}

check_trait_indices() {
    section "Trait Indices"

    if [[ -z "${START_TRAIT:-}" ]] || [[ -z "${END_TRAIT:-}" ]]; then
        error "START_TRAIT or END_TRAIT not set"
        return
    fi

    # Check START_TRAIT >= 2
    if [[ $START_TRAIT -lt 2 ]]; then
        error "START_TRAIT must be >= 2 (column 1 is Taxa), found: $START_TRAIT"
    else
        success "START_TRAIT: $START_TRAIT"
    fi

    # Check END_TRAIT <= column count (if we have it)
    if [[ -n "$PHENOTYPE_COLUMNS" ]] && [[ $END_TRAIT -gt $PHENOTYPE_COLUMNS ]]; then
        error "END_TRAIT ($END_TRAIT) exceeds column count ($PHENOTYPE_COLUMNS)"
    elif [[ -n "$PHENOTYPE_COLUMNS" ]]; then
        success "END_TRAIT: $END_TRAIT (within bounds)"
    else
        info "END_TRAIT: $END_TRAIT (cannot verify bounds without phenotype file)"
    fi

    # Check START <= END
    if [[ $START_TRAIT -gt $END_TRAIT ]]; then
        error "START_TRAIT ($START_TRAIT) > END_TRAIT ($END_TRAIT)"
        return
    fi

    # Calculate number of traits
    local num_traits=$((END_TRAIT - START_TRAIT + 1))
    success "Trait range: $START_TRAIT-$END_TRAIT ($num_traits traits)"

    # Warn if very large
    if [[ $num_traits -gt 500 ]]; then
        warning "Large number of traits ($num_traits) - submission may take a while"
    fi
}

check_gapit_parameters() {
    section "GAPIT Parameters"

    # Check MODEL (v3.0.0) or MODELS (legacy)
    local model_value="${MODEL:-${MODELS:-}}"
    if [[ -z "$model_value" ]]; then
        error "MODEL not set"
    else
        local valid_models="BLINK FarmCPU MLM MLMM SUPER CMLM"
        IFS=',' read -ra model_array <<< "$model_value"
        for model in "${model_array[@]}"; do
            model=$(echo "$model" | xargs)  # trim whitespace
            if [[ ! " $valid_models " =~ " $model " ]]; then
                error "Invalid model name: $model (valid: $valid_models)"
            else
                success "Model: $model"
            fi
        done
    fi

    # Check PCA_TOTAL (v3.0.0) or PCA_COMPONENTS (legacy)
    local pca_value="${PCA_TOTAL:-${PCA_COMPONENTS:-0}}"
    if [[ $pca_value -lt 0 ]] || [[ $pca_value -gt 20 ]]; then
        error "PCA_TOTAL must be between 0 and 20, found: $pca_value"
    else
        success "PCA_TOTAL: $pca_value"
    fi

    # Check SNP_THRESHOLD
    local threshold_value="${SNP_THRESHOLD:-0.05}"
    # Check is valid p-value format (scientific notation or decimal)
    if [[ "$threshold_value" =~ ^[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$ ]]; then
        success "SNP_THRESHOLD: $threshold_value"
    else
        error "SNP_THRESHOLD has invalid format: $threshold_value"
    fi

    # Check SNP_MAF (v3.0.0) or MAF_FILTER (legacy)
    local maf_value="${SNP_MAF:-${MAF_FILTER:-0}}"
    # Check is between 0 and 0.5 (use awk instead of bc)
    if awk -v maf="$maf_value" 'BEGIN { exit !(maf >= 0 && maf <= 0.5) }'; then
        success "SNP_MAF: $maf_value"
    else
        error "SNP_MAF must be between 0 and 0.5, found: $maf_value"
    fi

    # Check SNP_FDR (optional)
    if [[ -n "${SNP_FDR:-}" ]]; then
        if awk -v fdr="$SNP_FDR" 'BEGIN { exit !(fdr >= 0 && fdr <= 1) }'; then
            success "SNP_FDR: $SNP_FDR"
        else
            error "SNP_FDR must be between 0 and 1, found: $SNP_FDR"
        fi
    else
        info "SNP_FDR: disabled"
    fi
}

check_runai_config() {
    section "RunAI Configuration"

    # Check PROJECT
    if [[ -z "${PROJECT:-}" ]]; then
        error "PROJECT not set"
        return
    fi
    success "PROJECT: $PROJECT"

    # Check runai CLI available
    if ! command -v runai >/dev/null 2>&1; then
        warning "runai CLI not found - cannot verify project access"
        info "Install: pip install runai-cli"
        return
    fi
    success "runai CLI found"

    # Check project accessible
    if runai config project 2>/dev/null | grep -q "$PROJECT"; then
        success "Project configured: $PROJECT"
    else
        warning "Project not configured in runai CLI"
        info "Configure with: runai config project $PROJECT"
    fi

    # Check JOB_PREFIX
    if [[ -z "${JOB_PREFIX:-}" ]]; then
        error "JOB_PREFIX not set"
    else
        success "JOB_PREFIX: $JOB_PREFIX"

        # Check for conflicting jobs (if runai available)
        if command -v runai >/dev/null 2>&1; then
            local existing_jobs=$(runai workspace list -p "$PROJECT" 2>/dev/null | grep -c "^$JOB_PREFIX-" || echo 0)
            if [[ $existing_jobs -gt 0 ]]; then
                warning "Found $existing_jobs existing jobs with prefix '$JOB_PREFIX'"
                info "Check with: runai workspace list -p $PROJECT | grep $JOB_PREFIX"
            else
                success "No conflicting jobs found"
            fi
        fi
    fi

    # Check MAX_CONCURRENT
    if [[ -z "${MAX_CONCURRENT:-}" ]]; then
        error "MAX_CONCURRENT not set"
    elif [[ $MAX_CONCURRENT -lt 1 ]] || [[ $MAX_CONCURRENT -gt 200 ]]; then
        warning "MAX_CONCURRENT ($MAX_CONCURRENT) seems unusual (typical: 10-100)"
    else
        success "MAX_CONCURRENT: $MAX_CONCURRENT"
    fi
}

check_resources() {
    section "Resource Allocation"

    # Check CPU
    if [[ -z "${CPU:-}" ]]; then
        error "CPU not set"
    elif [[ $CPU -lt 1 ]] || [[ $CPU -gt 64 ]]; then
        error "CPU must be between 1 and 64, found: $CPU"
    else
        success "CPU per job: $CPU cores"
    fi

    # Check MEMORY
    if [[ -z "${MEMORY:-}" ]]; then
        error "MEMORY not set"
    else
        # Extract numeric value (e.g., 32G -> 32)
        local mem_value=${MEMORY%G}
        if [[ $mem_value -lt 8 ]]; then
            error "MEMORY too low (<8G): $MEMORY"
        elif [[ $mem_value -lt 16 ]]; then
            warning "MEMORY may be insufficient (<16G): $MEMORY (recommended: 32G)"
        else
            success "MEMORY per job: $MEMORY"
        fi
    fi

    # Calculate peak resources
    if [[ -n "${CPU:-}" ]] && [[ -n "${MAX_CONCURRENT:-}" ]]; then
        local peak_cpu=$((CPU * MAX_CONCURRENT))
        info "Peak CPU usage: $peak_cpu cores"

        if [[ $peak_cpu -gt 1000 ]]; then
            warning "Very high peak CPU usage: $peak_cpu cores"
        fi
    fi

    if [[ -n "${MEMORY:-}" ]] && [[ -n "${MAX_CONCURRENT:-}" ]]; then
        local mem_value=${MEMORY%G}
        local peak_mem=$((mem_value * MAX_CONCURRENT))
        info "Peak memory usage: ~${peak_mem}G"
    fi
}

# ===========================================================================
# Main
# ===========================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quick|-q)
            QUICK=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 2
            ;;
    esac
done

# Show header
echo ""
echo "Validating GAPIT GWAS Configuration"
echo "Environment file: $ENV_FILE"
if [[ "$QUICK" == "true" ]]; then
    echo "Mode: Quick (skipping slow checks)"
fi
if [[ "$VERBOSE" == "true" ]]; then
    echo "Mode: Verbose output enabled"
fi

# Load .env file
if [[ ! -f "$ENV_FILE" ]]; then
    echo ""
    error ".env file not found: $ENV_FILE"
    exit 1
fi

set -a
source <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r$//')
set +a

# Run validation checks
check_environment_file
check_docker_image
check_cluster_paths
check_data_files
check_phenotype_structure
check_trait_indices
check_gapit_parameters
check_runai_config
check_resources

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}OK: All validation checks passed!${NC}"
    echo ""
    echo "Configuration is ready for submission:"
    echo "  ./scripts/submit-all-traits-runai.sh"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}Validation passed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Configuration is usable but review warnings above."
    echo "To submit: ./scripts/submit-all-traits-runai.sh"
    exit 0
else
    echo -e "${RED}Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors above before submitting."
    exit 1
fi
