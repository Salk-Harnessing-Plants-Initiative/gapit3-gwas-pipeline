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

#' Format p-value for display
#' @param pval Numeric p-value
#' @return Character string in scientific notation
format_pvalue <- function(pval) {
  if (is.na(pval)) return("NA")
  sprintf("%.2e", pval)
}

#' Format number with thousand separators
#' @param n Numeric value
#' @return Character string with commas
format_number <- function(n) {
  if (is.na(n)) return("NA")
  format(n, big.mark = ",", scientific = FALSE)
}

#' Format duration for display
#' @param minutes Numeric duration in minutes
#' @param unit Output unit ("minutes" or "hours")
#' @return Character string with unit
format_duration <- function(minutes, unit = "minutes") {
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
  # Try new schema first (parameters.gapit.*)
  if (!is.null(metadata$parameters$gapit[[gapit_name]])) {
    return(metadata$parameters$gapit[[gapit_name]])
  }

  # Try flat v3.0.0 schema (parameters.*)
  if (!is.null(metadata$parameters[[gapit_name]])) {
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
  selected <- trait_info %>%
    dplyr::group_by(trait_index) %>%
    dplyr::arrange(dplyr::desc(n_models), dplyr::desc(timestamp)) %>%
    dplyr::slice(1) %>%
    dplyr::ungroup()

  return(selected$path)
}
