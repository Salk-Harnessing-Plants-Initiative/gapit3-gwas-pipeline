# ==============================================================================
# GAPIT3 Aggregation Utilities
# ==============================================================================
# Reusable pure functions for GWAS results aggregation.
# This module can be sourced independently without triggering script execution.
#
# Design principles:
# - All functions are pure (no global state, deterministic outputs)
# - All inputs are explicit parameters
# - Functions can be tested in isolation
# ==============================================================================

# Source constants from the same directory
# Uses robust path resolution that works from any working directory
.get_lib_dir <- function() {
  # Try multiple methods to find the lib directory


  # Method 1: If sourced directly, use the path of this file
  if (sys.nframe() > 0) {
    for (i in seq_len(sys.nframe())) {
      frame <- sys.frame(i)
      if (!is.null(frame$ofile)) {
        return(dirname(frame$ofile))
      }
    }
  }

  # Method 2: Check common relative paths
  candidates <- c(
    "scripts/lib",
    "../lib",
    "lib",
    file.path(getwd(), "scripts/lib")
  )

  for (path in candidates) {
    if (file.exists(file.path(path, "constants.R"))) {
      return(normalizePath(path))
    }
  }

  # Method 3: Search from current directory upward for project root
  current <- getwd()
  while (current != dirname(current)) {
    test_path <- file.path(current, "scripts", "lib")
    if (file.exists(file.path(test_path, "constants.R"))) {
      return(normalizePath(test_path))
    }
    current <- dirname(current)
  }

  stop("Could not locate constants.R - ensure you're running from the project directory")
}

# Only source constants if not already loaded
if (!exists("KNOWN_GAPIT_MODELS")) {
  source(file.path(.get_lib_dir(), "constants.R"))
}

# ==============================================================================
# Formatting Helper Functions
# ==============================================================================

#' Format p-value for display (vector-safe)
#' @param pval Numeric p-value (scalar or vector)
#' @return Character string(s) in scientific notation
format_pvalue <- function(pval) {
  if (length(pval) > 1) {
    return(vapply(pval, format_pvalue, character(1)))
  }
  if (is.null(pval) || is.na(pval)) return("NA")
  sprintf("%.2e", pval)
}

#' Format number with thousand separators (vector-safe)
#' @param n Numeric value (scalar or vector)
#' @return Character string(s) with commas
format_number <- function(n) {
  if (length(n) > 1) {
    return(vapply(n, format_number, character(1)))
  }
  if (is.null(n) || is.na(n)) return("NA")
  format(n, big.mark = ",", scientific = FALSE)
}

#' Format duration for display
#' @param minutes Numeric duration in minutes
#' @param unit Output unit ("minutes" or "hours")
#' @return Character string with unit
format_duration <- function(minutes, unit = "minutes") {
  if (is.null(minutes) || length(minutes) == 0 || is.na(minutes) || is.nan(minutes)) {
    return("N/A")
  }
  if (unit == "hours") {
    sprintf("%.1f hours", minutes)
  } else {
    sprintf("%.1f minutes", minutes)
  }
}

#' Truncate string with ellipsis
#' @param s Character string
#' @param max_length Maximum length
#' @return Truncated string
truncate_string <- function(s, max_length = 40) {
  if (nchar(s) <= max_length) return(s)
  paste0(substr(s, 1, max_length - 3), "...")
}

# ==============================================================================
# Configuration Section Generation
# ==============================================================================

