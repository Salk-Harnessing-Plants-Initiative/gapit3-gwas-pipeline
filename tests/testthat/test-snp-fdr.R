# ==============================================================================
# Tests for SNP FDR Parameter Implementation
# ==============================================================================
# Tests for SNP_FDR parameter handling, metadata tracking, and report generation
# ==============================================================================

library(testthat)
library(jsonlite)
library(optparse)

# Note: helper.R is automatically sourced by testthat

# ==============================================================================
# Source helper functions from R scripts
# ==============================================================================

#' Source the get_env_or_null function from run_gwas_single_trait.R
source_gwas_helpers <- function() {
  script_path <- file.path("..", "..", "scripts", "run_gwas_single_trait.R")
  if (!file.exists(script_path)) {
    script_path <- file.path("scripts", "run_gwas_single_trait.R")
  }
  script_lines <- readLines(script_path)

  # Find get_env_or_null function
  get_env_start <- grep("^get_env_or_null <- function", script_lines)[1]
  get_env_end <- grep("^}", script_lines)
  get_env_end <- get_env_end[get_env_end > get_env_start][1]

  if (!is.na(get_env_start)) {
    get_env_code <- paste(script_lines[get_env_start:get_env_end], collapse = "\n")
    eval(parse(text = get_env_code), envir = .GlobalEnv)
  }
}

# Source the functions
source_gwas_helpers()

# ==============================================================================
# Helper: Create option parser matching run_gwas_single_trait.R
# ==============================================================================

create_snp_fdr_option_parser <- function() {
  option_list <- list(
    make_option(c("-t", "--trait-index"), type = "integer",
                default = as.integer(Sys.getenv("TRAIT_INDEX", "2")),
                help = "Trait column index"),
    make_option(c("-m", "--models"), type = "character",
                default = Sys.getenv("MODELS", "BLINK,FarmCPU"),
                help = "Comma-separated models"),
    make_option(c("--pca"), type = "integer",
                default = as.integer(Sys.getenv("PCA_COMPONENTS", "3")),
                help = "Number of PCA components"),
    make_option(c("--maf"), type = "numeric",
                default = as.numeric(Sys.getenv("MAF_FILTER", "0.05")),
                help = "Minor allele frequency filter"),
    make_option(c("--multiple-analysis"), type = "logical",
                default = as.logical(Sys.getenv("MULTIPLE_ANALYSIS", "TRUE")),
                help = "Run multiple analysis"),
    make_option(c("--snp-fdr"), type = "numeric",
                default = NULL,
                help = "FDR threshold for SNP significance")
  )

  OptionParser(option_list = option_list)
}

# ==============================================================================
# Test: SNP_FDR Environment Variable Parsing
# ==============================================================================

test_that("SNP_FDR defaults to NULL when not set", {
  Sys.unsetenv("SNP_FDR")

  parser <- create_snp_fdr_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_null(opt$`snp-fdr`)
})

test_that("SNP_FDR command-line argument parsed correctly", {
  parser <- create_snp_fdr_option_parser()
  opt <- parse_args(parser, args = c("--snp-fdr", "0.05"))

  expect_equal(opt$`snp-fdr`, 0.05)
  expect_type(opt$`snp-fdr`, "double")
})

test_that("SNP_FDR accepts various valid values", {
  parser <- create_snp_fdr_option_parser()

  # Test 0.05 (5% FDR - common)
  opt <- parse_args(parser, args = c("--snp-fdr", "0.05"))
  expect_equal(opt$`snp-fdr`, 0.05)

  # Test 0.1 (10% FDR - permissive)
  opt <- parse_args(parser, args = c("--snp-fdr", "0.1"))
  expect_equal(opt$`snp-fdr`, 0.1)

  # Test 0.01 (1% FDR - strict)
  opt <- parse_args(parser, args = c("--snp-fdr", "0.01"))
  expect_equal(opt$`snp-fdr`, 0.01)
})

test_that("SNP_FDR can be combined with other parameters", {
  Sys.setenv(MODELS = "BLINK")
  on.exit(Sys.unsetenv("MODELS"))

  parser <- create_snp_fdr_option_parser()
  opt <- parse_args(parser, args = c("--snp-fdr", "0.05", "--pca", "5"))

  expect_equal(opt$`snp-fdr`, 0.05)
  expect_equal(opt$pca, 5)
  expect_equal(opt$models, "BLINK")
})

# ==============================================================================
# Test: SNP_FDR in Metadata Schema
# ==============================================================================

