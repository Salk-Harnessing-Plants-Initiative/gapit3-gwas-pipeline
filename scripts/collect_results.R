#!/usr/bin/env Rscript
# ==============================================================================
# GAPIT3 Results Collector
# ==============================================================================
# Aggregates results from all trait analyses into summary reports
# Reads GAPIT Filter files (significant SNPs only) and tracks model information
# Creates summary tables with per-model statistics
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
              help = "Genome-wide significance threshold [default: %default]", metavar = "FLOAT"),
  make_option(c("-m", "--models"), type = "character", default = "BLINK,FarmCPU,MLM",
              help = "Expected models for completeness check [default: %default]", metavar = "STRING")
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
expected_models <- strsplit(opt$models, ",")[[1]]

cat(strrep("=", 78), "\n")
cat("GAPIT3 Results Collector\n")
cat(strrep("=", 78), "\n")
cat("Output directory:", output_dir, "\n")
cat("Batch ID:", batch_id, "\n")
cat("Significance threshold:", threshold, "\n")
cat("Expected models:", paste(expected_models, collapse = ", "), "\n")
cat(strrep("=", 78), "\n\n")

# ==============================================================================
# Helper Functions
# ==============================================================================

#' Select best directory for each trait index (deduplication)
#'
#' When multiple directories exist for the same trait (from retries),
#' select the one with the most complete model outputs.
#' If tied, select the newest (by timestamp in directory name).
#'
#' @param trait_dirs Vector of trait directory paths
#' @param expected_models Vector of expected model names (e.g., c("BLINK", "FarmCPU", "MLM"))
#' @return Vector of selected trait directory paths (one per trait index)
select_best_trait_dirs <- function(trait_dirs, expected_models) {
  if (length(trait_dirs) == 0) return(character(0))

  # Build info table for all directories
  trait_info <- data.frame(
    path = trait_dirs,
    basename = basename(trait_dirs),
    stringsAsFactors = FALSE
  )

  # Extract trait index from directory name
  # Pattern: trait_<index>_<name>_<timestamp> or trait_<index>_<timestamp>
  trait_info$trait_index <- as.integer(
    sub("trait_(\\d+)_.*", "\\1", trait_info$basename)
  )

  # Count complete models for each directory
  trait_info$n_models <- sapply(trait_info$path, function(dir) {
    sum(sapply(expected_models, function(model) {
      pattern <- paste0("GAPIT\\.Association\\.GWAS_Results\\.", model, "\\.")
      length(list.files(dir, pattern = pattern)) > 0
    }))
  })

  # Extract timestamp for tie-breaking
  # Try to find YYYYMMDD_HHMMSS pattern at end of directory name
  trait_info$timestamp <- sub(".*_(\\d{8}_\\d{6})$", "\\1", trait_info$basename)
  # If no timestamp found, use basename for sorting
  trait_info$timestamp[trait_info$timestamp == trait_info$basename] <- "00000000_000000"

  # Find traits with duplicates (for logging)
  dup_counts <- table(trait_info$trait_index)
  dup_traits <- names(dup_counts[dup_counts > 1])

  if (length(dup_traits) > 0) {
    cat("  Note: Found multiple directories for", length(dup_traits), "trait(s)\n")
    cat("  Selecting most complete directory for each:\n")

    for (idx in as.integer(dup_traits)) {
      dirs_for_trait <- trait_info[trait_info$trait_index == idx, ]
      dirs_for_trait <- dirs_for_trait[order(-dirs_for_trait$n_models, -dirs_for_trait$timestamp), ]
      selected <- dirs_for_trait[1, ]
      others <- dirs_for_trait[-1, ]

      cat("    - Trait", idx, ":", nrow(dirs_for_trait), "directories\n")
      cat("      Selected:", selected$basename,
          "(", selected$n_models, "/", length(expected_models), "models)\n")
      for (j in seq_len(nrow(others))) {
        cat("      Skipped:", others$basename[j],
            "(", others$n_models[j], "/", length(expected_models), "models)\n")
      }
    }
    cat("\n")
  }

  # For each trait index, select best directory
  # Priority: most models complete, then newest timestamp
  selected <- trait_info %>%
    group_by(trait_index) %>%
    arrange(desc(n_models), desc(timestamp)) %>%
    slice(1) %>%
    ungroup()

  return(selected$path)
}

