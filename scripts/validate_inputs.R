#!/usr/bin/env Rscript
# ==============================================================================
# Input Validation Script
# ==============================================================================
# Validates input data files before running GWAS
# Returns exit code 0 on success, non-zero on failure
# ==============================================================================

suppressPackageStartupMessages({
  library(yaml)
  library(tools)
})

# Parse arguments
args <- commandArgs(trailingOnly = TRUE)
config_file <- ifelse(length(args) >= 1, args[1], "/config/config.yaml")

cat(strrep("=", 78), "\n")
cat("GAPIT3 Pipeline - Input Validation\n")
cat(strrep("=", 78), "\n\n")

# Load config
if (!file.exists(config_file)) {
  cat("ERROR: Config file not found:", config_file, "\n")
  quit(status = 1)
}

config <- read_yaml(config_file)
cat("✓ Config file loaded:", config_file, "\n\n")

# Track validation status
validation_passed <- TRUE

# ==============================================================================
# Validate data files
# ==============================================================================
cat("Checking data files...\n")

# Genotype file
genotype_file <- config$data$genotype
if (!file.exists(genotype_file)) {
  cat("✗ Genotype file not found:", genotype_file, "\n")
  validation_passed <- FALSE
} else {
  file_size_mb <- file.size(genotype_file) / 1024^2
  cat("✓ Genotype file:", genotype_file, sprintf("(%.1f MB)\n", file_size_mb))

  # Quick sanity check
  first_lines <- readLines(genotype_file, n = 2)
  if (length(first_lines) < 2) {
    cat("✗ Genotype file appears empty\n")
    validation_passed <- FALSE
  }
}

# Phenotype file
phenotype_file <- config$data$phenotype
if (!file.exists(phenotype_file)) {
  cat("✗ Phenotype file not found:", phenotype_file, "\n")
  validation_passed <- FALSE
} else {
  file_size_kb <- file.size(phenotype_file) / 1024
  cat("✓ Phenotype file:", phenotype_file, sprintf("(%.1f KB)\n", file_size_kb))

  # Load and check structure
  pheno <- tryCatch({
    read.table(phenotype_file, header = TRUE, nrows = 5)
  }, error = function(e) {
    cat("✗ Error reading phenotype file:", conditionMessage(e), "\n")
    validation_passed <<- FALSE
    NULL
  })

  if (!is.null(pheno)) {
    if (!"Taxa" %in% colnames(pheno)) {
      cat("✗ Phenotype file missing 'Taxa' column\n")
      validation_passed <- FALSE
    } else {
      cat("  - Found", ncol(pheno) - 1, "trait columns\n")
    }
  }
}

# Accession IDs file (optional)
ids_file <- config$data$accession_ids
if (!is.null(ids_file) && ids_file != "") {
  if (!file.exists(ids_file)) {
    cat("⚠ Accession IDs file not found (optional):", ids_file, "\n")
  } else {
    cat("✓ Accession IDs file:", ids_file, "\n")
  }
}

# ==============================================================================
# Validate GAPIT parameters
# ==============================================================================
cat("\nValidating GAPIT parameters...\n")

valid_models <- c("GLM", "MLM", "MLMM", "SUPER", "FarmCPU", "BLINK", "Blink")
models <- config$gapit$models

for (model in models) {
  if (model %in% valid_models) {
    cat("✓ Model:", model, "\n")
  } else {
    cat("✗ Invalid model:", model, "\n")
    cat("  Valid options:", paste(valid_models, collapse = ", "), "\n")
    validation_passed <- FALSE
  }
}

pca <- config$gapit$pca_components
if (is.null(pca) || !is.numeric(pca) || pca < 0) {
  cat("✗ Invalid PCA components:", pca, "\n")
  validation_passed <- FALSE
} else {
  cat("✓ PCA components:", pca, "\n")
}

# ==============================================================================
# Check output directory
# ==============================================================================
cat("\nChecking output directory...\n")
output_dir <- config$output$base_dir

if (!dir.exists(output_dir)) {
  cat("  Output directory doesn't exist, attempting to create:", output_dir, "\n")
  tryCatch({
    dir.create(output_dir, recursive = TRUE)
    cat("✓ Output directory created\n")
  }, error = function(e) {
    cat("✗ Cannot create output directory:", conditionMessage(e), "\n")
    validation_passed <<- FALSE
  })
} else {
  cat("✓ Output directory exists:", output_dir, "\n")
}

# ==============================================================================
# Summary
# ==============================================================================
cat("\n")
cat(strrep("=", 78), "\n")
if (validation_passed) {
  cat("✓ All validation checks passed!\n")
  cat(strrep("=", 78), "\n\n")
  quit(status = 0)
} else {
  cat("✗ Validation failed - please fix errors above\n")
  cat(strrep("=", 78), "\n\n")
  quit(status = 1)
}