#' Generate configuration section for markdown summary
#'
#' Creates a formatted markdown section showing GAPIT parameters,
#' filtering settings, and data information.
#'
#' @param metadata Parsed metadata list (from jsonlite::fromJSON)
#' @param summary_table Data frame with n_snps, n_samples columns
#' @return Character string with markdown content
generate_configuration_section <- function(metadata, summary_table) {
  # Extract GAPIT parameters (supports both v3.0.0 and v2.0.0 schemas)
  models <- get_gapit_param(metadata, "model", "models", NULL)
  if (!is.null(models)) {
    models <- paste(models, collapse = ", ")
  } else {
    models <- "N/A"
  }

  pca_total <- get_gapit_param(metadata, "PCA.total", "pca_components", "N/A")
  snp_maf <- get_gapit_param(metadata, "SNP.MAF", "maf_filter", "N/A")
  snp_fdr <- get_gapit_param(metadata, "SNP.FDR", "snp_fdr", NULL)
  snp_fdr <- if (!is.null(snp_fdr)) snp_fdr else "N/A (disabled)"

  # New GAPIT parameters (v3.0.0 only)
  kinship_algo <- get_gapit_param(metadata, "kinship.algorithm", NULL, NULL)
  snp_effect <- get_gapit_param(metadata, "SNP.effect", NULL, NULL)
  snp_impute <- get_gapit_param(metadata, "SNP.impute", NULL, NULL)

  n_snps <- if (!is.null(metadata$genotype$n_snps)) {
    format_number(metadata$genotype$n_snps)
  } else if (nrow(summary_table) > 0 && "n_snps" %in% colnames(summary_table)) {
    format_number(summary_table$n_snps[1])
  } else {
    "N/A"
  }

  n_accessions <- if (!is.null(metadata$genotype$n_accessions)) {
    format_number(metadata$genotype$n_accessions)
  } else if (nrow(summary_table) > 0 && "n_samples" %in% colnames(summary_table)) {
    format_number(summary_table$n_samples[1])
  } else {
    "N/A"
  }

  # Build configuration section with GAPIT naming
  lines <- c(
    "## Configuration",
    "",
    "### GAPIT Parameters",
    "",
    "| Parameter | Value |",
    "|-----------|-------|",
    sprintf("| model | %s |", models),
    sprintf("| PCA.total | %s |", pca_total)
  )

  # Add optional parameters if present
  if (!is.null(kinship_algo)) {
    lines <- c(lines, sprintf("| kinship.algorithm | %s |", kinship_algo))
  }
  if (!is.null(snp_effect)) {
    lines <- c(lines, sprintf("| SNP.effect | %s |", snp_effect))
  }
  if (!is.null(snp_impute)) {
    lines <- c(lines, sprintf("| SNP.impute | %s |", snp_impute))
  }

  lines <- c(lines, "")

  # Filtering section
  lines <- c(lines,
    "### Filtering",
    "",
    "| Parameter | Value |",
    "|-----------|-------|",
    sprintf("| SNP.MAF | %s |", snp_maf),
    sprintf("| SNP.FDR | %s |", snp_fdr),
    ""
  )

  # Data section
  lines <- c(lines,
    "### Data",
    "",
    "| Parameter | Value |",
    "|-----------|-------|",
    sprintf("| SNPs Tested | %s |", n_snps),
    sprintf("| Accessions | %s |", n_accessions),
    ""
  )

  # Add input files if available
  if (!is.null(metadata$inputs)) {
    geno_file <- if (!is.null(metadata$inputs$genotype_file)) metadata$inputs$genotype_file else "N/A"
    pheno_file <- if (!is.null(metadata$inputs$phenotype_file)) metadata$inputs$phenotype_file else "N/A"
    lines <- c(lines,
      "### Input Files",
      "",
      sprintf("- **Genotype:** `%s`", geno_file),
      sprintf("- **Phenotype:** `%s`", pheno_file),
      ""
    )
  }

  paste(lines, collapse = "\n")
}

# ==============================================================================
# Model Extraction and Validation Functions
# ==============================================================================

#' Extract expected models from trait metadata JSON file
#'
#' Reads a gapit_metadata.json file and extracts the model configuration.
#' Supports both v3.0.0 schema (parameters.gapit.model or parameters.model)
#' and legacy v2.0.0 schema (parameters.models).
#'
#' @param metadata_path Path to gapit_metadata.json file
#' @return Character vector of model names, or NULL if:
#'   - File does not exist
#'   - JSON is malformed
#'   - No model information found
#'
#' @examples
#' models <- extract_models_from_metadata("/path/to/trait_001/gapit_metadata.json")
#' if (!is.null(models)) {
#'   print(paste("Found models:", paste(models, collapse = ", ")))
#' }
extract_models_from_metadata <- function(metadata_path) {
  # Check file exists

if (!file.exists(metadata_path)) {
    return(NULL)
  }

  # Try to parse JSON
  tryCatch({
    metadata <- jsonlite::fromJSON(metadata_path)

    # Try v3.0.0 schema: parameters.gapit.model (nested gapit object)
    if (!is.null(metadata$parameters$gapit$model)) {
      model_str <- metadata$parameters$gapit$model
      if (is.character(model_str) && length(model_str) > 0) {
        # Handle both comma-separated string and vector
        if (length(model_str) == 1 && grepl(",", model_str)) {
          return(trimws(strsplit(model_str, ",")[[1]]))
        }
        return(model_str)
      }
    }

    # Try v3.0.0 schema: parameters.model (flat structure)
    if (!is.null(metadata$parameters$model)) {
      model_str <- metadata$parameters$model
      if (is.character(model_str) && length(model_str) > 0) {
        if (length(model_str) == 1 && grepl(",", model_str)) {
          return(trimws(strsplit(model_str, ",")[[1]]))
        }
        return(model_str)
      }
    }

    # Try legacy v2.0.0 schema: parameters.models
    if (!is.null(metadata$parameters$models)) {
      model_str <- metadata$parameters$models
      if (is.character(model_str) && length(model_str) > 0) {
        if (length(model_str) == 1 && grepl(",", model_str)) {
          return(trimws(strsplit(model_str, ",")[[1]]))
        }
        return(model_str)
      }
    }

    # No model information found
    return(NULL)

  }, error = function(e) {
    # JSON parse error or other issue
    return(NULL)
  })
}

