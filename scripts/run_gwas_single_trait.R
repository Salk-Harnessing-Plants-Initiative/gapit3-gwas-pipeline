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
  library(yaml)
  library(jsonlite)
})

# ==============================================================================
# Parse command line arguments
# ==============================================================================
option_list <- list(
  make_option(c("-t", "--trait-index"), type = "integer", default = NULL,
              help = "Trait column index (required)", metavar = "INTEGER"),
  make_option(c("-c", "--config"), type = "character", default = "/config/config.yaml",
              help = "Path to config file [default: %default]", metavar = "FILE"),
  make_option(c("-g", "--genotype"), type = "character", default = NULL,
              help = "Path to genotype HapMap file (overrides config)", metavar = "FILE"),
  make_option(c("-p", "--phenotype"), type = "character", default = NULL,
              help = "Path to phenotype file (overrides config)", metavar = "FILE"),
  make_option(c("-i", "--ids"), type = "character", default = NULL,
              help = "Path to accession IDs file (overrides config)", metavar = "FILE"),
  make_option(c("-o", "--output-dir"), type = "character", default = "/outputs",
              help = "Output directory [default: %default]", metavar = "DIR"),
  make_option(c("-m", "--models"), type = "character", default = NULL,
              help = "Comma-separated models (e.g., 'BLINK,FarmCPU') [overrides config]", metavar = "STRING"),
  make_option(c("--pca"), type = "integer", default = NULL,
              help = "Number of PCA components [overrides config]", metavar = "INTEGER"),
  make_option(c("--threads"), type = "integer", default = NULL,
              help = "Number of CPU threads to use", metavar = "INTEGER")
)

opt_parser <- OptionParser(option_list = option_list,
                          description = "\nRun GWAS analysis for a single trait using GAPIT3")
opt <- parse_args(opt_parser)

# Validate required arguments
if (is.null(opt$`trait-index`)) {
  stop("Error: --trait-index is required\n", call. = FALSE)
}

# ==============================================================================
# Load configuration
# ==============================================================================
cat("Loading configuration from:", opt$config, "\n")
config <- read_yaml(opt$config)

# Override config with command-line arguments if provided
genotype_file <- ifelse(is.null(opt$genotype), config$data$genotype, opt$genotype)
phenotype_file <- ifelse(is.null(opt$phenotype), config$data$phenotype, opt$phenotype)
ids_file <- ifelse(is.null(opt$ids), config$data$accession_ids, opt$ids)

# GAPIT parameters
if (!is.null(opt$models)) {
  models <- strsplit(opt$models, ",")[[1]]
} else {
  models <- config$gapit$models
}

pca_components <- ifelse(is.null(opt$pca), config$gapit$pca_components, opt$pca)

# Set thread count
if (!is.null(opt$threads)) {
  Sys.setenv(OPENBLAS_NUM_THREADS = opt$threads)
  Sys.setenv(OMP_NUM_THREADS = opt$threads)
  cat("Set thread count to:", opt$threads, "\n")
}

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
cat("=" %R% 78, "\n")
cat("GAPIT3 GWAS Pipeline - Single Trait Execution\n")
cat("=" %R% 78, "\n")
cat("Trait index:", trait_index, "\n")
cat("Output directory:", output_dir, "\n")
cat("GAPIT version:", as.character(packageVersion("GAPIT")), "\n")
cat("R version:", R.version.string, "\n")
cat("Models:", paste(models, collapse = ", "), "\n")
cat("PCA components:", pca_components, "\n")
cat("=" %R% 78, "\n\n")

# ==============================================================================
# Metadata tracking
# ==============================================================================
metadata <- list(
  execution = list(
    trait_index = trait_index,
    start_time = Sys.time(),
    hostname = Sys.info()["nodename"],
    r_version = R.version.string,
    gapit_version = as.character(packageVersion("GAPIT"))
  ),
  inputs = list(
    genotype_file = genotype_file,
    phenotype_file = phenotype_file,
    ids_file = ids_file
  ),
  parameters = list(
    models = models,
    pca_components = pca_components,
    multiple_analysis = config$gapit$multiple_analysis
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
cat("=" %R% 78, "\n")
cat("Starting GWAS analysis...\n")
cat("=" %R% 78, "\n\n")

gwas_start <- Sys.time()

tryCatch({
  myGAPIT <- GAPIT(
    Y = myY,
    G = myG,
    PCA.total = pca_components,
    model = models,
    Multiple_analysis = config$gapit$multiple_analysis %||% TRUE
  )

  gwas_end <- Sys.time()
  gwas_duration <- as.numeric(difftime(gwas_end, gwas_start, units = "mins"))

  cat("\n")
  cat("=" %R% 78, "\n")
  cat("GWAS analysis completed successfully!\n")
  cat("Duration:", round(gwas_duration, 2), "minutes\n")
  cat("=" %R% 78, "\n\n")

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
