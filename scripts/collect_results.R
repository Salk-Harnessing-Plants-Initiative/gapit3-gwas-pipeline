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
  library(tidyr)
  library(ggplot2)
  library(gridExtra)
  library(jsonlite)
  library(optparse)
})

# ==============================================================================
# Source modules (provides reusable, testable functions)
# ==============================================================================
# Robust path resolution that works regardless of working directory
.get_script_dir <- function() {
  # Try to get the path of this script from command line arguments

cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd_args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg))))
  }

  # Fallback: check common locations
  candidates <- c(
    "scripts",
    ".",
    file.path(getwd(), "scripts")
  )

  for (path in candidates) {
    if (file.exists(file.path(path, "lib", "constants.R"))) {
      return(normalizePath(path))
    }
  }

  # Last resort: search upward from current directory
  current <- getwd()
  while (current != dirname(current)) {
    test_path <- file.path(current, "scripts")
    if (file.exists(file.path(test_path, "lib", "constants.R"))) {
      return(normalizePath(test_path))
    }
    current <- dirname(current)
  }

  stop("Could not locate scripts/lib/constants.R - ensure you're running from the project directory")
}

.script_dir <- .get_script_dir()
source(file.path(.script_dir, "lib", "constants.R"))
source(file.path(.script_dir, "lib", "aggregation_utils.R"))

# ==============================================================================
# Helper function for environment variables
# ==============================================================================

#' Get environment variable with NULL fallback for empty strings
#' @param name Environment variable name
#' @param default Default value if not set or empty
#' @return The value or NULL if empty/unset
get_env_or_null <- function(name, default = NULL) {
  value <- trimws(Sys.getenv(name, ""))
  if (value == "" || value == "null" || value == "NULL") {
    return(default)
  }
  return(value)
}

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
  make_option(c("-m", "--models"), type = "character", default = DEFAULT_MODELS_STRING,
              help = "Expected models for completeness check [default: %default]", metavar = "STRING"),
  make_option(c("--allow-incomplete"), action = "store_true", default = FALSE,
              help = "Allow aggregation with incomplete traits (skip them with warning)"),
  make_option(c("--no-markdown"), action = "store_true", default = FALSE,
              help = "Skip markdown summary generation"),
  make_option(c("--markdown-only"), action = "store_true", default = FALSE,
              help = "Only regenerate markdown from existing JSON/CSV (no re-aggregation)")
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
allow_incomplete <- opt$`allow-incomplete`
no_markdown <- opt$`no-markdown`
markdown_only <- opt$`markdown-only`

# Determine expected models and their source
# Priority: CLI flag > auto-detected from metadata > default
models_source <- "default"  # Track where models came from
cli_models_specified <- opt$models != DEFAULT_MODELS_STRING

if (cli_models_specified) {
  # User explicitly specified models via CLI
  expected_models <- strsplit(opt$models, ",")[[1]]
  models_source <- "cli"
} else {
  # Try to auto-detect from first trait's metadata
  detected_models <- detect_models_from_first_trait(output_dir)

  if (!is.null(detected_models) && length(detected_models) > 0) {
    # Validate detected models
    validation <- validate_model_names(detected_models)
    if (validation$valid) {
      expected_models <- validation$canonical_models
      models_source <- "auto-detected"
    } else {
      warning(sprintf("Invalid models detected in metadata: %s. Using defaults.",
                      paste(validation$invalid_models, collapse = ", ")))
      expected_models <- DEFAULT_MODELS
      models_source <- "default"
    }
  } else {
    # Fall back to defaults
    expected_models <- DEFAULT_MODELS
    models_source <- "default"
  }
}

cat(strrep("=", 78), "\n")
cat("GAPIT3 Results Collector\n")
cat(strrep("=", 78), "\n")
cat("Output directory:", output_dir, "\n")
cat("Batch ID:", batch_id, "\n")
cat("Significance threshold:", threshold, "\n")
cat("Expected models:", paste(expected_models, collapse = ", "), "\n")
cat("Models source:", models_source, "\n")
cat("Allow incomplete:", allow_incomplete, "\n")
cat("No markdown:", no_markdown, "\n")
cat("Markdown only:", markdown_only, "\n")
cat(strrep("=", 78), "\n\n")

