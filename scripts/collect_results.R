#!/usr/bin/env Rscript
# ==============================================================================
# GAPIT3 Results Collector
# ==============================================================================
# Aggregates results from all trait analyses into summary reports
# Combines Manhattan plots, identifies significant SNPs, creates final report
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(ggplot2)
  library(gridExtra)
  library(jsonlite)
  library(optparse)
})

# ==============================================================================
# Parse arguments
# ==============================================================================
option_list <- list(
  make_option(c("-o", "--output-dir"), type = "character", default = "/outputs",
              help = "Output directory containing trait results", metavar = "DIR"),
  make_option(c("-b", "--batch-id"), type = "character", default = "unknown",
              help = "Batch/workflow ID for tracking", metavar = "STRING"),
  make_option(c("-t", "--threshold"), type = "numeric", default = 5e-8,
              help = "Genome-wide significance threshold [default: %default]", metavar = "FLOAT")
)

opt_parser <- OptionParser(option_list = option_list,
                          description = "\nAggregate GWAS results from multiple traits")
opt <- parse_args(opt_parser)

# ==============================================================================
# Setup
# ==============================================================================
output_dir <- opt$`output-dir`
batch_id <- opt$`batch-id`
threshold <- opt$threshold

cat(strrep("=", 78), "\n")
cat("GAPIT3 Results Collector\n")
cat(strrep("=", 78), "\n")
cat("Output directory:", output_dir, "\n")
cat("Batch ID:", batch_id, "\n")
cat("Significance threshold:", threshold, "\n")
cat(strrep("=", 78), "\n\n")

# ==============================================================================
# Find all trait result directories
# ==============================================================================
cat("Scanning for trait results...\n")
trait_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = TRUE)
trait_dirs <- trait_dirs[grepl("trait_\\d+_", basename(trait_dirs))]

cat("Found", length(trait_dirs), "trait result directories\n\n")

if (length(trait_dirs) == 0) {
  cat("No trait results found. Exiting.\n")
  quit(status = 0)
}

# ==============================================================================
# Collect metadata from all traits
# ==============================================================================
cat("Collecting metadata...\n")

metadata_list <- list()
success_count <- 0
failed_count <- 0

for (dir in trait_dirs) {
  metadata_file <- file.path(dir, "metadata.json")

  if (file.exists(metadata_file)) {
    meta <- fromJSON(metadata_file)

    if (!is.null(meta$execution$status) && meta$execution$status == "success") {
      metadata_list[[length(metadata_list) + 1]] <- meta
      success_count <- success_count + 1
    } else {
      failed_count <- failed_count + 1
    }
  }
}

cat("  - Successful:", success_count, "\n")
cat("  - Failed:", failed_count, "\n\n")

# ==============================================================================
# Create summary dataframe
# ==============================================================================
cat("Creating summary table...\n")

summary_df <- data.frame(
  trait_index = integer(),
  trait_name = character(),
  n_samples = integer(),
  n_valid = integer(),
  n_snps = integer(),
  duration_minutes = numeric(),
  status = character(),
  stringsAsFactors = FALSE
)

for (meta in metadata_list) {
  summary_df <- rbind(summary_df, data.frame(
    trait_index = if (is.null(meta$trait$column_index)) NA else meta$trait$column_index,
    trait_name = if (is.null(meta$trait$name)) "unknown" else meta$trait$name,
    n_samples = if (is.null(meta$trait$n_total)) NA else meta$trait$n_total,
    n_valid = if (is.null(meta$trait$n_valid)) NA else meta$trait$n_valid,
    n_snps = if (is.null(meta$genotype$n_snps)) NA else meta$genotype$n_snps,
    duration_minutes = if (is.null(meta$execution$duration_minutes)) NA else meta$execution$duration_minutes,
    status = if (is.null(meta$execution$status)) "unknown" else meta$execution$status,
    stringsAsFactors = FALSE
  ))
}

