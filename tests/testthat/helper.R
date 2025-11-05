# ==============================================================================
# Test Helper Utilities
# ==============================================================================
# Shared utilities and fixtures for tests
# ==============================================================================

# Get path to test fixtures
get_fixture_path <- function(filename) {
  # Check if we're already in the root directory (has tests/ subdirectory)
  if (dir.exists("tests/fixtures")) {
    return(file.path("tests", "fixtures", filename))
  }
  # If we're in tests/ directory, go up one level
  if (dir.exists("../tests/fixtures")) {
    return(file.path("../tests", "fixtures", filename))
  }
  # If we're in tests/testthat/, go up two levels
  if (dir.exists("../../tests/fixtures")) {
    return(file.path("../../tests", "fixtures", filename))
  }
  # Fallback: try to find the project root by looking for .git
  root <- getwd()
  while (!dir.exists(file.path(root, ".git")) && root != dirname(root)) {
    root <- dirname(root)
  }
  return(file.path(root, "tests", "fixtures", filename))
}

# Create temporary test output directory
create_temp_output_dir <- function() {
  temp_dir <- tempfile(pattern = "gapit_test_")
  dir.create(temp_dir, recursive = TRUE)
  return(temp_dir)
}

# Clean up test output directory
cleanup_test_dir <- function(dir_path) {
  if (dir.exists(dir_path)) {
    unlink(dir_path, recursive = TRUE)
  }
}

# Check if file has expected number of lines
file_line_count <- function(filepath) {
  length(readLines(filepath, warn = FALSE))
}

# Parse YAML file safely
safe_yaml_parse <- function(filepath) {
  if (!file.exists(filepath)) {
    stop(paste("File not found:", filepath))
  }
  yaml::yaml.load_file(filepath)
}

# Create minimal mock genotype data in HapMap format
create_mock_genotype <- function(output_path, n_snps = 10, n_samples = 5) {
  # HapMap header
  header <- c("rs#", "alleles", "chrom", "pos", "strand", "assembly#",
              "center", "protLSID", "assayLSID", "panelLSID", "QCcode",
              paste0("sample_", 1:n_samples))

  # Generate mock SNP data
  rows <- list()
  for (i in 1:n_snps) {
    snp_data <- c(
      paste0("SNP_", i),
      "A/T",
      "1",
      as.character(i * 1000),
      "+",
      "NA",
      "NA",
      "NA",
      "NA",
      "NA",
      "NA",
      sample(c("AA", "AT", "TT", "NN"), n_samples, replace = TRUE)
    )
    rows[[i]] <- snp_data
  }

  # Write to file
  write.table(rbind(header, do.call(rbind, rows)),
              output_path,
              sep = "\t",
              quote = FALSE,
              row.names = FALSE,
              col.names = FALSE)

  return(output_path)
}

# Create minimal mock phenotype data
create_mock_phenotype <- function(output_path, n_samples = 5, n_traits = 3) {
  sample_ids <- paste0("sample_", 1:n_samples)
  trait_data <- data.frame(
    Taxa = sample_ids,
    matrix(rnorm(n_samples * n_traits, mean = 100, sd = 10),
           nrow = n_samples,
           ncol = n_traits)
  )
  colnames(trait_data)[-1] <- paste0("trait_", 1:n_traits)

  write.table(trait_data,
              output_path,
              sep = "\t",
              quote = FALSE,
              row.names = FALSE,
              col.names = TRUE)

  return(output_path)
}

# Create mock config file
create_mock_config <- function(output_path, genotype_path = NULL, phenotype_path = NULL) {
  config <- list(
    data = list(
      genotype = if (!is.null(genotype_path)) genotype_path else "/data/genotype/test.hmp.txt",
      phenotype = if (!is.null(phenotype_path)) phenotype_path else "/data/phenotype/test.txt",
      accession_ids = "/data/metadata/ids.txt"
    ),
    gapit = list(
      models = c("BLINK", "FarmCPU"),
      pca_components = 3,
      multiple_analysis = TRUE
    ),
    output = list(
      base_dir = "/outputs",
      create_timestamp_dirs = TRUE,
      save_intermediate = TRUE
    ),
    resources = list(
      threads = 4
    ),
    logging = list(
      level = "INFO",
      save_logs = TRUE,
      log_dir = "/logs"
    ),
    metadata = list(
      enable_provenance = TRUE,
      save_execution_metadata = TRUE,
      compute_checksums = TRUE
    ),
    validation = list(
      check_input_files = TRUE,
      verify_trait_index = TRUE,
      # NOTE: Test config uses 5 samples to keep fixtures small and fast
      # Production requirement is 50 samples (see openspec/project.md line 182)
      require_minimum_samples = 5
    )
  )

  yaml::write_yaml(config, output_path)
  return(output_path)
}