# ==============================================================================
# Markdown-only mode: regenerate from existing data
# ==============================================================================
if (markdown_only) {
  cat("Running in markdown-only mode...\n")

  agg_dir <- file.path(output_dir, "aggregated_results")
  stats_file <- file.path(agg_dir, "summary_stats.json")
  snps_file <- file.path(agg_dir, "all_traits_significant_snps.csv")
  summary_file <- file.path(agg_dir, "summary_table.csv")

  if (!file.exists(stats_file)) {
    stop("Cannot find ", stats_file, ". Run full aggregation first.")
  }
  if (!file.exists(snps_file)) {
    stop("Cannot find ", snps_file, ". Run full aggregation first.")
  }
  if (!file.exists(summary_file)) {
    stop("Cannot find ", summary_file, ". Run full aggregation first.")
  }

  cat("Loading existing aggregated data...\n")
  stats <- fromJSON(stats_file)
  snps_df <- fread(snps_file)
  summary_df <- fread(summary_file)

  # Try to load first trait metadata for configuration details
  trait_dirs <- list.dirs(output_dir, recursive = FALSE)
  trait_dirs <- trait_dirs[grepl("^trait_\\d+", basename(trait_dirs))]
  first_metadata <- NULL
  if (length(trait_dirs) > 0) {
    meta_file <- file.path(trait_dirs[1], "metadata.json")
    if (file.exists(meta_file)) {
      first_metadata <- fromJSON(meta_file)
    }
  }

  generate_markdown_summary(
    output_dir = agg_dir,
    stats = stats,
    summary_table = summary_df,
    snps_df = snps_df,
    metadata = first_metadata
  )

  cat("\n✓ Markdown regeneration complete!\n")
  quit(save = "no", status = 0)
}

# ==============================================================================
# Helper Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# Markdown section generators
# Note: Formatting helpers (format_pvalue, format_number, format_duration,
# truncate_string) are provided by aggregation_utils.R
# ------------------------------------------------------------------------------

#' Generate executive summary section
#' @param stats Summary statistics list
#' @param top_snp Data frame with top SNP (first row used)
#' @param top_trait List with name and count of top trait
#' @return Character string with markdown
generate_executive_summary <- function(stats, top_snp, top_trait) {
  success_rate <- if (stats$total_traits_attempted > 0) {
    sprintf("%.1f%%", 100 * stats$successful_traits / stats$total_traits_attempted)
  } else {
    "N/A"
  }

  top_hit_str <- if (!is.null(top_snp) && nrow(top_snp) > 0) {
    sprintf("%s (p = %s)", top_snp$SNP[1], format_pvalue(top_snp$P.value[1]))
  } else {
    "N/A"
  }

  top_trait_str <- if (!is.null(top_trait) && !is.null(top_trait$name)) {
    sprintf("%s (%s SNPs)", top_trait$name, format_number(top_trait$count))
  } else {
    "N/A"
  }

  # Show source workflows info if multi-workflow aggregation
  workflow_info <- if (!is.null(stats$is_multi_workflow) && stats$is_multi_workflow) {
    sprintf("| Source Workflows | %d |", length(stats$workflow_stats))
  } else {
    sprintf("| Workflow ID | `%s` |", stats$batch_id)
  }

  lines <- c(
    "## Executive Summary",
    "",
    "| Metric | Value |",
    "|--------|-------|",
    workflow_info,
    sprintf("| Analysis Date | %s |", if (!is.null(stats$collection_time)) format(as.Date(stats$collection_time), "%Y-%m-%d") else "N/A"),
    sprintf("| Total Traits Analyzed | %s |", format_number(stats$total_traits_attempted)),
    sprintf("| Successful | %s (%s) |", format_number(stats$successful_traits), success_rate),
    sprintf("| Failed | %s |", format_number(stats$failed_traits)),
    sprintf("| **Total Significant SNPs** | **%s** |", format_number(stats$total_significant_snps)),
    sprintf("| Top Hit | %s |", top_hit_str),
    sprintf("| Top Trait | %s |", top_trait_str),
    sprintf("| Total Runtime | %s |", format_duration(stats$total_duration_hours, "hours")),
    sprintf("| Avg Runtime per Trait | %s |", format_duration(stats$average_duration_minutes)),
    ""
  )

  paste(lines, collapse = "\n")
}

# Note: get_gapit_param and generate_configuration_section are provided by
# aggregation_utils.R - no need to duplicate here

