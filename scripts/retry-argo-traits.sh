#!/bin/bash
# ==============================================================================
# Retry Failed Argo Workflow Traits
# ==============================================================================
# Generates and optionally submits a retry workflow for incomplete traits
# Detects incomplete traits by inspecting output directories for missing model outputs
#
# Usage: ./scripts/retry-argo-traits.sh --workflow <name> --output-dir <path> [OPTIONS]
# ==============================================================================

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults
NAMESPACE="runai-talmo-lab"
WORKFLOW=""
TRAITS=""
OUTPUT_DIR=""
HIGHMEM=false
ULTRAHIGHMEM=false
DRY_RUN=false
SUBMIT=false
WATCH=false
AGGREGATE=false
OUTPUT_FILE=""
PARALLELISM=""  # Empty = use template-specific default

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==============================================================================
# Functions
# ==============================================================================

# Escape a value for safe use inside YAML double-quoted strings
yaml_escape() {
    local val="$1"
    # Escape backslashes first, then double quotes
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    printf '%s' "$val"
}

show_help() {
    cat << EOF
${GREEN}GAPIT3 GWAS - Retry Failed Argo Workflow Traits${NC}

Detect incomplete traits by inspecting output directories and generate a retry workflow.

${BLUE}Usage:${NC}
  $0 --workflow <name> --output-dir <path> [OPTIONS]
  $0 --traits 5,28,29,30,31 --workflow <name> [OPTIONS]

${BLUE}Required:${NC}
  --workflow NAME    Source workflow to get parameters from
  --output-dir PATH  Local path to output directory (to inspect for incomplete traits)

${BLUE}Options:${NC}
  --traits LIST      Comma-separated trait indices (e.g., 5,28,29,30,31)
                     If not specified, auto-detects from output directory
  --namespace NS     Kubernetes namespace (default: runai-talmo-lab)
  --highmem          Use high-memory template (96Gi/16 CPU)
  --ultrahighmem     Use ultra-high-memory template (160Gi/16 CPU) for >1.5M SNPs
  --dry-run          Generate YAML and print to stdout, don't submit
  --submit           Submit the generated workflow to cluster
  --watch            Watch workflow after submission (implies --submit)
  --aggregate        Include aggregation step in workflow (runs in-cluster after retries)
  --parallelism N    Max concurrent jobs (default: 10 for standard/highmem, 5 for ultrahighmem)
  --output FILE      Write generated YAML to file
  --help             Show this help message

${BLUE}Template Selection Guide:${NC}
  standard (default)  64Gi memory   For <500K SNPs, <300 samples
  --highmem           96Gi memory   For 500K-1.5M SNPs, <600 samples
  --ultrahighmem     160Gi memory   For >1.5M SNPs or >600 samples

${BLUE}Memory Estimation:${NC}
  Peak (GB) ≈ (samples × SNPs × 8 × 5) / 1024³ × 1.5
  Example: 546 samples × 2.64M SNPs = ~129 GB → use --ultrahighmem

${BLUE}Examples:${NC}
  # Auto-detect incomplete traits and preview retry workflow
  $0 --workflow gapit3-gwas-parallel-8nj24 \\
     --output-dir "Z:/users/eberrigan/.../outputs" --dry-run

  # Retry specific traits with high memory
  $0 --traits 5,28,29,30,31 --workflow gapit3-gwas-parallel-8nj24 \\
     --highmem --submit

  # Retry, watch, and aggregate when done
  $0 --workflow gapit3-gwas-parallel-8nj24 \\
     --output-dir "Z:/users/eberrigan/.../outputs" \\
     --highmem --watch --aggregate

${BLUE}Notes:${NC}
  - Uses Filter file (GAPIT.Association.Filter_GWAS_results.csv) as definitive completion signal
  - GAPIT only creates the Filter file after ALL models complete successfully
  - Traits with partial outputs (GWAS_Results but no Filter) are correctly detected as incomplete
  - Models list comes from the original workflow parameters (not hardcoded)
  - SNP FDR threshold is automatically propagated from the original workflow
  - Use --highmem for traits that failed with OOMKilled (exit code 137)
  - Use --ultrahighmem for very large datasets (>1.5M SNPs) that fail even with --highmem

EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# ==============================================================================
# Parse Arguments
# ==============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --workflow)
            WORKFLOW="$2"
            shift 2
            ;;
        --traits)
            TRAITS="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --highmem)
            HIGHMEM=true
            shift
            ;;
        --ultrahighmem)
            ULTRAHIGHMEM=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --submit)
            SUBMIT=true
            shift
            ;;
        --watch)
            WATCH=true
            SUBMIT=true  # --watch implies --submit
            shift
            ;;
        --aggregate)
            AGGREGATE=true
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --parallelism)
            PARALLELISM="$2"
            # Validate it's a positive integer
            if ! [[ "$PARALLELISM" =~ ^[1-9][0-9]*$ ]]; then
                log_error "--parallelism must be a positive integer, got: $PARALLELISM"
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# ==============================================================================
# Validate Prerequisites
# ==============================================================================