# Sort by trait index
summary_df <- summary_df[order(summary_df$trait_index), ]

# ==============================================================================
# Save summary table
# ==============================================================================
summary_file <- file.path(output_dir, "aggregated_results", "summary_table.csv")
dir.create(dirname(summary_file), recursive = TRUE, showWarnings = FALSE)

write.csv(summary_df, summary_file, row.names = FALSE)
cat("Summary table saved:", summary_file, "\n\n")

# ==============================================================================
# Collect significant SNPs (if GWAS result files exist)
# ==============================================================================
cat("Collecting significant SNPs...\n")

# GAPIT typically creates files like: GAPIT.Association.GWAS_Results.*.csv
# Find all GWAS result files

all_snps <- data.frame()
snp_count <- 0

for (dir in trait_dirs) {
  gwas_files <- list.files(dir, pattern = "GAPIT.*GWAS_Results.*csv$", full.names = TRUE)

  for (gwas_file in gwas_files) {
    tryCatch({
      gwas_data <- fread(gwas_file)

      # Check if P.value column exists
      if ("P.value" %in% colnames(gwas_data)) {
        # Get trait name from metadata
        meta_file <- file.path(dir, "metadata.json")
        trait_name <- if (file.exists(meta_file)) {
          name <- tryCatch(fromJSON(meta_file)$trait$name, error = function(e) NULL)
          if (is.null(name)) basename(dir) else name
        } else {
          basename(dir)
        }

        # Filter significant SNPs
        sig_snps <- gwas_data[gwas_data$P.value < threshold, ]

        if (nrow(sig_snps) > 0) {
          sig_snps$trait <- trait_name
          all_snps <- rbind(all_snps, sig_snps)
          snp_count <- snp_count + nrow(sig_snps)
        }
      }
    }, error = function(e) {
      cat("  Warning: Could not read", basename(gwas_file), "\n")
    })
  }
}

cat("  - Total significant SNPs:", snp_count, "\n")

if (nrow(all_snps) > 0) {
  sig_snps_file <- file.path(output_dir, "aggregated_results", "significant_snps.csv")
  write.csv(all_snps, sig_snps_file, row.names = FALSE)
  cat("Significant SNPs saved:", sig_snps_file, "\n")
}

cat("\n")

# ==============================================================================
# Generate summary statistics
# ==============================================================================
cat("Generating summary statistics...\n")

stats <- list(
  batch_id = batch_id,
  collection_time = Sys.time(),
  total_traits_attempted = length(trait_dirs),
  successful_traits = success_count,
  failed_traits = failed_count,
  total_significant_snps = snp_count,
  average_duration_minutes = mean(summary_df$duration_minutes, na.rm = TRUE),
  total_duration_hours = sum(summary_df$duration_minutes, na.rm = TRUE) / 60
)

stats_file <- file.path(output_dir, "aggregated_results", "summary_stats.json")
write_json(stats, stats_file, pretty = TRUE, auto_unbox = TRUE)
cat("Summary statistics saved:", stats_file, "\n\n")

# ==============================================================================
# Print summary
# ==============================================================================
cat(strrep("=", 78), "\n")
cat("Results Collection Summary\n")
cat(strrep("=", 78), "\n")
cat("Batch ID:", batch_id, "\n")
cat("Collection time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("Traits:\n")
cat("  - Total attempted:", length(trait_dirs), "\n")
cat("  - Successful:", success_count, "\n")
cat("  - Failed:", failed_count, "\n\n")

cat("Significant SNPs:", snp_count, "\n")
cat("Average duration:", round(stats$average_duration_minutes, 2), "minutes/trait\n")
cat("Total compute time:", round(stats$total_duration_hours, 2), "hours\n\n")

cat("Results directory:", file.path(output_dir, "aggregated_results"), "\n")
cat(strrep("=", 78), "\n\n")

cat("✓ Results collection complete!\n\n")