#' Read GAPIT Filter file and parse model information
#'
#' Reads GAPIT.Association.Filter_GWAS_results.csv which contains only
#' significant SNPs with model information in the traits column.
#' Format: "<MODEL>.<TraitName>" (e.g., "BLINK.root_length")
#'
#' @param trait_dir Path to trait result directory
#' @param threshold Significance threshold (for fallback only)
#' @return data.frame with columns including model and trait
read_filter_file <- function(trait_dir, threshold = 5e-8) {
  filter_file <- file.path(trait_dir, "GAPIT.Association.Filter_GWAS_results.csv")

  if (!file.exists(filter_file)) {
    # Fall back to reading GWAS_Results files
    return(read_gwas_results_fallback(trait_dir, threshold))
  }

  tryCatch({
    # Read Filter file (contains only significant SNPs)
    filter_data <- fread(filter_file, data.table = FALSE)

    # Check if traits column exists
    # No traits column means no significant SNPs found (empty Filter file)
    if (!"traits" %in% colnames(filter_data)) {
      return(data.frame())
    }

    # Return empty data.frame if no rows (no significant SNPs)
    if (nrow(filter_data) == 0) {
      return(data.frame())
    }

    # Parse model and trait from traits column
    # Format: "<MODEL>.<TraitName>"
    # Handle compound models (FarmCPU.LM, Blink.LM) before simple split
    filter_data$model <- ifelse(
      grepl("^FarmCPU\\.LM\\.", filter_data$traits), "FarmCPU.LM",
      ifelse(grepl("^Blink\\.LM\\.", filter_data$traits), "Blink.LM",
             sub("\\..*", "", filter_data$traits))
    )
    filter_data$trait <- ifelse(
      grepl("^FarmCPU\\.LM\\.", filter_data$traits),
      sub("^FarmCPU\\.LM\\.", "", filter_data$traits),
      ifelse(grepl("^Blink\\.LM\\.", filter_data$traits),
             sub("^Blink\\.LM\\.", "", filter_data$traits),
             sub("^[^.]+\\.", "", filter_data$traits))
    )

    # Validate model names (warn if unexpected, but continue)
    expected_models <- c("BLINK", "FarmCPU", "GLM", "MLM", "MLMM",
                         "FarmCPU.LM", "Blink.LM")
    unexpected <- unique(filter_data$model[!(filter_data$model %in% expected_models)])
    if (length(unexpected) > 0) {
      cat("  Warning: Unexpected model names in", basename(trait_dir), ":",
          paste(unexpected, collapse=", "), "\n")
    }

    # Remove original traits column
    filter_data$traits <- NULL

    return(filter_data)

  }, error = function(e) {
    cat("  Warning: Error reading Filter file for", basename(trait_dir), ":",
        e$message, "\n")
    return(read_gwas_results_fallback(trait_dir, threshold))
  })
}

#' Fallback to reading complete GWAS_Results files when Filter file unavailable
#'
#' @param trait_dir Path to trait result directory
#' @param threshold Significance threshold for filtering
#' @return data.frame with model and trait columns
read_gwas_results_fallback <- function(trait_dir, threshold) {
  cat("  Warning: Filter file missing for", basename(trait_dir),
      "- using GWAS_Results fallback (slower)\n")

  # Find GWAS_Results files
  gwas_files <- list.files(trait_dir, pattern = "GAPIT.*GWAS_Results.*csv$",
                          full.names = TRUE)

  if (length(gwas_files) == 0) {
    return(data.frame())
  }

  # Get trait name from metadata
  meta_file <- file.path(trait_dir, "metadata.json")
  trait_name <- if (file.exists(meta_file)) {
    name <- tryCatch(fromJSON(meta_file)$trait$name, error = function(e) NULL)
    if (is.null(name)) basename(trait_dir) else name
  } else {
    basename(trait_dir)
  }

  all_snps <- data.frame()

  for (gwas_file in gwas_files) {
    tryCatch({
      gwas_data <- fread(gwas_file, data.table = FALSE)

      if ("P.value" %in% colnames(gwas_data)) {
        # Filter for significant SNPs
        sig_snps <- gwas_data[gwas_data$P.value < threshold, ]

        if (nrow(sig_snps) > 0) {
          # Try to infer model from filename
          # Pattern: GAPIT.Association.GWAS_Results.<MODEL>.<TraitName>.csv
          filename <- basename(gwas_file)
          model_match <- regmatches(filename,
                                   regexpr("GWAS_Results\\.(\\w+)\\.", filename))
          if (length(model_match) > 0) {
            model <- sub("GWAS_Results\\.", "", sub("\\.$", "", model_match))
          } else {
            model <- "unknown"
          }

          sig_snps$model <- model
          sig_snps$trait <- trait_name
          all_snps <- rbind(all_snps, sig_snps)
        }
      }
    }, error = function(e) {
      cat("  Warning: Could not read", basename(gwas_file), "\n")
    })
  }

  return(all_snps)
}

# ==============================================================================
# Find all trait result directories (with deduplication)
# ==============================================================================
cat("Scanning for trait results...\n")
all_trait_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = TRUE)
all_trait_dirs <- all_trait_dirs[grepl("trait_\\d+_", basename(all_trait_dirs))]

cat("Found", length(all_trait_dirs), "trait result directories\n")