#' Generate top SNPs table
#' @param snps_df Data frame of significant SNPs
#' @param top_n Number of SNPs to show
#' @return Character string with markdown
generate_top_snps_table <- function(snps_df, top_n = 20) {
  if (is.null(snps_df) || nrow(snps_df) == 0) {
    return(paste(c(
      "### Top Significant SNPs",
      "",
      "*No significant SNPs found at the specified threshold.*",
      ""
    ), collapse = "\n"))
  }

  # Ensure sorted by P.value
  snps_df <- snps_df[order(snps_df$P.value), ]

  # Take top N
  top_snps <- head(snps_df, top_n)

  lines <- c(
    sprintf("### Top %d Significant SNPs", min(top_n, nrow(snps_df))),
    "",
    "| Rank | SNP | Chr | Position | P-value | MAF | Model | Trait |",
    "|------|-----|-----|----------|---------|-----|-------|-------|"
  )

  for (i in seq_len(nrow(top_snps))) {
    row <- top_snps[i, ]
    model_val <- if ("model" %in% names(row) && !is.na(row$model)) row$model else "N/A"
    trait_val <- if ("trait" %in% names(row) && !is.na(row$trait)) truncate_string(row$trait, 35) else "N/A"
    maf_val <- if ("MAF" %in% names(row) && !is.na(row$MAF)) sprintf("%.3f", row$MAF) else "N/A"
    lines <- c(lines, sprintf(
      "| %d | %s | %s | %s | %s | %s | %s | %s |",
      i,
      row$SNP,
      row$Chr,
      format_number(row$Pos),
      format_pvalue(row$P.value),
      maf_val,
      model_val,
      trait_val
    ))
  }

  if (nrow(snps_df) > top_n) {
    lines <- c(lines, "",
      sprintf("*Showing top %d of %s total significant SNPs. See `all_traits_significant_snps.csv` for complete data.*",
              top_n, format_number(nrow(snps_df))))
  }

  lines <- c(lines, "")
  paste(lines, collapse = "\n")
}

#' Generate traits with most hits table
#' @param snps_df Data frame of significant SNPs
#' @param top_n Number of traits to show
#' @return Character string with markdown
generate_traits_table <- function(snps_df, top_n = 10) {
  if (is.null(snps_df) || nrow(snps_df) == 0 || !"trait" %in% colnames(snps_df)) {
    return("")
  }

  # Count SNPs per trait
  trait_counts <- snps_df %>%
    group_by(trait) %>%
    summarise(
      total = n(),
      .groups = "drop"
    ) %>%
    arrange(desc(total)) %>%
    head(top_n)

  # Get per-model counts if model column exists
  if ("model" %in% colnames(snps_df)) {
    model_counts <- snps_df %>%
      group_by(trait, model) %>%
      summarise(n = n(), .groups = "drop") %>%
      tidyr::pivot_wider(names_from = model, values_from = n, values_fill = 0)

    trait_counts <- trait_counts %>%
      left_join(model_counts, by = "trait")
  }

  # Build table
  models <- setdiff(colnames(trait_counts), c("trait", "total"))

  header <- paste0("| Rank | Trait | Total SNPs |",
                   paste(sapply(models, function(m) sprintf(" %s |", m)), collapse = ""))

  sep <- paste0("|------|-------|------------|",
                paste(rep("-----|", length(models)), collapse = ""))

  lines <- c(
    "### Traits with Most Significant Hits",
    "",
    header,
    sep
  )

  for (i in seq_len(nrow(trait_counts))) {
    row <- trait_counts[i, ]
    row_str <- sprintf("| %d | %s | %s |",
                       i,
                       truncate_string(as.character(row$trait), 35),
                       format_number(row$total))
    for (m in models) {
      row_str <- paste0(row_str, sprintf(" %s |", format_number(row[[m]])))
    }
    lines <- c(lines, row_str)
  }

  lines <- c(lines, "",
             sprintf("*Showing top %d traits by significant SNP count.*", min(top_n, nrow(trait_counts))),
             "")

  paste(lines, collapse = "\n")
}

