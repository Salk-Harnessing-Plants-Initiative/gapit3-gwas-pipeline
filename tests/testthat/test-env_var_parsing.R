# ==============================================================================
# Tests for Environment Variable Parsing in R Scripts
# ==============================================================================

library(testthat)
library(optparse)

# Helper to create option parser (same as run_gwas_single_trait.R)
create_option_parser <- function() {
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
                help = "Run multiple analysis")
  )

  OptionParser(option_list = option_list)
}

# ==============================================================================
# Environment Variable Parsing Tests
# ==============================================================================

test_that("Default values used when no env vars set", {
  # Clear any existing env vars
  Sys.unsetenv("TRAIT_INDEX")
  Sys.unsetenv("MODELS")
  Sys.unsetenv("PCA_COMPONENTS")
  Sys.unsetenv("MAF_FILTER")
  Sys.unsetenv("MULTIPLE_ANALYSIS")

  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$`trait-index`, 2)
  expect_equal(opt$models, "BLINK,FarmCPU")
  expect_equal(opt$pca, 3)
  expect_equal(opt$maf, 0.05)
  expect_equal(opt$`multiple-analysis`, TRUE)
})

test_that("MODELS env var parsed correctly", {
  Sys.setenv(MODELS = "BLINK")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$models, "BLINK")

  # Test list parsing
  models_list <- strsplit(opt$models, ",")[[1]]
  expect_equal(length(models_list), 1)
  expect_equal(models_list[1], "BLINK")

  Sys.unsetenv("MODELS")
})

test_that("PCA_COMPONENTS env var parsed as integer", {
  Sys.setenv(PCA_COMPONENTS = "5")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$pca, 5)
  expect_type(opt$pca, "integer")

  Sys.unsetenv("PCA_COMPONENTS")
})

test_that("MAF_FILTER env var parsed as numeric", {
  Sys.setenv(MAF_FILTER = "0.01")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$maf, 0.01)
  expect_type(opt$maf, "double")

  Sys.unsetenv("MAF_FILTER")
})

test_that("MULTIPLE_ANALYSIS env var parsed as logical", {
  Sys.setenv(MULTIPLE_ANALYSIS = "FALSE")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$`multiple-analysis`, FALSE)
  expect_type(opt$`multiple-analysis`, "logical")

  Sys.unsetenv("MULTIPLE_ANALYSIS")
})

test_that("Command-line args override env vars", {
  Sys.setenv(MODELS = "BLINK")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = c("--models", "FarmCPU"))

  expect_equal(opt$models, "FarmCPU")

  Sys.unsetenv("MODELS")
})

test_that("Comma-separated models parsed correctly", {
  Sys.setenv(MODELS = "BLINK,FarmCPU,MLM")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  models_list <- strsplit(opt$models, ",")[[1]]
  expect_equal(length(models_list), 3)
  expect_true("BLINK" %in% models_list)
  expect_true("FarmCPU" %in% models_list)
  expect_true("MLM" %in% models_list)

  Sys.unsetenv("MODELS")
})

test_that("Whitespace in models trimmed correctly", {
  Sys.setenv(MODELS = "BLINK, FarmCPU")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  models_list <- strsplit(opt$models, ",")[[1]]
  models_list <- trimws(models_list)

  expect_equal(models_list[1], "BLINK")
  expect_equal(models_list[2], "FarmCPU")

  Sys.unsetenv("MODELS")
})

test_that("TRAIT_INDEX env var parsed as integer", {
  Sys.setenv(TRAIT_INDEX = "10")
  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$`trait-index`, 10)
  expect_type(opt$`trait-index`, "integer")

  Sys.unsetenv("TRAIT_INDEX")
})

test_that("All env vars work together", {
  Sys.setenv(TRAIT_INDEX = "10")
  Sys.setenv(MODELS = "BLINK")
  Sys.setenv(PCA_COMPONENTS = "5")
  Sys.setenv(MAF_FILTER = "0.01")
  Sys.setenv(MULTIPLE_ANALYSIS = "FALSE")

  parser <- create_option_parser()
  opt <- parse_args(parser, args = character(0))

  expect_equal(opt$`trait-index`, 10)
  expect_equal(opt$models, "BLINK")
  expect_equal(opt$pca, 5)
  expect_equal(opt$maf, 0.01)
  expect_equal(opt$`multiple-analysis`, FALSE)

  # Cleanup
  Sys.unsetenv("TRAIT_INDEX")
  Sys.unsetenv("MODELS")
  Sys.unsetenv("PCA_COMPONENTS")
  Sys.unsetenv("MAF_FILTER")
  Sys.unsetenv("MULTIPLE_ANALYSIS")
})

test_that("Scientific notation threshold parsed correctly", {
  # This would be in a separate test file, but testing the pattern here
  threshold <- "5e-8"
  expect_true(grepl("^[0-9]+\\.?[0-9]*[eE]?-?[0-9]*$", threshold))

  threshold <- "0.00000005"
  expect_true(grepl("^[0-9]+\\.?[0-9]*[eE]?-?[0-9]*$", threshold))
})

test_that("Command-line args work without env vars", {
  # Clear env vars
  Sys.unsetenv("TRAIT_INDEX")
  Sys.unsetenv("MODELS")

  parser <- create_option_parser()
  opt <- parse_args(parser, args = c("--trait-index", "5", "--models", "MLM"))

  expect_equal(opt$`trait-index`, 5)
  expect_equal(opt$models, "MLM")
})
