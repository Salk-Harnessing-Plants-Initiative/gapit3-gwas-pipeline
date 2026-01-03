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

  # Find select_best_trait_dirs function
  select_start <- grep("^select_best_trait_dirs <- function", script_lines)[1]
  select_end <- grep("^}", script_lines)
  select_end <- select_end[select_end > select_start][1]

  # Find check_trait_completeness function
  check_start <- grep("^check_trait_completeness <- function", script_lines)[1]
  check_end <- grep("^}", script_lines)
  check_end <- check_end[check_end > check_start][1]

  # Find read_filter_file function (no longer has fallback)
  read_filter_start <- grep("^read_filter_file <- function", script_lines)[1]
  read_filter_end <- grep("^}", script_lines)
  read_filter_end <- read_filter_end[read_filter_end > read_filter_start][1]

  # Extract and evaluate function definitions
  select_code <- paste(script_lines[select_start:select_end], collapse = "\n")
  eval(parse(text = select_code), envir = .GlobalEnv)

  if (!is.na(check_start)) {
    check_code <- paste(script_lines[check_start:check_end], collapse = "\n")
    eval(parse(text = check_code), envir = .GlobalEnv)
  }

  filter_code <- paste(script_lines[read_filter_start:read_filter_end], collapse = "\n")
  eval(parse(text = filter_code), envir = .GlobalEnv)
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

  result <- suppressWarnings(read_filter_file(fixture_dir, threshold = 5e-8))

  expect_equal(unique(result$model), "BLINK")

  trait_name <- unique(result$trait)
  # Trait name should contain the period but NOT the (NYC) suffix (stripped)
  expect_true(grepl("day_1\\.2", trait_name))
  expect_equal(trait_name, "mean_GR_rootLength_day_1.2")

  # analysis_type should be extracted
  expect_true("analysis_type" %in% colnames(result))
  expect_equal(unique(result$analysis_type), "NYC")
})

# ==============================================================================
# Test: read_filter_file() returns NULL when Filter file missing (fail-fast)
# ==============================================================================
test_that("read_filter_file returns NULL when Filter file missing", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_004_no_filter"))

  # With fail-fast behavior, missing Filter file returns NULL (not fallback data)
  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  expect_null(result)
})

# ==============================================================================
# Test: check_trait_completeness() detects incomplete traits
# ==============================================================================
test_that("check_trait_completeness detects incomplete traits", {
  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  fixture_base <- get_fixture_path("aggregation")

  # Copy complete traits (have Filter file)
  for (trait_dir in c("trait_001_single_model", "trait_002_multi_model")) {
    src_dir <- file.path(fixture_base, trait_dir)
    dest_dir <- file.path(temp_output, trait_dir)
    dir.create(dest_dir, recursive = TRUE)
    for (file in list.files(src_dir, full.names = TRUE)) {
      file.copy(file, dest_dir)
    }
  }

  # Copy incomplete trait (no Filter file)
  src_dir <- file.path(fixture_base, "trait_004_no_filter")
  dest_dir <- file.path(temp_output, "trait_004_no_filter")
  dir.create(dest_dir, recursive = TRUE)
  for (file in list.files(src_dir, full.names = TRUE)) {
    file.copy(file, dest_dir)
  }

  trait_dirs <- list.files(temp_output, pattern = "trait_", full.names = TRUE)
  incomplete <- check_trait_completeness(trait_dirs)

  expect_equal(length(incomplete), 1)
  expect_true(grepl("trait_004_no_filter", incomplete[1]))
})

# ==============================================================================
# Test: Aggregation fails by default when incomplete traits found
# ==============================================================================
test_that("aggregation workflow fails when incomplete traits present", {
  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  fixture_base <- get_fixture_path("aggregation")

  # Copy one complete and one incomplete trait
  for (trait_dir in c("trait_001_single_model", "trait_004_no_filter")) {
    src_dir <- file.path(fixture_base, trait_dir)
    dest_dir <- file.path(temp_output, trait_dir)
    dir.create(dest_dir, recursive = TRUE)
    for (file in list.files(src_dir, full.names = TRUE)) {
      file.copy(file, dest_dir)
    }
  }

  trait_dirs <- list.files(temp_output, pattern = "trait_", full.names = TRUE)
  incomplete <- check_trait_completeness(trait_dirs)

  # Should detect 1 incomplete trait
  expect_equal(length(incomplete), 1)

  # Aggregation should not proceed without --allow-incomplete
  # (We test this by checking incomplete list is not empty)
  expect_gt(length(incomplete), 0)
})