if (length(all_trait_dirs) == 0) {
  cat("No trait results found. Exiting.\n")
  quit(status = 0)
}

# Deduplicate: select best directory per trait index
trait_dirs <- select_best_trait_dirs(all_trait_dirs, expected_models)
cat("After deduplication:", length(trait_dirs), "unique traits\n\n")

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
# Collect significant SNPs using Filter files
# ==============================================================================
cat("Collecting significant SNPs...\n")
cat("  - Reading Filter files (fast mode)\n")

all_snps <- data.frame()

for (dir in trait_dirs) {
  trait_snps <- read_filter_file(dir, threshold)

  if (nrow(trait_snps) > 0) {
    all_snps <- rbind(all_snps, trait_snps)
  }
}

# Sort by P.value (most significant first)
if (nrow(all_snps) > 0) {
  all_snps <- all_snps[order(all_snps$P.value), ]
}

# Detect models and calculate statistics
if (nrow(all_snps) > 0 && "model" %in% colnames(all_snps)) {
  detected_models <- unique(all_snps$model)
  cat("  - Models detected:", paste(detected_models, collapse=", "), "\n")
  cat("  - Total significant SNPs:", nrow(all_snps), "\n")

  # Count per model
  for (model in detected_models) {
    model_count <- sum(all_snps$model == model)
    cat("    -", model, ":", model_count, "SNPs\n")
  }

  # Find SNPs in multiple models (same SNP/Chr/Pos)
  if ("SNP" %in% colnames(all_snps) && "Chr" %in% colnames(all_snps) &&
      "Pos" %in% colnames(all_snps)) {
    snp_models <- all_snps %>%
      group_by(SNP, Chr, Pos) %>%
      summarise(n_models = n_distinct(model), .groups = "drop")
    overlap_count <- sum(snp_models$n_models > 1)
    if (overlap_count > 0) {
      cat("    - Found by multiple models:", overlap_count, "SNPs\n")
    }
  }
} else {
  cat("  - Total significant SNPs:", nrow(all_snps), "\n")
}

# Save aggregated significant SNPs
if (nrow(all_snps) > 0) {
  sig_snps_file <- file.path(output_dir, "aggregated_results", "all_traits_significant_snps.csv")
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
  total_directories_found = length(all_trait_dirs),
  unique_traits = length(trait_dirs),
  successful_traits = success_count,
  failed_traits = failed_count,
  total_significant_snps = nrow(all_snps),
  average_duration_minutes = mean(summary_df$duration_minutes, na.rm = TRUE),
  total_duration_hours = sum(summary_df$duration_minutes, na.rm = TRUE) / 60,
  expected_models = expected_models
)

# Add per-model statistics if model column exists
if (nrow(all_snps) > 0 && "model" %in% colnames(all_snps)) {
  snps_by_model <- list()

  # Count SNPs per model
  for (model in unique(all_snps$model)) {
    snps_by_model[[model]] <- sum(all_snps$model == model)
  }

  # Find overlap (SNPs found by multiple models)
  if ("SNP" %in% colnames(all_snps) && "Chr" %in% colnames(all_snps) &&
      "Pos" %in% colnames(all_snps)) {
    snp_models <- all_snps %>%
      group_by(SNP, Chr, Pos) %>%
      summarise(n_models = n_distinct(model),
               models = paste(sort(unique(model)), collapse=","),
               .groups = "drop")

    overlap_snps <- snp_models %>%
      filter(n_models > 1) %>%
      pull(SNP)

    snps_by_model$both_models <- length(overlap_snps)
    if (length(overlap_snps) > 0) {
      snps_by_model$overlap_snps <- overlap_snps
    }
  }

  stats$snps_by_model <- snps_by_model
}

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
cat("  - Directories found:", length(all_trait_dirs), "\n")
cat("  - Unique traits:", length(trait_dirs), "\n")
cat("  - Successful:", success_count, "\n")
cat("  - Failed:", failed_count, "\n\n")

cat("Significant SNPs:", nrow(all_snps), "\n")
if (!is.null(stats$snps_by_model)) {
  for (model in names(stats$snps_by_model)) {
    if (model != "both_models" && model != "overlap_snps") {
      cat("  -", model, ":", stats$snps_by_model[[model]], "\n")
    }
  }
  if (!is.null(stats$snps_by_model$both_models) && stats$snps_by_model$both_models > 0) {
    cat("  - Overlap:", stats$snps_by_model$both_models, "\n")
  }
}
cat("\nAverage duration:", round(stats$average_duration_minutes, 2), "minutes/trait\n")
cat("Total compute time:", round(stats$total_duration_hours, 2), "hours\n\n")

cat("Results directory:", file.path(output_dir, "aggregated_results"), "\n")
cat(strrep("=", 78), "\n\n")

cat("✓ Results collection complete!\n\n")
