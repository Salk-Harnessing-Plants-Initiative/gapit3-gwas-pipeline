#!/usr/bin/env Rscript
# ==============================================================================
# GAPIT3 GWAS - Single Trait Execution
# ==============================================================================
# Runs GWAS for a single trait using GAPIT3
# Designed for parallel execution across multiple cluster jobs
# ==============================================================================

suppressPackageStartupMessages({
  library(GAPIT)
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readr)
  library(matrixStats)
  library(gridExtra)
  library(optparse)
  library(jsonlite)
  library(tools)  # For md5sum
})

# ==============================================================================
# Helper functions
# ==============================================================================

#' Get environment variable with NULL fallback for empty strings
#' @param name Environment variable name
#' @param default Default value if not set or empty
#' @return The value or NULL if empty/unset
get_env_or_null <- function(name, default = NULL) {
  value <- Sys.getenv(name, "")
  if (value == "" || value == "null" || value == "NULL") {
    return(default)
  }
  return(value)
}

#' Compute MD5 checksum for a file
#' @param file_path Path to file
#' @return MD5 hash string or NULL if file doesn't exist or checksums disabled
compute_file_md5 <- function(file_path) {
  # Check if checksums are disabled
  if (toupper(Sys.getenv("SKIP_INPUT_CHECKSUMS", "false")) == "TRUE") {
    return(NULL)
  }

  if (is.null(file_path) || !file.exists(file_path)) {
    return(NULL)
  }

  tryCatch({
    md5sum(file_path)[[1]]
  }, error = function(e) {
    cat("  Warning: Could not compute MD5 for", file_path, ":", e$message, "\n")
    return(NULL)
  })
}

# ==============================================================================
# Parse command line arguments and environment variables
# ==============================================================================
option_list <- list(
  make_option(c("-t", "--trait-index"), type = "integer",
              default = as.integer(Sys.getenv("TRAIT_INDEX", "2")),
              help = "Trait column index [env: TRAIT_INDEX]", metavar = "INTEGER"),
  make_option(c("-g", "--genotype"), type = "character",
              default = Sys.getenv("GENOTYPE_FILE", "/data/genotype/all_chromosomes_binary.hmp.txt"),
              help = "Path to genotype HapMap file [env: GENOTYPE_FILE]", metavar = "FILE"),
  make_option(c("-p", "--phenotype"), type = "character",
              default = Sys.getenv("PHENOTYPE_FILE", "/data/phenotype/traits.txt"),
              help = "Path to phenotype file [env: PHENOTYPE_FILE]", metavar = "FILE"),
  make_option(c("-i", "--ids"), type = "character",
              default = Sys.getenv("ACCESSION_IDS_FILE", ""),
              help = "Path to accession IDs file [env: ACCESSION_IDS_FILE]", metavar = "FILE"),
  make_option(c("-o", "--output-dir"), type = "character",
              default = Sys.getenv("OUTPUT_PATH", "/outputs"),
              help = "Output directory [env: OUTPUT_PATH]", metavar = "DIR"),
  make_option(c("-m", "--models"), type = "character",
              default = Sys.getenv("MODELS", "BLINK,FarmCPU"),
              help = "Comma-separated models [env: MODELS]", metavar = "STRING"),
  make_option(c("--pca"), type = "integer",
              default = as.integer(Sys.getenv("PCA_COMPONENTS", "3")),
              help = "Number of PCA components [env: PCA_COMPONENTS]", metavar = "INTEGER"),
  make_option(c("--threads"), type = "integer",
              default = as.integer(Sys.getenv("OPENBLAS_NUM_THREADS", "12")),
              help = "Number of CPU threads [env: OPENBLAS_NUM_THREADS]", metavar = "INTEGER"),
  make_option(c("--maf"), type = "numeric",
              default = as.numeric(Sys.getenv("MAF_FILTER", "0.05")),
              help = "Minor allele frequency filter [env: MAF_FILTER]", metavar = "FLOAT"),
  make_option(c("--multiple-analysis"), type = "logical",
              default = as.logical(Sys.getenv("MULTIPLE_ANALYSIS", "TRUE")),
              help = "Run multiple analysis [env: MULTIPLE_ANALYSIS]", metavar = "BOOL"),
  make_option(c("--snp-fdr"), type = "numeric",
              default = NULL,
              help = "FDR threshold for SNP significance (e.g., 0.05) [env: SNP_FDR]", metavar = "FLOAT")
)

opt_parser <- OptionParser(option_list = option_list,
                          description = "\nRun GWAS analysis for a single trait using GAPIT3\nConfiguration via command-line arguments or environment variables.")
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`trait-index`)) {
  stop("Error: --trait-index is required\n", call. = FALSE)
}

# ==============================================================================
# Runtime Configuration (from command-line args or environment variables)
# ==============================================================================
cat("Runtime Configuration:\n")
cat("  Trait Index:    ", opt$`trait-index`, "\n")
cat("  Models:         ", opt$models, "\n")
cat("  PCA Components: ", opt$pca, "\n")
cat("  MAF Filter:     ", opt$maf, "\n")
cat("  SNP FDR:        ", ifelse(is.null(opt$`snp-fdr`), "disabled", opt$`snp-fdr`), "\n")
cat("  Multiple Analysis:", opt$`multiple-analysis`, "\n")
cat("\n")