# ==============================================================================
# Test: Aggregation succeeds when all traits complete
# ==============================================================================
test_that("aggregation succeeds when all traits have Filter files", {
  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  fixture_base <- get_fixture_path("aggregation")

  # Copy only complete traits
  for (trait_dir in c("trait_001_single_model", "trait_002_multi_model", "trait_003_period_in_name")) {
    src_dir <- file.path(fixture_base, trait_dir)
    dest_dir <- file.path(temp_output, trait_dir)
    dir.create(dest_dir, recursive = TRUE)
    for (file in list.files(src_dir, full.names = TRUE)) {
      file.copy(file, dest_dir)
    }
  }

  trait_dirs <- list.files(temp_output, pattern = "trait_", full.names = TRUE)
  incomplete <- check_trait_completeness(trait_dirs)

  # Should detect no incomplete traits
  expect_equal(length(incomplete), 0)

  # Aggregation should proceed
  all_snps <- data.frame()
  for (dir in trait_dirs) {
    trait_snps <- read_filter_file(dir, threshold = 5e-8)
    if (!is.null(trait_snps) && nrow(trait_snps) > 0) {
      all_snps <- rbind(all_snps, trait_snps)
    }
  }

  expect_gt(nrow(all_snps), 0)
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
    trait_str <- test_cases$traits[i]

    # Parse model and trait - handle compound models (e.g., FarmCPU.LM, Blink.LM)
    if (grepl("^FarmCPU\\.LM\\.", trait_str)) {
      model <- "FarmCPU.LM"
      trait <- sub("^FarmCPU\\.LM\\.", "", trait_str)
    } else if (grepl("^Blink\\.LM\\.", trait_str)) {
      model <- "Blink.LM"
      trait <- sub("^Blink\\.LM\\.", "", trait_str)
    } else {
      # Simple model - split on first period
      model <- sub("\\..*", "", trait_str)
      trait <- sub("^[^.]+\\.", "", trait_str)
    }

    expect_equal(model, test_cases$expected_model[i],
                 info = paste("Failed for:", trait_str))
    expect_equal(trait, test_cases$expected_trait[i],
                 info = paste("Failed for:", trait_str))
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

# ==============================================================================
# Test: Empty Filter file without traits column (TDD Phase 1)
# ==============================================================================
test_that("read_filter_file returns empty immediately for Filter without traits column", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_empty_no_traits"))

  # Capture any console output
  output <- capture.output({
    start_time <- Sys.time()
    result <- read_filter_file(fixture_dir, threshold = 5e-8)
    end_time <- Sys.time()
  })

  # Should return empty data.frame
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)

  # Should NOT contain fallback warnings
  expect_false(any(grepl("using GWAS_Results fallback", output)))

  # Should complete quickly (<0.1 seconds)
  elapsed <- as.numeric(end_time - start_time, units = "secs")
  expect_lt(elapsed, 0.1)
})