log_info "Validating prerequisites..."

# Check argo CLI
if ! command -v argo &> /dev/null; then
    log_error "argo CLI not found. Please install Argo Workflows CLI."
    exit 1
fi

# Check jq for JSON parsing
if ! command -v jq &> /dev/null; then
    log_error "jq not found. Please install jq for JSON parsing."
    exit 1
fi

# Require workflow
if [[ -z "$WORKFLOW" ]]; then
    log_error "--workflow is required"
    echo "Run '$0 --help' for usage information"
    exit 1
fi

# Require output-dir if no traits specified
if [[ -z "$TRAITS" && -z "$OUTPUT_DIR" ]]; then
    log_error "Either --traits or --output-dir must be specified for trait detection"
    echo "Run '$0 --help' for usage information"
    exit 1
fi

# ==============================================================================
# Get Workflow Info
# ==============================================================================

log_info "Fetching workflow info: $WORKFLOW"

# Get workflow JSON
WORKFLOW_JSON=$(argo get "$WORKFLOW" -n "$NAMESPACE" -o json 2>/dev/null) || {
    log_error "Failed to get workflow: $WORKFLOW"
    log_error "Make sure the workflow exists and you have access to namespace: $NAMESPACE"
    exit 1
}

# Extract parameters from workflow
DATA_HOSTPATH=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "data-hostpath") | .value')
OUTPUT_HOSTPATH=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "output-hostpath") | .value')
IMAGE=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "image") | .value')

# Handle both v3.0.0 naming ("model") and legacy naming ("models")
MODEL=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "model") | .value // ""')
if [[ -z "$MODEL" ]]; then
    MODEL=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "models") | .value // "MLM"')
fi

START_TRAIT=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "start-trait-index") | .value // "2"')
END_TRAIT=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "end-trait-index") | .value // "187"')

# Core GAPIT parameters (v3.0.0 naming)
SNP_FDR=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "snp-fdr") | .value // ""')
PCA_TOTAL=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "pca-total") | .value // "0"')
SNP_MAF=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "snp-maf") | .value // "0"')

# Advanced GAPIT parameters
KINSHIP_ALGORITHM=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "kinship-algorithm") | .value // "Zhang"')
SNP_EFFECT=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "snp-effect") | .value // "Add"')
SNP_IMPUTE=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "snp-impute") | .value // "Middle"')

# File path parameters
GENOTYPE_FILE=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "genotype-file") | .value // "/data/genotype/acc_snps_filtered_maf_perl_edited_diploid.hmp.txt"')
PHENOTYPE_FILE=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "phenotype-file") | .value // "/data/phenotype/iron_traits_edited.txt"')
ACCESSION_IDS_FILE=$(echo "$WORKFLOW_JSON" | jq -r '.spec.arguments.parameters[] | select(.name == "accession-ids-file") | .value // "/data/metadata/ids_gwas.txt"')

