# ==============================================================================
# Tests for Config File Parsing
# ==============================================================================

library(testthat)
library(yaml)

test_that("Test config file loads successfully", {
  config_path <- get_fixture_path("config_test.yaml")
  expect_true(file.exists(config_path))

  config <- yaml::read_yaml(config_path)
  expect_type(config, "list")
  expect_true("data" %in% names(config))
  expect_true("gapit" %in% names(config))
})

test_that("Config contains expected GAPIT models", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)

  models <- config$gapit$models
  expect_type(models, "character")
  expect_equal(length(models), 2)
  expect_true("BLINK" %in% models)
  expect_true("FarmCPU" %in% models)
})

test_that("Config PCA components parsed correctly", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)

  pca <- config$gapit$pca_components
  expect_type(pca, "integer")
  expect_equal(pca, 3)
})

test_that("Config validation settings are present", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)

  expect_true("validation" %in% names(config))
  expect_true(config$validation$check_input_files)
  expect_true(config$validation$verify_trait_index)
  expect_equal(config$validation$require_minimum_samples, 3)
})

test_that("Config data paths are specified", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)

  expect_true("data" %in% names(config))
  expect_type(config$data$genotype, "character")
  expect_type(config$data$phenotype, "character")
  expect_match(config$data$genotype, "genotype_mini.hmp.txt")
  expect_match(config$data$phenotype, "phenotype_mini.txt")
})

test_that("Config resources settings are valid", {
  config_path <- get_fixture_path("config_test.yaml")
  config <- yaml::read_yaml(config_path)

  expect_true("resources" %in% names(config))
  expect_type(config$resources$threads, "integer")
  expect_gt(config$resources$threads, 0)
})