#' Validate model names against known GAPIT models
#'
#' Checks if the provided model names are valid GAPIT models.
#' Comparison is case-insensitive for user convenience.
#'
#' @param models Character vector of model names to validate
#' @param known_models Reference list of valid models (default: KNOWN_GAPIT_MODELS)
#' @return List with:
#'   - valid: logical, TRUE if all models are valid
#'   - invalid_models: character vector of invalid model names (empty if valid)
#'   - canonical_models: character vector of models in canonical case
#'
#' @examples
#' result <- validate_model_names(c("BLINK", "farmcpu"))
#' if (result$valid) {
#'   print("All models valid")
#' } else {
#'   print(paste("Invalid:", paste(result$invalid_models, collapse = ", ")))
#' }
validate_model_names <- function(models, known_models = KNOWN_GAPIT_MODELS) {
  if (length(models) == 0) {
    return(list(
      valid = FALSE,
      invalid_models = character(0),
      canonical_models = character(0)
    ))
  }

  # Create case-insensitive lookup
  known_upper <- toupper(known_models)
  models_upper <- toupper(models)

  # Find invalid models
  invalid_mask <- !(models_upper %in% known_upper)
  invalid_models <- models[invalid_mask]

  # Map to canonical case
  canonical_models <- character(length(models))
  for (i in seq_along(models)) {
    idx <- match(models_upper[i], known_upper)
    if (!is.na(idx)) {
      canonical_models[i] <- known_models[idx]
    } else {
      canonical_models[i] <- models[i]  # Keep original if unknown
    }
  }

  return(list(
    valid = length(invalid_models) == 0,
    invalid_models = invalid_models,
    canonical_models = canonical_models
  ))
}

#' Detect models from first trait directory's metadata
#'
#' Scans the output directory for trait subdirectories and reads
#' the metadata from the first one found to extract model configuration.
#'
#' @param output_dir Directory containing trait_* subdirectories
#' @return Character vector of model names, or NULL if:
#'   - No trait directories found
#'   - No metadata file in first trait
#'   - Metadata doesn't contain model info
#'
#' @examples
#' models <- detect_models_from_first_trait("/outputs")
#' if (!is.null(models)) {
#'   print(paste("Detected:", paste(models, collapse = ", ")))
#' }
detect_models_from_first_trait <- function(output_dir) {
  # Find trait directories
  if (!dir.exists(output_dir)) {
    return(NULL)
  }

  trait_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = TRUE)
  trait_dirs <- trait_dirs[grepl("trait_\\d+", basename(trait_dirs))]

  if (length(trait_dirs) == 0) {
    return(NULL)
  }

  # Sort to get consistent "first" trait
  trait_dirs <- sort(trait_dirs)
  first_trait <- trait_dirs[1]

  # Try gapit_metadata.json first (preferred)
  metadata_path <- file.path(first_trait, "gapit_metadata.json")
  if (file.exists(metadata_path)) {
    models <- extract_models_from_metadata(metadata_path)
    if (!is.null(models)) {
      return(models)
    }
  }

  # Fall back to metadata.json (legacy)
  metadata_path <- file.path(first_trait, "metadata.json")
  if (file.exists(metadata_path)) {
    models <- extract_models_from_metadata(metadata_path)
    if (!is.null(models)) {
      return(models)
    }
  }

  return(NULL)
}