# Parse inputs
genotype_file <- opt$genotype
phenotype_file <- opt$phenotype
ids_file <- opt$ids

# Parse models (split comma-separated list and trim whitespace)
models <- strsplit(opt$models, ",")[[1]]
models <- trimws(models)

pca_components <- opt$pca
multiple_analysis <- opt$`multiple-analysis`

# Set thread count
Sys.setenv(OPENBLAS_NUM_THREADS = opt$threads)
Sys.setenv(OMP_NUM_THREADS = opt$threads)
cat("Thread count set to:", opt$threads, "\n\n")

# ==============================================================================
# Setup output directory
# ==============================================================================
trait_index <- opt$`trait-index`
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
output_dir <- file.path(opt$`output-dir`, sprintf("trait_%03d_%s", trait_index, timestamp))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Set working directory to output dir (GAPIT writes files to getwd())
setwd(output_dir)

cat("\n")
cat(strrep("=", 78), "\n")
cat("GAPIT3 GWAS Pipeline - Single Trait Execution\n")
cat(strrep("=", 78), "\n")
cat("Trait index:", trait_index, "\n")
cat("Output directory:", output_dir, "\n")
cat("GAPIT version:", as.character(packageVersion("GAPIT")), "\n")
cat("R version:", R.version.string, "\n")
cat("Models:", paste(models, collapse = ", "), "\n")
cat("PCA components:", pca_components, "\n")
cat(strrep("=", 78), "\n\n")

# ==============================================================================
# Metadata tracking (schema v2.0.0 with provenance)
# ==============================================================================

# Compute input file checksums (if enabled)
cat("Computing input file checksums...\n")
genotype_md5 <- compute_file_md5(genotype_file)
phenotype_md5 <- compute_file_md5(phenotype_file)
ids_md5 <- if (!is.null(ids_file) && ids_file != "") compute_file_md5(ids_file) else NULL

if (toupper(Sys.getenv("SKIP_INPUT_CHECKSUMS", "false")) == "TRUE") {
  cat("  - Checksums disabled (SKIP_INPUT_CHECKSUMS=true)\n")
} else {
  cat("  - Genotype MD5:", ifelse(is.null(genotype_md5), "N/A", genotype_md5), "\n")
  cat("  - Phenotype MD5:", ifelse(is.null(phenotype_md5), "N/A", phenotype_md5), "\n")
}

# Parse retry attempt (Argo provides as string, may be empty for first attempt)
retry_attempt_str <- get_env_or_null("RETRY_ATTEMPT")
retry_attempt <- if (!is.null(retry_attempt_str)) as.integer(retry_attempt_str) else NULL

metadata <- list(
  schema_version = "3.0.0",
  execution = list(
    trait_index = trait_index,
    start_time = Sys.time(),
    hostname = Sys.info()["nodename"],
    r_version = R.version.string,
    gapit_version = as.character(packageVersion("GAPIT"))
  ),
  argo = list(
    workflow_name = get_env_or_null("WORKFLOW_NAME"),
    workflow_uid = get_env_or_null("WORKFLOW_UID"),
    namespace = get_env_or_null("WORKFLOW_NAMESPACE"),
    pod_name = get_env_or_null("POD_NAME"),
    node_name = get_env_or_null("NODE_NAME"),
    retry_attempt = retry_attempt,
    max_retries = 5  # Default from workflow template
  ),
  container = list(
    image = get_env_or_null("CONTAINER_IMAGE")
  ),
  inputs = list(
    genotype_file = genotype_file,
    genotype_md5 = genotype_md5,
    phenotype_file = phenotype_file,
    phenotype_md5 = phenotype_md5,
    ids_file = if (ids_file != "") ids_file else NULL,
    ids_md5 = ids_md5
  ),
  parameters = list(
    # GAPIT parameters using native GAPIT naming convention (v3.0.0)
    gapit = list(
      model = models,
      PCA.total = pca_components,
      Multiple_analysis = multiple_analysis,
      SNP.MAF = opt$maf,
      SNP.FDR = opt$`snp-fdr`
    ),
    # Compute resources
    compute = list(
      openblas_threads = as.integer(Sys.getenv("OPENBLAS_NUM_THREADS", "12")),
      omp_threads = as.integer(Sys.getenv("OMP_NUM_THREADS", "12"))
    ),
    # Legacy parameter names for backward compatibility (v2.0.0)
    models = models,
    pca_components = pca_components,
    multiple_analysis = multiple_analysis,
    maf_filter = opt$maf,
    snp_fdr = opt$`snp-fdr`
  ),
  resources = list(
    threads = Sys.getenv("OPENBLAS_NUM_THREADS")
  )
)

# ==============================================================================
# Load and preprocess data
# ==============================================================================
cat("Loading phenotype data:", phenotype_file, "\n")
pheno_data <- read.table(phenotype_file, header = TRUE, stringsAsFactors = FALSE)
cat("  - Loaded", nrow(pheno_data), "rows,", ncol(pheno_data), "columns\n")