test_that("metadata fixture with FDR has snp_fdr field", {
  fixture_path <- get_fixture_path(file.path("snp_fdr", "trait_with_fdr", "metadata.json"))
  skip_if_not(file.exists(fixture_path), "SNP FDR fixture not found")

  meta <- fromJSON(fixture_path)

  expect_true("parameters" %in% names(meta))
  expect_true("snp_fdr" %in% names(meta$parameters))
  expect_equal(meta$parameters$snp_fdr, 0.05)
})

test_that("metadata fixture without FDR has null snp_fdr", {
  fixture_path <- get_fixture_path(file.path("snp_fdr", "trait_without_fdr", "metadata.json"))
  skip_if_not(file.exists(fixture_path), "SNP FDR fixture not found")

  meta <- fromJSON(fixture_path)

  expect_true("parameters" %in% names(meta))
  expect_true("snp_fdr" %in% names(meta$parameters))
  expect_null(meta$parameters$snp_fdr)
})

test_that("metadata fixture with strict FDR has correct value", {
  fixture_path <- get_fixture_path(file.path("snp_fdr", "trait_strict_fdr", "metadata.json"))
  skip_if_not(file.exists(fixture_path), "SNP FDR fixture not found")

  meta <- fromJSON(fixture_path)

  expect_equal(meta$parameters$snp_fdr, 0.01)
  expect_equal(meta$parameters$maf_filter, 0.10)
})

test_that("existing aggregation fixtures have snp_fdr field", {
  fixture_path <- get_fixture_path(file.path("aggregation", "trait_001_single_model", "metadata.json"))
  meta <- fromJSON(fixture_path)

  expect_true("snp_fdr" %in% names(meta$parameters))
  expect_equal(meta$parameters$snp_fdr, 0.05)
})

# ==============================================================================
# Test: SNP_FDR and MAF_FILTER Both Tracked
# ==============================================================================

test_that("metadata tracks both maf_filter and snp_fdr", {
  fixture_path <- get_fixture_path(file.path("snp_fdr", "trait_with_fdr", "metadata.json"))
  skip_if_not(file.exists(fixture_path), "SNP FDR fixture not found")

  meta <- fromJSON(fixture_path)

  # Both parameters should be present

  expect_true("maf_filter" %in% names(meta$parameters))
  expect_true("snp_fdr" %in% names(meta$parameters))

  # Both should have values
  expect_equal(meta$parameters$maf_filter, 0.05)
  expect_equal(meta$parameters$snp_fdr, 0.05)
})

test_that("different fixtures have different FDR configurations", {
  fdr_path <- get_fixture_path(file.path("snp_fdr", "trait_with_fdr", "metadata.json"))
  no_fdr_path <- get_fixture_path(file.path("snp_fdr", "trait_without_fdr", "metadata.json"))
  strict_path <- get_fixture_path(file.path("snp_fdr", "trait_strict_fdr", "metadata.json"))

  skip_if_not(file.exists(fdr_path), "SNP FDR fixtures not found")

  fdr_meta <- fromJSON(fdr_path)
  no_fdr_meta <- fromJSON(no_fdr_path)
  strict_meta <- fromJSON(strict_path)

  # Different SNP FDR values

  expect_equal(fdr_meta$parameters$snp_fdr, 0.05)
  expect_null(no_fdr_meta$parameters$snp_fdr)
  expect_equal(strict_meta$parameters$snp_fdr, 0.01)

  # Verify they have different workflow UIDs (different runs)
  expect_false(fdr_meta$argo$workflow_uid == no_fdr_meta$argo$workflow_uid)
})

# ==============================================================================
# Test: get_env_or_null handles SNP_FDR correctly
# ==============================================================================

test_that("get_env_or_null returns NULL for empty SNP_FDR", {
  Sys.setenv(SNP_FDR = "")
  on.exit(Sys.unsetenv("SNP_FDR"))

  result <- get_env_or_null("SNP_FDR")
  expect_null(result)
})

test_that("get_env_or_null returns value for set SNP_FDR", {
  Sys.setenv(SNP_FDR = "0.05")
  on.exit(Sys.unsetenv("SNP_FDR"))

  result <- get_env_or_null("SNP_FDR")
  expect_equal(result, "0.05")
})

test_that("get_env_or_null returns NULL for 'null' string SNP_FDR", {
  Sys.setenv(SNP_FDR = "null")
  on.exit(Sys.unsetenv("SNP_FDR"))

  result <- get_env_or_null("SNP_FDR")
  expect_null(result)
})

# ==============================================================================
# Test: Filter File Parsing with Different FDR Configurations
# ==============================================================================

