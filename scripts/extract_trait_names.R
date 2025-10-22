#!/usr/bin/env Rscript
# ==============================================================================
# Extract Trait Names from Phenotype File
# ==============================================================================
# Creates a manifest of all traits for parallel processing
# Output: config/traits_manifest.yaml
# ==============================================================================

suppressPackageStartupMessages({
  library(yaml)
})

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
phenotype_file <- ifelse(length(args) >= 1, args[1], "/data/phenotype/iron_traits_edited.txt")
output_file <- ifelse(length(args) >= 2, args[2], "/config/traits_manifest.yaml")

cat("Extracting trait names from:", phenotype_file, "\n")

# Read phenotype data
data <- read.table(phenotype_file, header = TRUE, stringsAsFactors = FALSE)

# Extract trait names (all columns except 'Taxa')
trait_columns <- colnames(data)[colnames(data) != "Taxa"]
num_traits <- length(trait_columns)

cat("Found", num_traits, "traits\n")

# Create manifest structure
manifest <- list(
  metadata = list(
    source_file = basename(phenotype_file),
    extraction_date = Sys.time(),
    total_traits = num_traits,
    total_accessions = nrow(data)
  ),
  traits = list()
)

# Add each trait with metadata
for (i in seq_along(trait_columns)) {
  trait_name <- trait_columns[i]
  trait_index <- which(colnames(data) == trait_name)

  # Calculate basic statistics
  trait_values <- data[[trait_name]]
  n_valid <- sum(!is.na(trait_values))

  manifest$traits[[i]] <- list(
    index = trait_index,
    name = trait_name,
    column_position = trait_index,
    n_samples = n_valid,
    missing_rate = round((nrow(data) - n_valid) / nrow(data), 4)
  )
}

# Write manifest
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
write_yaml(manifest, output_file)

cat("Trait manifest written to:", output_file, "\n")
cat("\nFirst 5 traits:\n")
for (i in 1:min(5, num_traits)) {
  cat(sprintf("  %3d. %s (column %d)\n",
              i,
              manifest$traits[[i]]$name,
              manifest$traits[[i]]$column_position))
}