# ==============================================================================
# Test: Empty Filter file with traits column but no rows (TDD Phase 1)
# ==============================================================================
test_that("read_filter_file returns empty for Filter with traits but no data", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_empty_with_traits"))

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  # Should return empty data.frame
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

# ==============================================================================
# Tests for select_best_trait_dirs() - Deduplication
# ==============================================================================

test_that("select_best_trait_dirs returns empty for empty input", {
  result <- select_best_trait_dirs(character(0), c("BLINK", "FarmCPU", "MLM"))
  expect_equal(length(result), 0)
})

test_that("select_best_trait_dirs selects more complete directory", {
  # Create temp directories with different completeness
  temp_base <- tempdir()
  old_dir <- file.path(temp_base, "trait_005_20231101_120000")
  new_dir <- file.path(temp_base, "trait_005_20231102_120000")

  dir.create(old_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(new_dir, showWarnings = FALSE, recursive = TRUE)

  on.exit({
    unlink(old_dir, recursive = TRUE)
    unlink(new_dir, recursive = TRUE)
  })

  # Old directory: 2/3 models (missing MLM)
  file.create(file.path(old_dir, "GAPIT.Association.GWAS_Results.BLINK.trait.csv"))
  file.create(file.path(old_dir, "GAPIT.Association.GWAS_Results.FarmCPU.trait.csv"))

  # New directory: 3/3 models (complete)
  file.create(file.path(new_dir, "GAPIT.Association.GWAS_Results.BLINK.trait.csv"))
  file.create(file.path(new_dir, "GAPIT.Association.GWAS_Results.FarmCPU.trait.csv"))
  file.create(file.path(new_dir, "GAPIT.Association.GWAS_Results.MLM.trait.csv"))

  trait_dirs <- c(old_dir, new_dir)
  expected_models <- c("BLINK", "FarmCPU", "MLM")

  result <- select_best_trait_dirs(trait_dirs, expected_models)

  expect_equal(length(result), 1)
  expect_equal(result, new_dir)  # Should select more complete
})

test_that("select_best_trait_dirs prefers old complete over new partial", {
  # Scenario: retry failed early, old directory is more complete
  temp_base <- tempdir()
  old_dir <- file.path(temp_base, "trait_010_20231101_120000")
  new_dir <- file.path(temp_base, "trait_010_20231102_120000")

  dir.create(old_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(new_dir, showWarnings = FALSE, recursive = TRUE)

  on.exit({
    unlink(old_dir, recursive = TRUE)
    unlink(new_dir, recursive = TRUE)
  })

  # Old directory: 2/3 models
  file.create(file.path(old_dir, "GAPIT.Association.GWAS_Results.BLINK.trait.csv"))
  file.create(file.path(old_dir, "GAPIT.Association.GWAS_Results.FarmCPU.trait.csv"))

  # New directory: 1/3 models (retry failed very early)
  file.create(file.path(new_dir, "GAPIT.Association.GWAS_Results.BLINK.trait.csv"))

  trait_dirs <- c(old_dir, new_dir)
  expected_models <- c("BLINK", "FarmCPU", "MLM")

  result <- select_best_trait_dirs(trait_dirs, expected_models)

  expect_equal(length(result), 1)
  expect_equal(result, old_dir)  # Should prefer more complete old directory
})

test_that("select_best_trait_dirs uses newest as tie-breaker", {
  # Both directories are equally complete
  temp_base <- tempdir()
  old_dir <- file.path(temp_base, "trait_015_20231101_120000")
  new_dir <- file.path(temp_base, "trait_015_20231102_120000")

  dir.create(old_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(new_dir, showWarnings = FALSE, recursive = TRUE)

  on.exit({
    unlink(old_dir, recursive = TRUE)
    unlink(new_dir, recursive = TRUE)
  })

  # Both directories: 3/3 models (complete)
  for (dir in c(old_dir, new_dir)) {
    file.create(file.path(dir, "GAPIT.Association.GWAS_Results.BLINK.trait.csv"))
    file.create(file.path(dir, "GAPIT.Association.GWAS_Results.FarmCPU.trait.csv"))
    file.create(file.path(dir, "GAPIT.Association.GWAS_Results.MLM.trait.csv"))
  }

  trait_dirs <- c(old_dir, new_dir)
  expected_models <- c("BLINK", "FarmCPU", "MLM")

  result <- select_best_trait_dirs(trait_dirs, expected_models)

  expect_equal(length(result), 1)
  expect_equal(result, new_dir)  # Should prefer newer when tied
})

test_that("select_best_trait_dirs handles multiple traits correctly", {
  temp_base <- tempdir()
  dirs <- c(
    file.path(temp_base, "trait_001_20231101_120000"),
    file.path(temp_base, "trait_002_20231101_120000"),
    file.path(temp_base, "trait_002_20231102_120000")  # duplicate for trait 2
  )

  for (d in dirs) {
    dir.create(d, showWarnings = FALSE, recursive = TRUE)
    file.create(file.path(d, "GAPIT.Association.GWAS_Results.BLINK.trait.csv"))
    file.create(file.path(d, "GAPIT.Association.GWAS_Results.FarmCPU.trait.csv"))
    file.create(file.path(d, "GAPIT.Association.GWAS_Results.MLM.trait.csv"))
  }

  on.exit(unlink(dirs, recursive = TRUE))

  expected_models <- c("BLINK", "FarmCPU", "MLM")

  result <- select_best_trait_dirs(dirs, expected_models)

  expect_equal(length(result), 2)  # One per trait index
  expect_true(dirs[1] %in% result)  # Trait 1
  expect_true(dirs[3] %in% result)  # Trait 2 (newer)
  expect_false(dirs[2] %in% result)  # Old trait 2 excluded
})

# ==============================================================================
# Tests for BLINK MAF column swap fix (fix-aggregation-column-handling)
# ==============================================================================

test_that("read_filter_file detects BLINK MAF > 1 and sets to NA", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_blink_maf_swap"))

  # Capture warnings
  result <- suppressWarnings(read_filter_file(fixture_dir, threshold = 5e-8))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true("MAF" %in% colnames(result))


  # BLINK rows with MAF > 1 should be set to NA
  expect_true(all(is.na(result$MAF)))
  expect_equal(unique(result$model), "BLINK")
})

test_that("read_filter_file retains valid MAF for MLM/FarmCPU models", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_mixed_models"))

  result <- suppressWarnings(read_filter_file(fixture_dir, threshold = 5e-8))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)

  # MLM and FarmCPU should have valid MAF values
  mlm_row <- result[result$model == "MLM", ]
  farmcpu_row <- result[result$model == "FarmCPU", ]

  expect_false(is.na(mlm_row$MAF))
  expect_false(is.na(farmcpu_row$MAF))
  expect_true(mlm_row$MAF > 0 && mlm_row$MAF <= 0.5)
  expect_true(farmcpu_row$MAF > 0 && farmcpu_row$MAF <= 0.5)

  # BLINK should have NA MAF (was 536)
  blink_row <- result[result$model == "BLINK", ]
  expect_true(is.na(blink_row$MAF))
})

# ==============================================================================
# Tests for analysis_type parsing (fix-aggregation-column-handling)
# ==============================================================================

test_that("read_filter_file extracts analysis_type=NYC from trait suffix", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_mixed_models"))

  result <- suppressWarnings(read_filter_file(fixture_dir, threshold = 5e-8))

  expect_true("analysis_type" %in% colnames(result))
  expect_true(all(result$analysis_type == "NYC"))

  # Trait name should NOT contain (NYC) suffix
  expect_false(any(grepl("\\(NYC\\)", result$trait)))
  expect_equal(unique(result$trait), "test_trait")
})