# ==============================================================================
# Parameter Extraction Functions
# ==============================================================================

#' Extract GAPIT parameter with fallback to legacy names
#'
#' Reads a parameter from metadata, supporting both v3.0.0 schema
#' (parameters.gapit.*) and legacy v2.0.0 schema (parameters.*).
#'
#' @param metadata Parsed metadata list (from jsonlite::fromJSON)
#' @param gapit_name GAPIT native parameter name (e.g., "model", "PCA.total")
#' @param legacy_name Legacy parameter name (e.g., "models", "pca_components")
#' @param default Default value if not found in either location
#' @return Parameter value or default
#'
#' @examples
#' metadata <- jsonlite::fromJSON("metadata.json")
#' models <- get_gapit_param(metadata, "model", "models", "BLINK,FarmCPU,MLM")
#' pca <- get_gapit_param(metadata, "PCA.total", "pca_components", 3)
get_gapit_param <- function(metadata, gapit_name, legacy_name, default = NULL) {
  # Handle NULL parameters gracefully
  if (is.null(metadata) || is.null(metadata$parameters)) {
    return(default)
  }

  # Try new schema first (parameters.gapit.*)
  if (!is.null(metadata$parameters$gapit) && !is.null(metadata$parameters$gapit[[gapit_name]])) {
    return(metadata$parameters$gapit[[gapit_name]])
  }

  # Try flat v3.0.0 schema (parameters.*)
  if (!is.null(gapit_name) && !is.null(metadata$parameters[[gapit_name]])) {
    return(metadata$parameters[[gapit_name]])
  }

  # Fall back to legacy schema (parameters.*)
  if (!is.null(legacy_name) && !is.null(metadata$parameters[[legacy_name]])) {
    return(metadata$parameters[[legacy_name]])
  }

  return(default)
}

# ==============================================================================
# Trait Directory Selection Functions
# ==============================================================================

#' Select best directory for each trait index (deduplication)
#'
#' When multiple directories exist for the same trait (from retries),
#' selects the one with the most complete model outputs.
#' If tied, selects the newest (by timestamp in directory name).
#'
#' @param trait_dirs Vector of trait directory paths
#' @param expected_models Vector of expected model names (e.g., c("BLINK", "FarmCPU", "MLM"))
#' @return Vector of selected trait directory paths (one per trait index)
#'
#' @examples
#' dirs <- c("/out/trait_001_20231101", "/out/trait_001_20231102", "/out/trait_002_20231101")
#' selected <- select_best_trait_dirs(dirs, c("BLINK", "FarmCPU", "MLM"))
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
      # Sort by n_models descending, then timestamp descending
      dirs_for_trait <- dirs_for_trait[order(-dirs_for_trait$n_models, -xtfrm(dirs_for_trait$timestamp)), ]
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
  selected <- dplyr::ungroup(
    dplyr::slice(
      dplyr::arrange(
        dplyr::group_by(trait_info, trait_index),
        dplyr::desc(n_models), dplyr::desc(timestamp)
      ),
      1
    )
  )

  return(selected$path)
}

# ==============================================================================
# Multi-Workflow Provenance Functions
# ==============================================================================

