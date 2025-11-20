# ==============================================================================
# Tests for Input Validation Logic
# ==============================================================================

library(testthat)
library(yaml)

test_that("Genotype fixture file has correct HapMap format", {
  geno_path <- get_fixture_path("genotype_mini.hmp.txt")
  expect_true(file.exists(geno_path))

  # Read first two lines
  lines <- readLines(geno_path, n = 2)
  expect_equal(length(lines), 2)

  # Check header
  header <- strsplit(lines[1], "\t")[[1]]
  expect_true("rs#" %in% header)
  expect_true("alleles" %in% header)
  expect_true("chrom" %in% header)
  expect_true("pos" %in% header)
})

test_that("Genotype file contains expected number of SNPs", {
  geno_path <- get_fixture_path("genotype_mini.hmp.txt")
  lines <- readLines(geno_path)
  # Header + 10 SNPs = 11 lines
  expect_equal(length(lines), 11)
})

test_that("Phenotype file has Taxa column", {
  pheno_path <- get_fixture_path("phenotype_mini.txt")
  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)
  expect_true("Taxa" %in% colnames(pheno))
})

test_that("Phenotype file has correct number of samples", {
  pheno_path <- get_fixture_path("phenotype_mini.txt")
  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)
  expect_equal(nrow(pheno), 5)
})

test_that("Config file validates with correct models", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)

  valid_models <- c("GLM", "MLM", "MLMM", "SUPER", "FarmCPU", "BLINK", "Blink")
  models <- config$gapit$models

  for (model in models) {
    expect_true(model %in% valid_models,
                info = paste("Model", model, "should be valid"))
  }
})

test_that("Config file has valid PCA components", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)

  pca <- config$gapit$pca_components
  expect_type(pca, "integer")
  expect_gte(pca, 0)
})

test_that("File size checks work for genotype", {
  geno_path <- get_fixture_path("genotype_mini.hmp.txt")
  file_size <- file.size(geno_path)
  expect_gt(file_size, 0)
  expect_lt(file_size, 1024 * 1024)  # Less than 1 MB for test fixture
})

test_that("Missing file detection works", {
  fake_path <- "nonexistent_file.txt"
  expect_false(file.exists(fake_path))
})

test_that("Minimum sample size validation", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)

  min_samples <- config$validation$require_minimum_samples
  expect_type(min_samples, "integer")

  pheno_path <- get_fixture_path("phenotype_mini.txt")
  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)

  expect_gte(nrow(pheno), min_samples)
})

test_that("Taxa column detection for malformed file", {
  malformed_path <- get_fixture_path("phenotype_malformed.txt")
  pheno <- read.table(malformed_path, header = TRUE, stringsAsFactors = FALSE)

  # This should fail Taxa check
  has_taxa <- "Taxa" %in% colnames(pheno)
  expect_false(has_taxa)
})
