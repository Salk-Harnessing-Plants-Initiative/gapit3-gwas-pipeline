#!/bin/bash
# ==============================================================================
# GAPIT3 Pipeline - Container Entrypoint
# ==============================================================================
# Main entrypoint for the Docker container
# Handles validation, logging, and execution routing
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper functions
# ==============================================================================

print_banner() {
    echo "=============================================================================="
    echo "$1"
    echo "=============================================================================="
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_help() {
    cat << EOF
GAPIT3 GWAS Pipeline - Docker Container

Usage:
  docker run [docker-options] ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest [COMMAND] [OPTIONS]

Commands:
  run-single-trait   Run GWAS for a single trait
  validate           Validate input files and configuration
  extract-traits     Extract trait manifest from phenotype file
  help               Show this help message

Examples:
  # Validate inputs
  docker run -v /data:/data -v /outputs:/outputs gapit3-gwas-pipeline validate

  # Extract trait manifest
  docker run -v /data:/data -v /config:/config gapit3-gwas-pipeline extract-traits

  # Run single trait (trait index 2)
  docker run -v /data:/data -v /outputs:/outputs gapit3-gwas-pipeline run-single-trait --trait-index 2

Options for run-single-trait:
  --trait-index INT       Trait column index (required)
  --config FILE           Config file path [default: /config/config.yaml]
  --genotype FILE         Genotype HapMap file
  --phenotype FILE        Phenotype file
  --ids FILE              Accession IDs file
  --output-dir DIR        Output directory [default: /outputs]
  --models STRING         Models to run (e.g., 'BLINK,FarmCPU')
  --pca INT               Number of PCA components
  --threads INT           Number of CPU threads

Environment Variables:
  OPENBLAS_NUM_THREADS    Number of threads for OpenBLAS (default: 16)
  OMP_NUM_THREADS         Number of OpenMP threads (default: 16)

For more information:
  https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline

EOF
}

# ==============================================================================
# Main entrypoint logic
# ==============================================================================

print_banner "GAPIT3 GWAS Pipeline"
echo "R version: $(R --version | head -n1)"
echo "GAPIT version: $(Rscript -e 'cat(as.character(packageVersion(\"GAPIT\")))')"
echo ""

# Parse command
COMMAND="${1:-help}"

case "$COMMAND" in
    run-single-trait)
        shift  # Remove command from arguments
        print_banner "Running Single Trait GWAS"

        # Optional: Run validation first
        if [ "${SKIP_VALIDATION:-false}" != "true" ]; then
            echo "Running pre-flight validation..."
            if Rscript /scripts/validate_inputs.R /config/config.yaml; then
                print_success "Validation passed"
            else
                print_error "Validation failed - exiting"
                exit 1
            fi
            echo ""
        fi

        # Execute single trait script
        exec Rscript /scripts/run_gwas_single_trait.R "$@"
        ;;

    validate)
        print_banner "Validating Inputs"
        exec Rscript /scripts/validate_inputs.R /config/config.yaml
        ;;

    extract-traits)
        print_banner "Extracting Trait Manifest"
        PHENOTYPE="${2:-/data/phenotype/iron_traits_edited.txt}"
        OUTPUT="${3:-/config/traits_manifest.yaml}"
        exec Rscript /scripts/extract_trait_names.R "$PHENOTYPE" "$OUTPUT"
        ;;

    bash|shell)
        print_warning "Starting interactive bash shell"
        exec /bin/bash
        ;;

    help|--help|-h)
        print_help
        exit 0
        ;;

    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        print_help
        exit 1
        ;;
esac