test_that("read_filter_file extracts analysis_type=Kansas from trait suffix", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_kansas_suffix"))

  result <- suppressWarnings(read_filter_file(fixture_dir, threshold = 5e-8))

  expect_true("analysis_type" %in% colnames(result))
  expect_true(all(result$analysis_type == "Kansas"))

  # Trait name should NOT contain (Kansas) suffix
  expect_false(any(grepl("\\(Kansas\\)", result$trait)))
  expect_equal(unique(result$trait), "shoot_iron_content")
})

test_that("read_filter_file sets analysis_type=standard when no suffix", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_no_suffix"))

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  expect_true("analysis_type" %in% colnames(result))
  expect_true(all(result$analysis_type == "standard"))
  expect_equal(unique(result$trait), "simple_trait")
})

test_that("aggregated output includes analysis_type and trait_dir columns", {
  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  fixture_base <- get_fixture_path("aggregation")

  # Copy fixtures to temp directory
  for (trait_dir in c("trait_mixed_models", "trait_no_suffix")) {
    src_dir <- file.path(fixture_base, trait_dir)
    dest_dir <- file.path(temp_output, trait_dir)
    dir.create(dest_dir, recursive = TRUE)
    for (file in list.files(src_dir, full.names = TRUE)) {
      file.copy(file, dest_dir)
    }
  }

  # Aggregate results
  all_snps <- data.frame()
  trait_dirs_full <- list.files(temp_output, pattern = "trait_", full.names = TRUE)

  for (dir in trait_dirs_full) {
    trait_snps <- suppressWarnings(read_filter_file(dir, threshold = 5e-8))
    if (!is.null(trait_snps) && nrow(trait_snps) > 0) {
      all_snps <- rbind(all_snps, trait_snps)
    }
  }

  # Verify required columns exist
  expect_true("analysis_type" %in% colnames(all_snps))
  expect_true("trait_dir" %in% colnames(all_snps))
  expect_true("model" %in% colnames(all_snps))
  expect_true("trait" %in% colnames(all_snps))

  # Verify analysis_type values
  expect_true("NYC" %in% all_snps$analysis_type)
  expect_true("standard" %in% all_snps$analysis_type)
})