#' Generate model statistics section
#' @param stats Summary statistics list with snps_by_model
#' @return Character string with markdown
generate_model_statistics <- function(stats) {
  if (is.null(stats$snps_by_model)) {
    return("")
  }

  snps_by_model <- stats$snps_by_model
  total <- stats$total_significant_snps

  # Get model names (exclude metadata fields)
  model_names <- setdiff(names(snps_by_model), c("both_models", "overlap_snps"))

  lines <- c(
    "## Model Statistics",
    "",
    "| Model | SNPs Found | % of Total |",
    "|-------|------------|------------|"
  )

  for (model in model_names) {
    count <- snps_by_model[[model]]
    pct <- if (total > 0) sprintf("%.1f%%", 100 * count / total) else "N/A"
    lines <- c(lines, sprintf("| %s | %s | %s |", model, format_number(count), pct))
  }

  # Add overlap info
  if (!is.null(snps_by_model$both_models) && snps_by_model$both_models > 0) {
    overlap <- snps_by_model$both_models
    overlap_pct <- if (total > 0) sprintf("%.1f%%", 100 * overlap / total) else "N/A"
    lines <- c(lines, "",
               "### Cross-Model Validation",
               "",
               sprintf("- **SNPs found by multiple models:** %s (%s of total)",
                       format_number(overlap), overlap_pct),
               "- **Model agreement indicates high-confidence hits**",
               "")
  }

  lines <- c(lines, "")
  paste(lines, collapse = "\n")
}

#' Generate chromosome distribution section
#' @param snps_df Data frame of significant SNPs
#' @return Character string with markdown
generate_chromosome_distribution <- function(snps_df) {
  if (is.null(snps_df) || nrow(snps_df) == 0 || !"Chr" %in% colnames(snps_df)) {
    return("")
  }

  total <- nrow(snps_df)

  chr_counts <- snps_df %>%
    group_by(Chr) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(desc(count))

  lines <- c(
    "## Chromosome Distribution",
    "",
    "| Chromosome | SNP Count | % of Total |",
    "|------------|-----------|------------|"
  )

  for (i in seq_len(nrow(chr_counts))) {
    row <- chr_counts[i, ]
    pct <- sprintf("%.1f%%", 100 * row$count / total)
    lines <- c(lines, sprintf("| %s | %s | %s |", row$Chr, format_number(row$count), pct))
  }

  lines <- c(lines, "")
  paste(lines, collapse = "\n")
}

#' Generate quality metrics section
#' @param stats Summary statistics list
#' @param summary_table Summary data frame
#' @return Character string with markdown
generate_quality_metrics <- function(stats, summary_table) {
  lines <- c(
    "## Quality Metrics",
    "",
    "### Completion Status",
    sprintf("- **Traits Attempted:** %s", format_number(stats$total_traits_attempted)),
    sprintf("- **Traits Completed:** %s (%.0f%%)",
            format_number(stats$successful_traits),
            if (stats$total_traits_attempted > 0) 100 * stats$successful_traits / stats$total_traits_attempted else 0),
    sprintf("- **Traits Failed:** %s", format_number(stats$failed_traits)),
    ""
  )

  # Runtime stats
  if (!is.null(stats$average_duration_minutes)) {
    lines <- c(lines,
               "### Runtime Distribution",
               sprintf("- **Average:** %s", format_duration(stats$average_duration_minutes)),
               sprintf("- **Total Compute Time:** %s", format_duration(stats$total_duration_hours, "hours")),
               "")
  }

  # Sample coverage from summary table
  if (nrow(summary_table) > 0 && "n_samples" %in% colnames(summary_table)) {
    lines <- c(lines,
               "### Sample Coverage",
               sprintf("- **Total Accessions:** %s", format_number(summary_table$n_samples[1])),
               "")
  }

  paste(lines, collapse = "\n")
}