#' Collect per-workflow statistics from trait directories
#'
#' Scans metadata.json files in trait directories and aggregates statistics
#' by source workflow UID.
#'
#' @param trait_dirs Character vector of trait directory paths
#' @return Named list of workflow statistics, keyed by workflow UID
#'         Each entry contains: workflow_name, trait_count, total_duration_minutes
collect_workflow_stats <- function(trait_dirs) {
  workflow_stats <- list()

  for (dir in trait_dirs) {
    metadata_file <- file.path(dir, "metadata.json")

    if (!file.exists(metadata_file)) {
      # Track traits without metadata under "unknown"
      if (is.null(workflow_stats[["unknown"]])) {
        workflow_stats[["unknown"]] <- list(
          workflow_name = "unknown",
          trait_count = 0,
          total_duration_minutes = 0
        )
      }
      workflow_stats[["unknown"]]$trait_count <- workflow_stats[["unknown"]]$trait_count + 1
      next
    }

    tryCatch({
      meta <- jsonlite::fromJSON(metadata_file)

      # Extract workflow UID (required for tracking)
      workflow_uid <- NULL
      workflow_name <- "unknown"
      duration <- 0

      if (!is.null(meta$argo) && !is.null(meta$argo$workflow_uid)) {
        workflow_uid <- meta$argo$workflow_uid
        workflow_name <- meta$argo$workflow_name %||% "unknown"
      }

      if (!is.null(meta$execution) && !is.null(meta$execution$duration_minutes)) {
        duration <- as.numeric(meta$execution$duration_minutes)
      }

      # Use "unknown" if no workflow UID

      if (is.null(workflow_uid)) {
        workflow_uid <- "unknown"
        workflow_name <- "unknown"
      }

      # Initialize or update workflow stats
      if (is.null(workflow_stats[[workflow_uid]])) {
        workflow_stats[[workflow_uid]] <- list(
          workflow_name = workflow_name,
          trait_count = 0,
          total_duration_minutes = 0
        )
      }

      workflow_stats[[workflow_uid]]$trait_count <- workflow_stats[[workflow_uid]]$trait_count + 1
      workflow_stats[[workflow_uid]]$total_duration_minutes <-
        workflow_stats[[workflow_uid]]$total_duration_minutes + duration

    }, error = function(e) {
      # On error reading metadata, count as unknown
      # Use <<- to assign in the enclosing collect_workflow_stats scope
      if (is.null(workflow_stats[["unknown"]])) {
        workflow_stats[["unknown"]] <<- list(
          workflow_name = "unknown",
          trait_count = 0,
          total_duration_minutes = 0
        )
      }
      workflow_stats[["unknown"]]$trait_count <<- workflow_stats[["unknown"]]$trait_count + 1
    })
  }

  return(workflow_stats)
}

#' Check if results come from multiple workflows
#'
#' @param workflow_stats Named list from collect_workflow_stats()
#' @return TRUE if more than one workflow contributed results
is_multi_workflow <- function(workflow_stats) {
  # Filter out "unknown" when checking for multi-workflow
  known_workflows <- names(workflow_stats)[names(workflow_stats) != "unknown"]
  return(length(known_workflows) > 1)
}

#' Format workflow stats for markdown report
#'
#' @param workflow_stats Named list from collect_workflow_stats()
#' @return Character string with markdown table
format_workflow_stats_table <- function(workflow_stats) {
  if (length(workflow_stats) == 0) {
    return("No workflow statistics available.\n")
  }

  lines <- c(
    "| Workflow Name | UID | Traits | Compute Hours |",
    "|---------------|-----|--------|---------------|"
  )

  for (uid in names(workflow_stats)) {
    stats <- workflow_stats[[uid]]
    hours <- round(stats$total_duration_minutes / 60, 1)
    # Truncate UID for display
    uid_display <- if (nchar(uid) > 20) paste0(substr(uid, 1, 17), "...") else uid
    lines <- c(lines, sprintf("| %s | %s | %d | %.1f |",
                               stats$workflow_name, uid_display,
                               stats$trait_count, hours))
  }

  return(paste(lines, collapse = "\n"))
}

# ==============================================================================
# Trait Completeness and Filter File Functions
# ==============================================================================

#' Check which trait directories are missing Filter files
#'
#' Scans trait directories for the presence of
#' GAPIT.Association.Filter_GWAS_results.csv, which is the definitive
#' completion signal (GAPIT only creates it after all models finish).
#'
#' @param trait_dirs Character vector of trait directory paths
#' @return Character vector of paths to incomplete trait directories
check_trait_completeness <- function(trait_dirs) {
  incomplete <- character(0)
  for (dir in trait_dirs) {
    filter_file <- file.path(dir, "GAPIT.Association.Filter_GWAS_results.csv")
    if (!file.exists(filter_file)) {
      incomplete <- c(incomplete, dir)
    }
  }
  return(incomplete)
}