# Remove duplicates
pheno_unique <- pheno_data[!duplicated(pheno_data$Taxa), ]
cat("  - After removing duplicates:", nrow(pheno_unique), "accessions\n")

# Filter by accession IDs if provided
if (!is.null(ids_file) && file.exists(ids_file)) {
  cat("Filtering by accession IDs:", ids_file, "\n")
  ids_data <- read.table(ids_file, header = TRUE, stringsAsFactors = FALSE)
  pheno_filtered <- pheno_unique[pheno_unique$Taxa %in% ids_data$Taxa, ]
  cat("  - After filtering:", nrow(pheno_filtered), "accessions\n")
} else {
  pheno_filtered <- pheno_unique
}

# Extract specific trait
if (trait_index > ncol(pheno_filtered)) {
  stop("Error: Trait index ", trait_index, " exceeds number of columns (", ncol(pheno_filtered), ")")
}

trait_name <- colnames(pheno_filtered)[trait_index]
myY <- pheno_filtered[, c(1, trait_index)]  # Taxa + trait column
colnames(myY) <- c("Taxa", trait_name)

cat("\nSelected trait:", trait_name, "\n")
cat("  - Total samples:", nrow(myY), "\n")
cat("  - Valid values:", sum(!is.na(myY[[2]])), "\n")
cat("  - Missing values:", sum(is.na(myY[[2]])), "\n")

metadata$trait <- list(
  name = trait_name,
  column_index = trait_index,
  n_total = nrow(myY),
  n_valid = sum(!is.na(myY[[2]])),
  n_missing = sum(is.na(myY[[2]]))
)

# Load genotype data
cat("\nLoading genotype data:", genotype_file, "\n")
cat("  - This may take several minutes for large files...\n")
start_time <- Sys.time()
myG <- read.table(genotype_file, header = FALSE, stringsAsFactors = FALSE)
load_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
cat("  - Loaded in", round(load_time, 1), "seconds\n")
cat("  - SNPs:", nrow(myG) - 1, "\n")
cat("  - Accessions:", ncol(myG) - 11, "\n")

metadata$genotype <- list(
  n_snps = nrow(myG) - 1,
  n_accessions = ncol(myG) - 11,
  load_time_seconds = round(load_time, 1)
)

# ==============================================================================
# Run GAPIT
# ==============================================================================
cat("\n")
cat(strrep("=", 78), "\n")
cat("Starting GWAS analysis...\n")
cat(strrep("=", 78), "\n\n")

gwas_start <- Sys.time()

tryCatch({
  # Build GAPIT arguments
  gapit_args <- list(
    Y = myY,
    G = myG,
    PCA.total = pca_components,
    model = models,
    Multiple_analysis = multiple_analysis
  )

  # Add SNP.MAF if specified (GAPIT's native parameter name for MAF filtering)
  # Note: Previous versions incorrectly used MAF.Threshold which is not a valid GAPIT parameter
  if (!is.null(opt$maf) && opt$maf > 0) {
    cat("Applying SNP.MAF threshold:", opt$maf, "\n")
    gapit_args$SNP.MAF <- opt$maf
  }

  # Add SNP.FDR if specified
  if (!is.null(opt$`snp-fdr`)) {
    cat("Applying FDR threshold:", opt$`snp-fdr`, "\n")
    gapit_args$SNP.FDR <- opt$`snp-fdr`
  }

  # Run GAPIT with constructed arguments
  myGAPIT <- do.call(GAPIT, gapit_args)

  gwas_end <- Sys.time()
  gwas_duration <- as.numeric(difftime(gwas_end, gwas_start, units = "mins"))

  cat("\n")
  cat(strrep("=", 78), "\n")
  cat("GWAS analysis completed successfully!\n")
  cat("Duration:", round(gwas_duration, 2), "minutes\n")
  cat(strrep("=", 78), "\n\n")

  metadata$execution$end_time <- gwas_end
  metadata$execution$duration_minutes <- round(gwas_duration, 2)
  metadata$execution$status <- "success"

}, error = function(e) {
  cat("\nERROR during GWAS analysis:\n")
  cat(conditionMessage(e), "\n")

  metadata$execution$end_time <- Sys.time()
  metadata$execution$status <- "failed"
  metadata$execution$error <- conditionMessage(e)

  # Write metadata even on failure
  write_json(metadata, file.path(output_dir, "metadata.json"), pretty = TRUE, auto_unbox = TRUE)

  stop(e)
})

# ==============================================================================
# Save metadata
# ==============================================================================
metadata_file <- file.path(output_dir, "metadata.json")
write_json(metadata, metadata_file, pretty = TRUE, auto_unbox = TRUE)
cat("Metadata saved to:", metadata_file, "\n")

# ==============================================================================
# Summarize results
# ==============================================================================
cat("\nResults saved in:", output_dir, "\n")
cat("Files generated:\n")
result_files <- list.files(output_dir, recursive = FALSE)
for (f in result_files) {
  cat("  -", f, "\n")
}

cat("\n✓ Single trait GWAS completed successfully\n\n")