#' Generate reproducibility section
#' @param stats Summary statistics list
#' @param metadata Metadata from first trait (optional)
#' @return Character string with markdown
generate_reproducibility_section <- function(stats, metadata = NULL) {
  lines <- c(
    "## Reproducibility",
    "",
    "| Field | Value |",
    "|-------|-------|"
  )

  # Show workflow information based on multi-workflow status
 if (!is.null(stats$is_multi_workflow) && stats$is_multi_workflow) {
    n_workflows <- length(stats$workflow_stats)
    lines <- c(lines, sprintf("| Aggregation Workflow | `%s` |", stats$batch_id))
    lines <- c(lines, sprintf("| Source Workflows | %d (see below) |", n_workflows))
  } else {
    lines <- c(lines, sprintf("| Workflow ID | `%s` |", stats$batch_id))
    # Add workflow UID if available (single workflow case)
    if (!is.null(stats$provenance$workflow_uid)) {
      lines <- c(lines, sprintf("| Workflow UID | `%s` |", stats$provenance$workflow_uid))
    }
  }

  lines <- c(lines, sprintf("| Collection Time | %s |", stats$collection_time))

  # Add R/GAPIT version from metadata
  if (!is.null(metadata) && !is.null(metadata$execution$r_version)) {
    lines <- c(lines, sprintf("| R Version | %s |", metadata$execution$r_version))
  } else {
    lines <- c(lines, "| R Version | N/A |")
  }

  if (!is.null(metadata) && !is.null(metadata$execution$gapit_version)) {
    lines <- c(lines, sprintf("| GAPIT Version | %s |", metadata$execution$gapit_version))
  } else {
    lines <- c(lines, "| GAPIT Version | N/A |")
  }

  # Add source workflows table if multi-workflow
  if (!is.null(stats$is_multi_workflow) && stats$is_multi_workflow && !is.null(stats$workflow_stats)) {
    lines <- c(lines, "",
               "### Source Workflows",
               "",
               format_workflow_stats_table(stats$workflow_stats))
  }

  # Add output files reference
  lines <- c(lines, "",
             "### Output Files",
             "| File | Description |",
             "|------|-------------|",
             "| `summary_stats.json` | Machine-readable statistics and provenance |",
             "| `all_traits_significant_snps.csv` | All significant SNPs with full details |",
             "| `summary_table.csv` | Per-trait summary |",
             "")

  paste(lines, collapse = "\n")
}

#' Generate complete markdown summary report
#' @param output_dir Directory to write report
#' @param stats Summary statistics list
#' @param summary_table Summary data frame
#' @param snps_df Data frame of significant SNPs
#' @param metadata Metadata from first trait (optional)
#' @param contact Contact name for report footer (optional)
#' @return Path to generated markdown file
generate_markdown_summary <- function(output_dir, stats, summary_table, snps_df,
                                       metadata = NULL, contact = NULL) {
  # Find top SNP
  top_snp <- if (!is.null(snps_df) && nrow(snps_df) > 0) {
    snps_df[which.min(snps_df$P.value), , drop = FALSE]
  } else {
    NULL
  }

  # Find top trait
  top_trait <- if (!is.null(snps_df) && nrow(snps_df) > 0 && "trait" %in% colnames(snps_df)) {
    trait_counts <- table(snps_df$trait)
    top_name <- names(trait_counts)[which.max(trait_counts)]
    list(name = top_name, count = max(trait_counts))
  } else {
    NULL
  }

  # Build report sections
  sections <- c(
    "# GWAS Pipeline Summary Report",
    "",
    sprintf("**Generated:** %s", stats$collection_time),
    "",
    "---",
    "",
    generate_executive_summary(stats, top_snp, top_trait),
    "---",
    "",
    generate_configuration_section(metadata, summary_table),
    "---",
    "",
    "## Results Overview",
    "",
    generate_top_snps_table(snps_df, top_n = 20),
    "---",
    "",
    generate_traits_table(snps_df, top_n = 10),
    "---",
    "",
    generate_model_statistics(stats),
    "---",
    "",
    generate_chromosome_distribution(snps_df),
    "---",
    "",
    generate_quality_metrics(stats, summary_table),
    "---",
    "",
    generate_reproducibility_section(stats, metadata),
    "---",
    "",
    "*Report generated by collect_results.R*"
  )

  if (!is.null(contact)) {
    sections <- c(sections, sprintf("*Contact: %s*", contact))
  }

  # Write to file
  md_file <- file.path(output_dir, "pipeline_summary.md")
  writeLines(paste(sections, collapse = "\n"), md_file)

  cat("Pipeline summary saved:", md_file, "\n")

  return(md_file)
}

# ------------------------------------------------------------------------------
# Deduplication and trait completeness
# Note: select_best_trait_dirs, check_trait_completeness, and read_filter_file
#       are provided by aggregation_utils.R (sourced above)
# ------------------------------------------------------------------------------

