# ==============================================================================
# Tests for Trait Extraction Logic
# ==============================================================================

library(testthat)

test_that("Phenotype fixture file exists and is valid", {
  pheno_path <- get_fixture_path("phenotype_mini.txt")
  expect_true(file.exists(pheno_path))

  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)
  expect_s3_class(pheno, "data.frame")
  expect_true("Taxa" %in% colnames(pheno))
  expect_equal(nrow(pheno), 5)
})

test_that("Trait extraction identifies correct number of traits", {
  pheno_path <- get_fixture_path("phenotype_mini.txt")
  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)

  trait_columns <- colnames(pheno)[colnames(pheno) != "Taxa"]
  expect_equal(length(trait_columns), 3)
  expect_true("trait_1" %in% trait_columns)
  expect_true("trait_2" %in% trait_columns)
  expect_true("trait_3" %in% trait_columns)
})

test_that("Trait extraction gets correct column indices", {
  pheno_path <- get_fixture_path("phenotype_mini.txt")
  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)

  # Taxa should be column 1, traits should be 2, 3, 4
  expect_equal(which(colnames(pheno) == "Taxa"), 1)
  expect_equal(which(colnames(pheno) == "trait_1"), 2)
  expect_equal(which(colnames(pheno) == "trait_2"), 3)
  expect_equal(which(colnames(pheno) == "trait_3"), 4)
})

test_that("Trait values are numeric", {
  pheno_path <- get_fixture_path("phenotype_mini.txt")
  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)

  trait_columns <- colnames(pheno)[colnames(pheno) != "Taxa"]
  for (trait in trait_columns) {
    expect_type(pheno[[trait]], "double")
  }
})

test_that("Taxa IDs match between genotype and phenotype", {
  geno_path <- get_fixture_path("genotype_mini.hmp.txt")
  pheno_path <- get_fixture_path("phenotype_mini.txt")

  # Read phenotype Taxa
  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)
  pheno_samples <- pheno$Taxa

  # Read genotype header
  geno_header <- scan(geno_path, what = "", nlines = 1, quiet = TRUE)
  geno_samples <- geno_header[12:length(geno_header)]

  expect_equal(sort(pheno_samples), sort(geno_samples))
})

test_that("Malformed phenotype file detected (missing Taxa column)", {
  malformed_path <- get_fixture_path("phenotype_malformed.txt")
  expect_true(file.exists(malformed_path))

  pheno <- read.table(malformed_path, header = TRUE, stringsAsFactors = FALSE)
  expect_false("Taxa" %in% colnames(pheno))
  expect_true("SampleID" %in% colnames(pheno))
})