echo ""
log_info "Workflow parameters:"
echo "  Data path (cluster): $DATA_HOSTPATH"
echo "  Output path (cluster): $OUTPUT_HOSTPATH"
echo "  Image: $IMAGE"
echo "  Model: $MODEL"
echo "  Trait range: $START_TRAIT - $END_TRAIT"
echo ""
echo "  GAPIT Parameters:"
echo "    PCA Total: $PCA_TOTAL"
echo "    SNP MAF: $SNP_MAF"
if [[ -n "$SNP_FDR" ]]; then
    echo "    SNP FDR: $SNP_FDR"
else
    echo "    SNP FDR: (not set)"
fi
echo "    Kinship Algorithm: $KINSHIP_ALGORITHM"
echo "    SNP Effect: $SNP_EFFECT"
echo "    SNP Impute: $SNP_IMPUTE"
echo ""
echo "  File Paths:"
echo "    Genotype: $GENOTYPE_FILE"
echo "    Phenotype: $PHENOTYPE_FILE"
echo "    Accession IDs: $ACCESSION_IDS_FILE"
echo ""

# Parse models into array (for output completeness checking)
IFS=',' read -ra MODEL_ARRAY <<< "$MODEL"
log_info "Expected models: ${MODEL_ARRAY[*]}"

# ==============================================================================
# Detect Incomplete Traits
# ==============================================================================

TRAIT_ARRAY=()
MISSING_TRAITS=()
INCOMPLETE_TRAITS=()
NO_FILTER_TRAITS=()

if [[ -n "$TRAITS" ]]; then
    # Parse comma-separated traits
    log_info "Using specified traits: $TRAITS"
    IFS=',' read -ra TRAIT_ARRAY <<< "$TRAITS"