# ==============================================================================
# Find all trait result directories (with deduplication)
# ==============================================================================
cat("Scanning for trait results...\n")
all_trait_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = TRUE)
all_trait_dirs <- all_trait_dirs[grepl("^trait_\\d+", basename(all_trait_dirs))]

cat("Found", length(all_trait_dirs), "trait result directories\n")

if (length(all_trait_dirs) == 0) {
  cat("No trait results found. Exiting.\n")
  quit(save = "no", status = 0)
}

# Deduplicate: select best directory per trait index
trait_dirs <- select_best_trait_dirs(all_trait_dirs, expected_models)
cat("After deduplication:", length(trait_dirs), "unique traits\n\n")

# ==============================================================================
# Collect metadata from all traits (with provenance tracking)
# ==============================================================================
cat("Collecting metadata...\n")

metadata_list <- list()
success_count <- 0
failed_count <- 0
traits_with_metadata <- 0
traits_missing_metadata <- 0
traits_with_provenance <- 0

# Track unique workflow UIDs for lineage
workflow_uids <- character(0)

# Collect per-workflow statistics using the utility function
workflow_stats <- collect_workflow_stats(trait_dirs)
multi_workflow <- is_multi_workflow(workflow_stats)

for (dir in trait_dirs) {
  metadata_file <- file.path(dir, "metadata.json")

  if (file.exists(metadata_file)) {
    traits_with_metadata <- traits_with_metadata + 1
    meta <- fromJSON(metadata_file)

    # Track provenance info
    if (!is.null(meta$argo) && !is.null(meta$argo$workflow_uid)) {
      traits_with_provenance <- traits_with_provenance + 1
      if (!(meta$argo$workflow_uid %in% workflow_uids)) {
        workflow_uids <- c(workflow_uids, meta$argo$workflow_uid)
      }
    }

    if (!is.null(meta$execution$status) && meta$execution$status == "success") {
      metadata_list[[length(metadata_list) + 1]] <- meta
      success_count <- success_count + 1
    } else {
      failed_count <- failed_count + 1
    }
  } else {
    traits_missing_metadata <- traits_missing_metadata + 1
  }
}

cat("  - Successful:", success_count, "\n")
cat("  - Failed:", failed_count, "\n")
cat("  - With metadata:", traits_with_metadata, "\n")
cat("  - With provenance:", traits_with_provenance, "\n")
if (length(workflow_uids) > 0) {
  cat("  - Unique workflow UIDs:", length(workflow_uids), "\n")
}
if (multi_workflow) {
  cat("\n  Note: Aggregating results from", length(workflow_uids), "source workflows\n")
}
cat("\n")

# ==============================================================================
# Create summary dataframe
# ==============================================================================
cat("Creating summary table...\n")

summary_rows <- lapply(metadata_list, function(meta) {
  data.frame(
    trait_index = if (is.null(meta$trait$column_index)) NA else meta$trait$column_index,
    trait_name = if (is.null(meta$trait$name)) "unknown" else meta$trait$name,
    n_samples = if (is.null(meta$trait$n_total)) NA else meta$trait$n_total,
    n_valid = if (is.null(meta$trait$n_valid)) NA else meta$trait$n_valid,
    n_snps = if (is.null(meta$genotype$n_snps)) NA else meta$genotype$n_snps,
    duration_minutes = if (is.null(meta$execution$duration_minutes)) NA else meta$execution$duration_minutes,
    status = if (is.null(meta$execution$status)) "unknown" else meta$execution$status,
    stringsAsFactors = FALSE
  )
})
summary_df <- do.call(rbind, summary_rows)

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
# Check trait completeness (Filter files present)
# ==============================================================================
cat("Checking trait completeness...\n")
incomplete_traits <- check_trait_completeness(trait_dirs)

if (length(incomplete_traits) > 0) {
  cat("\nERROR:", length(incomplete_traits), "traits are incomplete (missing Filter file)\n")
  cat("Incomplete traits:\n")
  for (dir in incomplete_traits) {
    cat("  -", basename(dir), "\n")
  }
  cat("\nRun retry-argo-traits.sh --output-dir", output_dir, "first,\n")
  cat("or use --allow-incomplete to skip incomplete traits.\n\n")

  if (!allow_incomplete) {
    quit(save = "no", status = 1)
  }

  cat("--allow-incomplete flag set: skipping incomplete traits\n\n")
  # Filter out incomplete traits
  trait_dirs <- setdiff(trait_dirs, incomplete_traits)
  cat("Proceeding with", length(trait_dirs), "complete traits\n\n")
} else {
  cat("  - All", length(trait_dirs), "traits have Filter files\n\n")
}