#' Read GAPIT Filter file and parse model information
#'
#' Reads GAPIT.Association.Filter_GWAS_results.csv which contains only
#' significant SNPs with model information in the traits column.
#' Format: "<MODEL>.<TraitName>" (e.g., "BLINK.root_length")
#'
#' Handles known GAPIT quirks:
#' - BLINK model has swapped columns (MAF contains sample count instead of frequency)
#' - Trait names may have (NYC) or (Kansas) suffix indicating analysis type
#'
#' Returns NULL if Filter file is missing (trait incomplete).
#' Returns empty data.frame if Filter file exists but has no significant SNPs.
#'
#' @param trait_dir Path to trait result directory
#' @param threshold Significance threshold (unused, kept for API compatibility)
#' @return data.frame with columns including model, trait, analysis_type, and trait_dir, or NULL if incomplete
read_filter_file <- function(trait_dir, threshold = 5e-8) {
  filter_file <- file.path(trait_dir, "GAPIT.Association.Filter_GWAS_results.csv")

  # Missing Filter file = incomplete trait (fail-fast)
  if (!file.exists(filter_file)) {
    return(NULL)
  }

  tryCatch({
    # Read Filter file (contains only significant SNPs)
    filter_data <- data.table::fread(filter_file, data.table = FALSE)

    # Drop V1 column (row index) if present - not needed for analysis
    # Critical fix: V1 has mixed types across files (numeric: 1216644 vs X-prefixed: X2625218)
    # which causes bind_rows() type mismatch errors when combining results
    if ("V1" %in% colnames(filter_data)) {
      filter_data <- filter_data[, colnames(filter_data) != "V1", drop = FALSE]
    }

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
    # Format: "<MODEL>.<TraitName>" or "<MODEL>.<TraitName>(NYC|Kansas)"
    # Handle compound models (FarmCPU.LM, Blink.LM) before simple split
    filter_data$model <- ifelse(
      grepl("^FarmCPU\\.LM\\.", filter_data$traits), "FarmCPU.LM",
      ifelse(grepl("^Blink\\.LM\\.", filter_data$traits), "Blink.LM",
             sub("\\..*", "", filter_data$traits))
    )

    # Extract raw trait (before stripping analysis_type suffix)
    raw_trait <- ifelse(
      grepl("^FarmCPU\\.LM\\.", filter_data$traits),
      sub("^FarmCPU\\.LM\\.", "", filter_data$traits),
      ifelse(grepl("^Blink\\.LM\\.", filter_data$traits),
             sub("^Blink\\.LM\\.", "", filter_data$traits),
             sub("^[^.]+\\.", "", filter_data$traits))
    )

    # Parse analysis_type from trait suffix (NYC, Kansas, or standard)
    filter_data$analysis_type <- ifelse(
      grepl("\\(NYC\\)$", raw_trait), "NYC",
      ifelse(grepl("\\(Kansas\\)$", raw_trait), "Kansas", "standard")
    )

    # Strip analysis_type suffix from trait name
    filter_data$trait <- gsub("\\(NYC\\)$|\\(Kansas\\)$", "", raw_trait)

    # Add trait_dir for provenance tracking
    filter_data$trait_dir <- basename(trait_dir)

    # -------------------------------------------------------------------------
    # GAPIT BLINK column swap fix
    # -------------------------------------------------------------------------
    # GAPIT's BLINK model outputs columns in wrong order:
    # Header claims: P.value, MAF, nobs, Effect, H&B.P.Value
    # Actual data:   P.value, nobs, Effect, MAF, H&B.P.Value
    #
    # In the Filter file, only MAF column is present (no nobs, Effect, H&B).
    # When MAF > 1, it's actually the sample count (nobs), not a frequency.
    # Since we can't recover the true MAF from Filter file, set to NA.
    # -------------------------------------------------------------------------
    if ("MAF" %in% colnames(filter_data)) {
      # Detect invalid MAF values (frequency must be in [0, 0.5] for minor allele)
      invalid_maf <- !is.na(filter_data$MAF) & filter_data$MAF > 1

      if (any(invalid_maf)) {
        n_invalid <- sum(invalid_maf)
        affected_models <- unique(filter_data$model[invalid_maf])
        warning(sprintf(
          "Detected BLINK column order issue in %s: %d rows have MAF > 1 (models: %s). Setting to NA.",
          basename(trait_dir), n_invalid, paste(affected_models, collapse = ", ")
        ))
        filter_data$MAF[invalid_maf] <- NA
      }
    }

    # Validate model names using KNOWN_GAPIT_MODELS from constants (warn if unexpected, but continue)
    unexpected <- unique(filter_data$model[!(filter_data$model %in% KNOWN_GAPIT_MODELS)])
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
    return(NULL)
  })
}
