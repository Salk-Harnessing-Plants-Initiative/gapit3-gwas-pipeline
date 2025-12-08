#!/usr/bin/env Rscript
# ==============================================================================
# Input Validation Script
# ==============================================================================
# Validates input data files before running GWAS
# Configuration is read from environment variables (not config.yaml)
# Returns exit code 0 on success, non-zero on failure
# ==============================================================================

suppressPackageStartupMessages({
  library(tools)
})

cat(strrep("=", 78), "\n")
cat("GAPIT3 Pipeline - Input Validation\n")
cat(strrep("=", 78), "\n\n")

# ==============================================================================
# Read configuration from environment variables
# ==============================================================================
genotype_file <- Sys.getenv("GENOTYPE_FILE", "/data/genotype/all_chromosomes_binary.hmp.txt")
phenotype_file <- Sys.getenv("PHENOTYPE_FILE", "/data/phenotype/traits.txt")
ids_file <- Sys.getenv("ACCESSION_IDS_FILE", "")
models_str <- Sys.getenv("MODELS", "BLINK,FarmCPU")
pca_str <- Sys.getenv("PCA_COMPONENTS", "3")
output_dir <- Sys.getenv("OUTPUT_PATH", "/outputs")

cat("Configuration (from environment variables):\n")
cat("  GENOTYPE_FILE:      ", genotype_file, "\n")
cat("  PHENOTYPE_FILE:     ", phenotype_file, "\n")
cat("  ACCESSION_IDS_FILE: ", ifelse(ids_file == "", "(not set)", ids_file), "\n")
cat("  MODELS:             ", models_str, "\n")
cat("  PCA_COMPONENTS:     ", pca_str, "\n")
cat("  OUTPUT_PATH:        ", output_dir, "\n")
cat("\n")

# Track validation status
validation_passed <- TRUE

# ==============================================================================
# Validate data files
# ==============================================================================
cat("Checking data files...\n")

# Genotype file
if (!file.exists(genotype_file)) {
  cat("X Genotype file not found:", genotype_file, "\n")
  validation_passed <- FALSE
} else {
  file_size_mb <- file.size(genotype_file) / 1024^2
  cat("+ Genotype file:", genotype_file, sprintf("(%.1f MB)\n", file_size_mb))

  # Quick sanity check
  first_lines <- readLines(genotype_file, n = 2)
  if (length(first_lines) < 2) {
    cat("X Genotype file appears empty\n")
    validation_passed <- FALSE
  }
}

# Phenotype file
if (!file.exists(phenotype_file)) {
  cat("X Phenotype file not found:", phenotype_file, "\n")
  validation_passed <- FALSE
} else {
  file_size_kb <- file.size(phenotype_file) / 1024
  cat("+ Phenotype file:", phenotype_file, sprintf("(%.1f KB)\n", file_size_kb))

  # Load and check structure
  pheno <- tryCatch({
    read.table(phenotype_file, header = TRUE, nrows = 5)
  }, error = function(e) {
    cat("X Error reading phenotype file:", conditionMessage(e), "\n")
    validation_passed <<- FALSE
    NULL
  })

  if (!is.null(pheno)) {
    if (!"Taxa" %in% colnames(pheno)) {
      cat("X Phenotype file missing 'Taxa' column\n")
      validation_passed <- FALSE
    } else {
      cat("  - Found", ncol(pheno) - 1, "trait columns\n")
    }
  }
}

# Accession IDs file (optional)
if (ids_file != "" && ids_file != "null") {
  if (!file.exists(ids_file)) {
    cat("! Accession IDs file not found (optional):", ids_file, "\n")
  } else {
    cat("+ Accession IDs file:", ids_file, "\n")
  }
}

# ==============================================================================
# Validate GAPIT parameters
# ==============================================================================
cat("\nValidating GAPIT parameters...\n")

valid_models <- c("GLM", "MLM", "MLMM", "SUPER", "FarmCPU", "BLINK", "Blink", "CMLM")

# Parse comma-separated models
models <- strsplit(models_str, ",")[[1]]
models <- trimws(models)

for (model in models) {
  if (model %in% valid_models) {
    cat("+ Model:", model, "\n")
  } else {
    cat("X Invalid model:", model, "\n")
    cat("  Valid options:", paste(valid_models, collapse = ", "), "\n")
    validation_passed <- FALSE
  }
}

# Validate PCA components
pca <- suppressWarnings(as.integer(pca_str))
if (is.na(pca) || pca < 0) {
  cat("X Invalid PCA components:", pca_str, "\n")
  validation_passed <- FALSE
} else {
  cat("+ PCA components:", pca, "\n")
}

# ==============================================================================
# Check output directory
# ==============================================================================
cat("\nChecking output directory...\n")

if (!dir.exists(output_dir)) {
  cat("  Output directory doesn't exist, attempting to create:", output_dir, "\n")
  tryCatch({
    dir.create(output_dir, recursive = TRUE)
    cat("+ Output directory created\n")
  }, error = function(e) {
    cat("X Cannot create output directory:", conditionMessage(e), "\n")
    validation_passed <<- FALSE
  })
} else {
  cat("+ Output directory exists:", output_dir, "\n")
}

# ==============================================================================
# Summary
# ==============================================================================
cat("\n")
cat(strrep("=", 78), "\n")
if (validation_passed) {
  cat("+ All validation checks passed!\n")
  cat(strrep("=", 78), "\n\n")
  quit(status = 0)
} else {
  cat("X Validation failed - please fix errors above\n")
  cat(strrep("=", 78), "\n\n")
  quit(status = 1)
}