# ==============================================================================
# Collect significant SNPs using Filter files
# ==============================================================================
cat("Collecting significant SNPs...\n")
cat("  - Reading Filter files (fast mode)\n")

# Collect dataframes in a list, then combine with bind_rows
snps_list <- list()
skipped_count <- 0

for (dir in trait_dirs) {
  trait_snps <- read_filter_file(dir, threshold)

  if (is.null(trait_snps)) {
    # Should not happen after completeness check, but handle gracefully
    cat("  WARNING: Skipping", basename(dir), "(missing Filter file)\n")
    skipped_count <- skipped_count + 1
    next
  }

  if (nrow(trait_snps) > 0) {
    snps_list[[length(snps_list) + 1]] <- trait_snps
  }
}

# Use bind_rows for robust combining (handles column differences gracefully)
all_snps <- if (length(snps_list) > 0) bind_rows(snps_list) else data.frame()

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

# Save aggregated significant SNPs (always create file, even if empty, for --markdown-only)
sig_snps_file <- file.path(output_dir, "aggregated_results", "all_traits_significant_snps.csv")
write.csv(all_snps, sig_snps_file, row.names = FALSE)
cat("Significant SNPs saved:", sig_snps_file, "(", nrow(all_snps), "rows )\n")

cat("\n")

# ==============================================================================
# Generate summary statistics (with provenance)
# ==============================================================================
cat("Generating summary statistics...\n")

stats <- list(
  batch_id = batch_id,
  collection_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  total_directories_found = length(all_trait_dirs),
  unique_traits = length(trait_dirs),
  total_traits_attempted = length(trait_dirs) + length(incomplete_traits),
  successful_traits = success_count,
  failed_traits = failed_count,
  total_significant_snps = nrow(all_snps),
  average_duration_minutes = mean(summary_df$duration_minutes, na.rm = TRUE),
  total_duration_hours = sum(summary_df$duration_minutes, na.rm = TRUE) / 60,
  expected_models = expected_models,
  # Configuration section for reproducibility (per spec)
  configuration = list(
    expected_models = expected_models,
    models_source = models_source,
    significance_threshold = threshold,
    allow_incomplete = allow_incomplete
  ),
  # Provenance section for traceability
  provenance = list(
    workflow_name = get_env_or_null("WORKFLOW_NAME"),
    workflow_uid = get_env_or_null("WORKFLOW_UID"),
    aggregation_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
    aggregation_hostname = Sys.info()["nodename"],
    aggregation_pod = get_env_or_null("POD_NAME"),
    aggregation_node = get_env_or_null("NODE_NAME"),
    container_image = get_env_or_null("CONTAINER_IMAGE"),
    source_workflow_uids = if (length(workflow_uids) > 0) workflow_uids else NULL
  ),
  # Multi-workflow tracking
  is_multi_workflow = multi_workflow,
  workflow_stats = if (length(workflow_stats) > 0) workflow_stats else NULL,
  # Metadata coverage tracking
  metadata_coverage = list(
    traits_with_metadata = traits_with_metadata,
    traits_missing_metadata = traits_missing_metadata,
    traits_with_provenance = traits_with_provenance
  )
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
# Generate markdown summary report
# ==============================================================================
if (!no_markdown) {
  cat("Generating markdown summary report...\n")

  # Get first metadata for configuration details
  first_metadata <- if (length(metadata_list) > 0) metadata_list[[1]] else NULL

  generate_markdown_summary(
    output_dir = file.path(output_dir, "aggregated_results"),
    stats = stats,
    summary_table = summary_df,
    snps_df = all_snps,
    metadata = first_metadata
  )
} else {
  cat("Skipping markdown summary generation (--no-markdown)\n")
}

cat("\n")

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
cat("  - Unique traits:", length(trait_dirs) + length(incomplete_traits), "\n")
cat("  - Complete:", length(trait_dirs), "\n")
if (length(incomplete_traits) > 0) {
  cat("  - Incomplete (skipped):", length(incomplete_traits), "\n")
}
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