#' Source read_filter_file from collect_results.R
source_aggregation_functions <- function() {
  script_path <- file.path("..", "..", "scripts", "collect_results.R")
  if (!file.exists(script_path)) {
    script_path <- file.path("scripts", "collect_results.R")
  }
  script_lines <- readLines(script_path)

  read_filter_start <- grep("^read_filter_file <- function", script_lines)[1]
  read_filter_end <- grep("^}", script_lines)
  read_filter_end <- read_filter_end[read_filter_end > read_filter_start][1]

  filter_code <- paste(script_lines[read_filter_start:read_filter_end], collapse = "\n")
  eval(parse(text = filter_code), envir = .GlobalEnv)
}

# Try to source, skip tests if it fails
tryCatch({
  suppressPackageStartupMessages({
    library(data.table)
    library(dplyr)
  })
  source_aggregation_functions()
}, error = function(e) {
  # Will skip tests that need read_filter_file
})

test_that("Filter file with FDR has expected SNP count", {
  skip_if_not(exists("read_filter_file"), "read_filter_file not available")

  fixture_dir <- get_fixture_path(file.path("snp_fdr", "trait_with_fdr"))
  skip_if_not(file.exists(file.path(fixture_dir, "GAPIT.Association.Filter_GWAS_results.csv")),
              "FDR filter file not found")

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  # FDR-filtered trait should have 3 SNPs
  expect_equal(nrow(result), 3)
  expect_true("trait_dir" %in% colnames(result))
})

test_that("Filter file without FDR has more SNPs", {
  skip_if_not(exists("read_filter_file"), "read_filter_file not available")

  fixture_dir <- get_fixture_path(file.path("snp_fdr", "trait_without_fdr"))
  skip_if_not(file.exists(file.path(fixture_dir, "GAPIT.Association.Filter_GWAS_results.csv")),
              "No-FDR filter file not found")

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  # Non-FDR trait should have 5 SNPs (more permissive)
  expect_equal(nrow(result), 5)
})

test_that("Strict FDR filter has fewer SNPs", {
  skip_if_not(exists("read_filter_file"), "read_filter_file not available")

  fixture_dir <- get_fixture_path(file.path("snp_fdr", "trait_strict_fdr"))
  skip_if_not(file.exists(file.path(fixture_dir, "GAPIT.Association.Filter_GWAS_results.csv")),
              "Strict FDR filter file not found")

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  # Strict FDR (0.01) should have only 1 SNP
  expect_equal(nrow(result), 1)
})

# ==============================================================================
# Test: Metadata Schema Validation
# ==============================================================================

test_that("metadata schema v2.0.0 includes snp_fdr in parameters", {
  fixture_path <- get_fixture_path(file.path("snp_fdr", "trait_with_fdr", "metadata.json"))
  skip_if_not(file.exists(fixture_path), "SNP FDR fixture not found")

  meta <- fromJSON(fixture_path)

  # Verify schema version
  expect_equal(meta$schema_version, "2.0.0")

  # Verify parameters section structure
  expected_params <- c("models", "pca_components", "multiple_analysis",
                       "maf_filter", "snp_fdr", "openblas_threads", "omp_threads")

  for (param in expected_params) {
    expect_true(param %in% names(meta$parameters),
                info = paste("Missing parameter:", param))
  }
})

# ==============================================================================
# Test: Provenance Tracking with SNP_FDR
# ==============================================================================

test_that("SNP FDR fixtures have proper provenance tracking", {
  fixture_path <- get_fixture_path(file.path("snp_fdr", "trait_with_fdr", "metadata.json"))
  skip_if_not(file.exists(fixture_path), "SNP FDR fixture not found")

  meta <- fromJSON(fixture_path)

  # Verify argo provenance section exists
  expect_true("argo" %in% names(meta))
  expect_true("workflow_uid" %in% names(meta$argo))
  expect_true("workflow_name" %in% names(meta$argo))

  # Verify container image tracked
  expect_true("container" %in% names(meta))
  expect_true("image" %in% names(meta$container))
})

test_that("Different FDR runs have different workflow UIDs", {
  fdr_path <- get_fixture_path(file.path("snp_fdr", "trait_with_fdr", "metadata.json"))
  no_fdr_path <- get_fixture_path(file.path("snp_fdr", "trait_without_fdr", "metadata.json"))

  skip_if_not(file.exists(fdr_path) && file.exists(no_fdr_path),
              "SNP FDR fixtures not found")

  fdr_meta <- fromJSON(fdr_path)
  no_fdr_meta <- fromJSON(no_fdr_path)

  # Different workflow UIDs indicate different pipeline runs
  expect_false(fdr_meta$argo$workflow_uid == no_fdr_meta$argo$workflow_uid)
})