elif [[ -n "$OUTPUT_DIR" ]]; then
    # Auto-detect incomplete traits from output directory
    log_info "Scanning output directory for incomplete traits..."
    echo "  Directory: $OUTPUT_DIR"
    echo ""

    if [[ ! -d "$OUTPUT_DIR" ]]; then
        log_error "Output directory does not exist: $OUTPUT_DIR"
        exit 1
    fi

    # Check each trait in range
    for trait in $(seq "$START_TRAIT" "$END_TRAIT"); do
        # Format trait with leading zeros (trait_002, trait_003, etc.)
        TRAIT_PADDED=$(printf "%03d" "$trait")

        # Find trait directory (may have timestamp suffix)
        TRAIT_DIR=$(ls -d "$OUTPUT_DIR"/trait_${TRAIT_PADDED}_* 2>/dev/null | head -1 || true)

        if [[ -z "$TRAIT_DIR" ]]; then
            # No output directory at all
            MISSING_TRAITS+=("$trait")
            TRAIT_ARRAY+=("$trait")
        else
            # CRITICAL: Check for Filter file first - definitive completion signal
            # GAPIT only creates Filter_GWAS_results.csv after ALL models complete
            FILTER_FILE="$TRAIT_DIR/GAPIT.Association.Filter_GWAS_results.csv"

            if [[ ! -f "$FILTER_FILE" ]]; then
                # Missing Filter file = incomplete (regardless of GWAS_Results files)
                NO_FILTER_TRAITS+=("$trait")
                TRAIT_ARRAY+=("$trait")
            else
                # Filter file exists - trait is complete
                # Check for missing models only for informational purposes
                MISSING_MODELS=()
                for model in "${MODEL_ARRAY[@]}"; do
                    if ! ls "$TRAIT_DIR"/GAPIT.Association.GWAS_Results.${model}.* &>/dev/null 2>&1; then
                        MISSING_MODELS+=("$model")
                    fi
                done

                if [[ ${#MISSING_MODELS[@]} -gt 0 ]]; then
                    # Has Filter file but missing some GWAS_Results - unusual but complete
                    # (Filter file is the authoritative completion signal)
                    log_warn "Trait $trait has Filter file but missing GWAS_Results for: ${MISSING_MODELS[*]}"
                fi
            fi
        fi
    done

    # Display summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Trait Completeness Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    TOTAL_TRAITS=$((END_TRAIT - START_TRAIT + 1))
    COMPLETE_TRAITS=$((TOTAL_TRAITS - ${#TRAIT_ARRAY[@]}))

    echo "Total traits in range: $TOTAL_TRAITS"
    echo -e "Complete traits (Filter file present): ${GREEN}$COMPLETE_TRAITS${NC}"
    echo -e "Missing (no output directory): ${RED}${#MISSING_TRAITS[@]}${NC}"
    echo -e "Incomplete (missing Filter file): ${YELLOW}${#NO_FILTER_TRAITS[@]}${NC}"
    echo ""
    echo -e "${BLUE}Note:${NC} Filter file (GAPIT.Association.Filter_GWAS_results.csv) is the"
    echo "      definitive completion signal - GAPIT creates it only after ALL models finish."
    echo ""

    if [[ ${#MISSING_TRAITS[@]} -gt 0 ]]; then
        echo "Missing traits (no output directory):"
        for trait in "${MISSING_TRAITS[@]}"; do
            echo "  - Trait $trait"
        done
        echo ""
    fi

    if [[ ${#NO_FILTER_TRAITS[@]} -gt 0 ]]; then
        echo "Incomplete traits (missing Filter file):"
        for trait in "${NO_FILTER_TRAITS[@]}"; do
            echo "  - Trait $trait"
        done
        echo ""
    fi
fi

if [[ ${#TRAIT_ARRAY[@]} -eq 0 ]]; then
    log_info "All traits are complete! No retry needed."
    exit 0
fi

log_info "Traits to retry: ${TRAIT_ARRAY[*]}"
echo ""

# ==============================================================================
# Generate Retry Workflow YAML
# ==============================================================================

# Determine template to use (ultrahighmem takes precedence over highmem)
# Also set template-specific parallelism defaults
if [[ "$ULTRAHIGHMEM" == "true" ]]; then
    TEMPLATE_NAME="gapit3-gwas-single-trait-ultrahighmem"
    DEFAULT_PARALLELISM=5  # Ultrahighmem uses 160Gi+16CPU, limit concurrent jobs
    log_info "Using ultra-high-memory template (160Gi/16 CPU)"
elif [[ "$HIGHMEM" == "true" ]]; then
    TEMPLATE_NAME="gapit3-gwas-single-trait-highmem"
    DEFAULT_PARALLELISM=10
    log_info "Using high-memory template (96Gi/16 CPU)"
else
    TEMPLATE_NAME="gapit3-gwas-single-trait"
    DEFAULT_PARALLELISM=10
    log_info "Using standard template (64Gi/12 CPU)"
fi

# Use user-specified parallelism or template default
if [[ -n "$PARALLELISM" ]]; then
    EFFECTIVE_PARALLELISM=$PARALLELISM
    PARALLELISM_SOURCE="user-specified"
else
    EFFECTIVE_PARALLELISM=$DEFAULT_PARALLELISM
    PARALLELISM_SOURCE="template default"
fi
log_info "Parallelism: $EFFECTIVE_PARALLELISM ($PARALLELISM_SOURCE)"

# Generate workflow suffix from original workflow
WORKFLOW_SUFFIX=$(echo "$WORKFLOW" | sed 's/gapit3-gwas-parallel-//' | sed 's/gapit3-gwas-//')

# Build DAG tasks YAML
TASKS_YAML=""
TASK_NAMES=()
for trait in "${TRAIT_ARRAY[@]}"; do
    TASK_NAMES+=("retry-trait-${trait}")
    TASKS_YAML+="      - name: retry-trait-${trait}
        templateRef:
          name: ${TEMPLATE_NAME}
          template: run-gwas
        arguments:
          parameters:
          - name: trait-index
            value: \"${trait}\"
          - name: trait-name
            value: \"retry-trait-${trait}\"
          - name: image
            value: \"{{workflow.parameters.image}}\"
          # File paths
          - name: genotype-file
            value: \"{{workflow.parameters.genotype-file}}\"
          - name: phenotype-file
            value: \"{{workflow.parameters.phenotype-file}}\"
          - name: accession-ids-file
            value: \"{{workflow.parameters.accession-ids-file}}\"
          # Core GAPIT parameters (v3.0.0 naming)
          - name: model
            value: \"{{workflow.parameters.model}}\"
          - name: pca-total
            value: \"{{workflow.parameters.pca-total}}\"
          - name: snp-maf
            value: \"{{workflow.parameters.snp-maf}}\"
          - name: snp-fdr
            value: \"{{workflow.parameters.snp-fdr}}\"
          # Advanced GAPIT parameters
          - name: kinship-algorithm
            value: \"{{workflow.parameters.kinship-algorithm}}\"
          - name: snp-effect
            value: \"{{workflow.parameters.snp-effect}}\"
          - name: snp-impute
            value: \"{{workflow.parameters.snp-impute}}\"
"
done

# Add collect-results task if --aggregate flag is set
COLLECT_RESULTS_YAML=""
if [[ "$AGGREGATE" == "true" ]]; then
    log_info "Including aggregation step in workflow (runs after all retries complete)"
    # Build dependencies string for all retry tasks
    DEPS_STRING=$(IFS=,; echo "${TASK_NAMES[*]}")
    COLLECT_RESULTS_YAML="      - name: collect-results
        dependencies: [${DEPS_STRING}]
        templateRef:
          name: gapit3-results-collector
          template: collect-results
        arguments:
          parameters:
          - name: image
            value: \"{{workflow.parameters.image}}\"
          - name: batch-id
            value: \"{{workflow.name}}\"
"
fi

# Escape all shell-interpolated values for safe YAML embedding
Y_IMAGE=$(yaml_escape "$IMAGE")
Y_DATA_HOSTPATH=$(yaml_escape "$DATA_HOSTPATH")
Y_OUTPUT_HOSTPATH=$(yaml_escape "$OUTPUT_HOSTPATH")
Y_GENOTYPE_FILE=$(yaml_escape "$GENOTYPE_FILE")
Y_PHENOTYPE_FILE=$(yaml_escape "$PHENOTYPE_FILE")
Y_ACCESSION_IDS_FILE=$(yaml_escape "$ACCESSION_IDS_FILE")
Y_MODEL=$(yaml_escape "$MODEL")
Y_PCA_TOTAL=$(yaml_escape "$PCA_TOTAL")
Y_SNP_MAF=$(yaml_escape "$SNP_MAF")
Y_SNP_FDR=$(yaml_escape "$SNP_FDR")
Y_KINSHIP_ALGORITHM=$(yaml_escape "$KINSHIP_ALGORITHM")
Y_SNP_EFFECT=$(yaml_escape "$SNP_EFFECT")
Y_SNP_IMPUTE=$(yaml_escape "$SNP_IMPUTE")
Y_NAMESPACE=$(yaml_escape "$NAMESPACE")
Y_WORKFLOW=$(yaml_escape "$WORKFLOW")

# Generate full workflow YAML
RETRY_YAML="apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: gapit3-gwas-retry-${WORKFLOW_SUFFIX}-
  namespace: ${Y_NAMESPACE}
  labels:
    pipeline: gapit3-gwas
    stage: retry
    original-workflow: ${Y_WORKFLOW}
spec:
  # ===========================================================================
  # GAPIT3 GWAS - Retry Workflow (${#TRAIT_ARRAY[@]} traits)
  # ===========================================================================
  # Retry workflow for incomplete traits from: ${Y_WORKFLOW}
  # Template: ${TEMPLATE_NAME}
  # Model: ${Y_MODEL}
  # ===========================================================================

  entrypoint: retry-traits
  serviceAccountName: default

  # Workflow-level parameters (copied from original workflow)
  arguments:
    parameters:
    - name: image
      value: \"${Y_IMAGE}\"
    - name: data-hostpath
      value: \"${Y_DATA_HOSTPATH}\"
    - name: output-hostpath
      value: \"${Y_OUTPUT_HOSTPATH}\"
    # File paths
    - name: genotype-file
      value: \"${Y_GENOTYPE_FILE}\"
    - name: phenotype-file
      value: \"${Y_PHENOTYPE_FILE}\"
    - name: accession-ids-file
      value: \"${Y_ACCESSION_IDS_FILE}\"
    # Core GAPIT parameters (v3.0.0 naming)
    - name: model
      value: \"${Y_MODEL}\"
    - name: pca-total
      value: \"${Y_PCA_TOTAL}\"
    - name: snp-maf
      value: \"${Y_SNP_MAF}\"
    - name: snp-fdr
      value: \"${Y_SNP_FDR}\"
    # Advanced GAPIT parameters
    - name: kinship-algorithm
      value: \"${Y_KINSHIP_ALGORITHM}\"
    - name: snp-effect
      value: \"${Y_SNP_EFFECT}\"
    - name: snp-impute
      value: \"${Y_SNP_IMPUTE}\"

  # Global timeout (7 days - effectively no limit for retries)
  activeDeadlineSeconds: 604800

  # Workflow-level volumes
  volumes:
  - name: nfs-data
    hostPath:
      path: \"{{workflow.parameters.data-hostpath}}\"
      type: Directory
  - name: nfs-outputs
    hostPath:
      path: \"{{workflow.parameters.output-hostpath}}\"
      type: DirectoryOrCreate

  templates:
  - name: retry-traits
    dag:
      tasks:
${TASKS_YAML}${COLLECT_RESULTS_YAML}
  # Parallelism - limit concurrent jobs (template default or user-specified)
  parallelism: ${EFFECTIVE_PARALLELISM}
"

# ==============================================================================
# Output or Submit
# ==============================================================================

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Generated Retry Workflow YAML (DRY RUN)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Configuration Summary:${NC}"
    echo "  Template: $TEMPLATE_NAME"
    echo "  Parallelism: $EFFECTIVE_PARALLELISM ($PARALLELISM_SOURCE)"
    echo "  Traits to retry: ${#TRAIT_ARRAY[@]}"
    echo ""
    echo "$RETRY_YAML"
    echo ""
    log_info "To submit this workflow, run without --dry-run and add --submit"
    exit 0
fi

if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$RETRY_YAML" > "$OUTPUT_FILE"
    log_info "Workflow YAML written to: $OUTPUT_FILE"
fi

if [[ "$SUBMIT" == "true" ]]; then
    log_info "Submitting retry workflow..."

    # Create temp file for submission (with cleanup trap)
    TEMP_YAML=$(mktemp /tmp/retry-workflow-XXXXXX.yaml)
    trap 'rm -f "$TEMP_YAML"' EXIT INT TERM
    echo "$RETRY_YAML" > "$TEMP_YAML"

    # Submit workflow
    if [[ "$WATCH" == "true" ]]; then
        argo submit "$TEMP_YAML" -n "$NAMESPACE" --watch
        SUBMITTED_NAME=$(argo list -n "$NAMESPACE" --prefix gapit3-gwas-retry -o name | head -1)
    else
        SUBMITTED_NAME=$(argo submit "$TEMP_YAML" -n "$NAMESPACE" -o name 2>&1)
    fi

    rm -f "$TEMP_YAML"

    if [[ -z "$SUBMITTED_NAME" ]]; then
        log_error "Failed to submit workflow"
        exit 1
    fi

    echo ""
    log_info "Workflow submitted: $SUBMITTED_NAME"
    echo ""
    echo "Monitor with:"
    echo "  argo watch $SUBMITTED_NAME -n $NAMESPACE"
    echo ""
    echo "Get status:"
    echo "  argo get $SUBMITTED_NAME -n $NAMESPACE"

    # Note: When --aggregate is set, aggregation runs as part of the workflow DAG (in-cluster)
    # No local aggregation call needed
    if [[ "$AGGREGATE" == "true" ]]; then
        echo ""
        log_info "Aggregation will run in-cluster after all retry tasks complete"
    fi
else
    if [[ -z "$OUTPUT_FILE" ]]; then
        echo ""
        echo "$RETRY_YAML"
        echo ""
    fi
    log_info "Workflow generated but not submitted. Use --submit to submit."
fi
