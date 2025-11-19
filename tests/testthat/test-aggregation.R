# ==============================================================================
# Tests for GAPIT Results Aggregation Script
# ==============================================================================
# Tests for collect_results.R aggregation functionality
# ==============================================================================

library(testthat)
library(data.table)
library(dplyr)
library(jsonlite)

# Note: helper.R is automatically sourced by testthat

# ==============================================================================
# Helper function to source only the functions from collect_results.R
# ==============================================================================
source_aggregation_functions <- function() {
  # Read the script (path relative to project root)
  script_path <- file.path("..", "..", "scripts", "collect_results.R")
  script_lines <- readLines(script_path)

  # Find function definitions
  read_filter_start <- grep("^read_filter_file <- function", script_lines)[1]
  fallback_end <- grep("^}", script_lines)
  fallback_end <- fallback_end[fallback_end > read_filter_start][2]

  # Extract and evaluate function definitions
  functions_code <- paste(script_lines[read_filter_start:fallback_end], collapse = "\n")
  eval(parse(text = functions_code), envir = .GlobalEnv)
}

# Source the functions for testing
source_aggregation_functions()

# ==============================================================================
# Test: read_filter_file() with single model
# ==============================================================================
test_that("read_filter_file reads single model Filter file correctly", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_001_single_model"))

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  expect_s3_class(result, "data.frame")
  expect_gt(nrow(result), 0)
  expect_true("model" %in% colnames(result))
  expect_true("trait" %in% colnames(result))
  expect_equal(unique(result$model), "BLINK")
  expect_false("traits" %in% colnames(result))
  expect_true(all(c("SNP", "Chr", "Pos", "P.value", "model", "trait") %in% colnames(result)))
})

# ==============================================================================
# Test: read_filter_file() with multiple models
# ==============================================================================
test_that("read_filter_file reads multi-model Filter file correctly", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_002_multi_model"))

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  expect_s3_class(result, "data.frame")
  expect_gt(nrow(result), 0)
  expect_true("model" %in% colnames(result))

  models <- unique(result$model)
  expect_true("BLINK" %in% models)
  expect_true("FarmCPU" %in% models)

  snp_overlap <- result %>%
    group_by(SNP, Chr, Pos) %>%
    summarise(n_models = n_distinct(model), .groups = "drop") %>%
    filter(n_models > 1)

  expect_gt(nrow(snp_overlap), 0)
})

# ==============================================================================
# Test: read_filter_file() handles trait names with periods
# ==============================================================================
test_that("read_filter_file correctly parses trait names with periods", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_003_period_in_name"))

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  expect_equal(unique(result$model), "BLINK")

  trait_name <- unique(result$trait)
  expect_true(grepl("day_1\\.2", trait_name))
  expect_true(grepl("mean_GR_rootLength_day_1\\.2\\(NYC\\)", trait_name))
})

# ==============================================================================
# Test: read_filter_file() falls back to GWAS_Results when Filter missing
# ==============================================================================
test_that("read_filter_file falls back to GWAS_Results when Filter file missing", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_004_no_filter"))

  expect_warning(
    result <- read_filter_file(fixture_dir, threshold = 5e-8),
    "Filter file missing"
  )

  expect_s3_class(result, "data.frame")
  expect_true("model" %in% colnames(result))
  expect_true("trait" %in% colnames(result))
})

# ==============================================================================
# Test: Model parsing edge cases
# ==============================================================================
test_that("model parsing handles edge cases correctly", {
  test_cases <- data.frame(
    traits = c(
      "BLINK.simple_trait",
      "FarmCPU.trait_with_underscores",
      "BLINK.trait.with.many.periods",
      "FarmCPU.LM.trait_name"
    ),
    expected_model = c("BLINK", "FarmCPU", "BLINK", "FarmCPU.LM"),
    expected_trait = c(
      "simple_trait",
      "trait_with_underscores",
      "trait.with.many.periods",
      "trait_name"
    ),
    stringsAsFactors = FALSE
  )

  for (i in 1:nrow(test_cases)) {
    model <- sub("\\..*", "", test_cases$traits[i])
    trait <- sub("^[^.]+\\.", "", test_cases$traits[i])

    expect_equal(model, test_cases$expected_model[i])
    expect_equal(trait, test_cases$expected_trait[i])
  }
})

# ==============================================================================
# Test: Integration test - full aggregation workflow
# ==============================================================================
test_that("full aggregation workflow produces correct output", {
  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  fixture_base <- get_fixture_path("aggregation")
  trait_dirs <- c("trait_001_single_model", "trait_002_multi_model",
                 "trait_003_period_in_name")

  for (trait_dir in trait_dirs) {
    src_dir <- file.path(fixture_base, trait_dir)
    dest_dir <- file.path(temp_output, trait_dir)
    dir.create(dest_dir, recursive = TRUE)

    files_to_copy <- list.files(src_dir, full.names = TRUE)
    for (file in files_to_copy) {
      file.copy(file, dest_dir)
    }
  }

  all_snps <- data.frame()
  trait_dirs_full <- list.files(temp_output, pattern = "trait_", full.names = TRUE)

  for (dir in trait_dirs_full) {
    trait_snps <- read_filter_file(dir, threshold = 5e-8)
    if (nrow(trait_snps) > 0) {
      all_snps <- rbind(all_snps, trait_snps)
    }
  }

  all_snps <- all_snps[order(all_snps$P.value), ]

  expect_gt(nrow(all_snps), 0)
  expect_true("model" %in% colnames(all_snps))
  expect_true("trait" %in% colnames(all_snps))
  expect_true(all(diff(all_snps$P.value) >= 0))

  models <- unique(all_snps$model)
  expect_true("BLINK" %in% models)
  expect_true("FarmCPU" %in% models)

  output_dir <- file.path(temp_output, "aggregated_results")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_file <- file.path(output_dir, "all_traits_significant_snps.csv")

  write.csv(all_snps, output_file, row.names = FALSE)
  expect_true(file.exists(output_file))

  reloaded <- read.csv(output_file, stringsAsFactors = FALSE)
  expect_equal(nrow(reloaded), nrow(all_snps))
  expect_true("model" %in% colnames(reloaded))
})

# ==============================================================================
# Test: Summary statistics generation
# ==============================================================================
test_that("summary statistics include per-model counts", {
  test_snps <- data.frame(
    SNP = c("SNP_1", "SNP_2", "SNP_3", "SNP_3", "SNP_4"),
    Chr = c(1, 1, 1, 1, 2),
    Pos = c(100, 200, 300, 300, 400),
    P.value = c(1e-9, 2e-9, 3e-9, 4e-9, 5e-9),
    model = c("BLINK", "BLINK", "BLINK", "FarmCPU", "FarmCPU"),
    trait = c("trait_A", "trait_A", "trait_A", "trait_A", "trait_B"),
    stringsAsFactors = FALSE
  )

  snps_by_model <- list()
  for (model in unique(test_snps$model)) {
    snps_by_model[[model]] <- sum(test_snps$model == model)
  }

  expect_equal(snps_by_model$BLINK, 3)
  expect_equal(snps_by_model$FarmCPU, 2)

  snp_models <- test_snps %>%
    group_by(SNP, Chr, Pos) %>%
    summarise(n_models = n_distinct(model), .groups = "drop")

  overlap_count <- sum(snp_models$n_models > 1)
  expect_equal(overlap_count, 1)
})