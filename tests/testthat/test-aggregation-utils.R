# ==============================================================================
# Tests for Aggregation Utility Modules
# ==============================================================================
# Unit tests for scripts/lib/aggregation_utils.R and scripts/lib/constants.R
# These modules provide testable functions for GWAS results aggregation.
# ==============================================================================

library(testthat)
library(jsonlite)

# Note: helper.R is automatically sourced by testthat

# ==============================================================================
# Source modules for testing
# ==============================================================================

# Get project root (handle different test execution contexts)
get_project_root <- function() {
  # Try common locations
  candidates <- c(
    "../..",           # Running from tests/testthat
    "..",              # Running from tests
    "."                # Running from project root
  )

  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "scripts", "lib", "constants.R"))) {
      return(normalizePath(candidate))
    }
  }
  stop("Could not find project root")
}

project_root <- get_project_root()
source(file.path(project_root, "scripts", "lib", "constants.R"))
source(file.path(project_root, "scripts", "lib", "aggregation_utils.R"))

# ==============================================================================
# Tests: constants.R
# ==============================================================================

test_that("KNOWN_GAPIT_MODELS is defined and non-empty", {
  expect_true(exists("KNOWN_GAPIT_MODELS"))
  expect_type(KNOWN_GAPIT_MODELS, "character")
  expect_gt(length(KNOWN_GAPIT_MODELS), 0)
})

test_that("KNOWN_GAPIT_MODELS contains expected core models", {
  expect_true("BLINK" %in% KNOWN_GAPIT_MODELS)
  expect_true("FarmCPU" %in% KNOWN_GAPIT_MODELS)
  expect_true("MLM" %in% KNOWN_GAPIT_MODELS)
  expect_true("MLMM" %in% KNOWN_GAPIT_MODELS)
  expect_true("GLM" %in% KNOWN_GAPIT_MODELS)
})

test_that("KNOWN_GAPIT_MODELS contains compound models", {
  expect_true("FarmCPU.LM" %in% KNOWN_GAPIT_MODELS)
  expect_true("Blink.LM" %in% KNOWN_GAPIT_MODELS)
})

test_that("DEFAULT_MODELS is defined correctly", {
  expect_true(exists("DEFAULT_MODELS"))
  expect_type(DEFAULT_MODELS, "character")
  expect_equal(DEFAULT_MODELS, c("BLINK", "FarmCPU", "MLM"))
})

test_that("DEFAULT_MODELS_STRING matches DEFAULT_MODELS", {
  expect_true(exists("DEFAULT_MODELS_STRING"))
  expect_equal(DEFAULT_MODELS_STRING, "BLINK,FarmCPU,MLM")
  expect_equal(strsplit(DEFAULT_MODELS_STRING, ",")[[1]], DEFAULT_MODELS)
})

test_that("sourcing constants.R has no side effects", {
  # Re-source should not produce output or errors
  output <- capture.output({
    source(file.path(project_root, "scripts", "lib", "constants.R"))
  })
  expect_equal(length(output), 0)
})

# ==============================================================================
# Tests: extract_models_from_metadata()
# ==============================================================================

test_that("extract_models_from_metadata returns NULL for non-existent file", {
  result <- extract_models_from_metadata("/nonexistent/path/metadata.json")
  expect_null(result)
})

test_that("extract_models_from_metadata extracts v3.0.0 flat schema models", {
  fixture_path <- get_fixture_path("metadata/gapit_metadata_blink_farmcpu.json")
  result <- extract_models_from_metadata(fixture_path)

  expect_type(result, "character")
  expect_equal(result, c("BLINK", "FarmCPU"))
})

test_that("extract_models_from_metadata extracts single model", {
  fixture_path <- get_fixture_path("metadata/gapit_metadata_mlm_only.json")
  result <- extract_models_from_metadata(fixture_path)

  expect_type(result, "character")
  expect_equal(result, "MLM")
})

test_that("extract_models_from_metadata extracts legacy v2.0.0 schema models", {
  fixture_path <- get_fixture_path("metadata/gapit_metadata_legacy.json")
  result <- extract_models_from_metadata(fixture_path)

  expect_type(result, "character")
  expect_equal(result, c("GLM", "MLMM"))
})

test_that("extract_models_from_metadata returns NULL when no model field", {
  fixture_path <- get_fixture_path("metadata/gapit_metadata_empty.json")
  result <- extract_models_from_metadata(fixture_path)

  expect_null(result)
})

test_that("extract_models_from_metadata returns NULL for malformed JSON", {
  fixture_path <- get_fixture_path("metadata/gapit_metadata_malformed.json")
  result <- extract_models_from_metadata(fixture_path)

  expect_null(result)
})

test_that("extract_models_from_metadata handles comma-separated string", {
  # Create temp file with comma-separated models
  temp_file <- tempfile(fileext = ".json")
  on.exit(unlink(temp_file))

  metadata <- list(
    parameters = list(
      model = "BLINK,FarmCPU,MLM"
    )
  )
  write_json(metadata, temp_file, auto_unbox = TRUE)

  result <- extract_models_from_metadata(temp_file)
  expect_equal(result, c("BLINK", "FarmCPU", "MLM"))
})

test_that("extract_models_from_metadata handles nested gapit object", {
  # Create temp file with nested gapit object
  temp_file <- tempfile(fileext = ".json")
  on.exit(unlink(temp_file))

  metadata <- list(
    parameters = list(
      gapit = list(
        model = c("SUPER", "CMLM")
      )
    )
  )
  write_json(metadata, temp_file, auto_unbox = TRUE)

  result <- extract_models_from_metadata(temp_file)
  expect_equal(result, c("SUPER", "CMLM"))
})

# ==============================================================================
# Tests: validate_model_names()
# ==============================================================================

test_that("validate_model_names accepts all known models", {
  for (model in KNOWN_GAPIT_MODELS) {
    result <- validate_model_names(model)
    expect_true(result$valid, info = paste("Failed for model:", model))
    expect_equal(length(result$invalid_models), 0)
  }
})

test_that("validate_model_names rejects unknown models", {
  result <- validate_model_names(c("BLINK", "UNKNOWN_MODEL"))

  expect_false(result$valid)
  expect_equal(result$invalid_models, "UNKNOWN_MODEL")
})

test_that("validate_model_names is case-insensitive", {
  result <- validate_model_names(c("blink", "farmcpu", "mlm"))

  expect_true(result$valid)
  expect_equal(length(result$invalid_models), 0)
  expect_equal(result$canonical_models, c("BLINK", "FarmCPU", "MLM"))
})

test_that("validate_model_names preserves case for unknown models", {
  result <- validate_model_names(c("BLINK", "WeirdModel"))

  expect_false(result$valid)
  expect_equal(result$invalid_models, "WeirdModel")
  expect_equal(result$canonical_models[1], "BLINK")
  expect_equal(result$canonical_models[2], "WeirdModel")  # Preserved original
})

test_that("validate_model_names handles empty input", {
  result <- validate_model_names(character(0))

  expect_false(result$valid)
  expect_equal(length(result$invalid_models), 0)
  expect_equal(length(result$canonical_models), 0)
})

test_that("validate_model_names accepts custom known_models parameter", {
  custom_models <- c("MODEL_A", "MODEL_B", "MODEL_C")
  result <- validate_model_names(c("MODEL_A", "MODEL_B"), known_models = custom_models)

  expect_true(result$valid)
  expect_equal(length(result$invalid_models), 0)
})

test_that("validate_model_names works without global KNOWN_GAPIT_MODELS", {
  # This tests the explicit parameter approach (pure function)
  custom_known <- c("CUSTOM1", "CUSTOM2")
  result <- validate_model_names(c("CUSTOM1"), known_models = custom_known)

  expect_true(result$valid)
  expect_equal(result$canonical_models, "CUSTOM1")
})

test_that("validate_model_names handles compound models", {
  result <- validate_model_names(c("FarmCPU.LM", "Blink.LM"))

  expect_true(result$valid)
  expect_equal(result$canonical_models, c("FarmCPU.LM", "Blink.LM"))
})

# ==============================================================================
# Tests: get_gapit_param()
# ==============================================================================

test_that("get_gapit_param extracts v3.0.0 flat parameters", {
  fixture_path <- get_fixture_path("metadata/gapit_metadata_blink_farmcpu.json")
  metadata <- fromJSON(fixture_path)

  result <- get_gapit_param(metadata, "PCA.total", "pca_components", default = 0)
  expect_equal(result, 3)
})

test_that("get_gapit_param extracts legacy v2.0.0 parameters", {
  fixture_path <- get_fixture_path("metadata/gapit_metadata_legacy.json")
  metadata <- fromJSON(fixture_path)

  # Should find legacy parameter name
  result <- get_gapit_param(metadata, "PCA.total", "pca_components", default = 0)
  expect_equal(result, 3)
})

test_that("get_gapit_param returns default when not found", {
  metadata <- list(parameters = list())

  result <- get_gapit_param(metadata, "nonexistent", "also_nonexistent", default = "default_value")
  expect_equal(result, "default_value")
})

test_that("get_gapit_param prefers gapit_name over legacy_name", {
  # Create metadata with both old and new names
  metadata <- list(
    parameters = list(
      gapit = list(
        `PCA.total` = 5
      ),
      pca_components = 3  # Legacy name with different value
    )
  )

  result <- get_gapit_param(metadata, "PCA.total", "pca_components", default = 0)
  expect_equal(result, 5)  # Should prefer the new name
})

test_that("get_gapit_param handles NULL legacy_name", {
  metadata <- list(
    parameters = list(
      gapit = list(
        kinship.algorithm = "Zhang"
      )
    )
  )

  result <- get_gapit_param(metadata, "kinship.algorithm", NULL, default = "VanRaden")
  expect_equal(result, "Zhang")
})

test_that("get_gapit_param handles missing parameters section", {
  metadata <- list(trait = list(name = "test"))

  result <- get_gapit_param(metadata, "model", "models", default = "BLINK")
  expect_equal(result, "BLINK")
})

# ==============================================================================
# Tests: detect_models_from_first_trait()
# ==============================================================================

test_that("detect_models_from_first_trait returns NULL for nonexistent directory", {
  result <- detect_models_from_first_trait("/nonexistent/directory")
  expect_null(result)
})

test_that("detect_models_from_first_trait returns NULL when no trait dirs", {
  temp_dir <- tempdir()
  empty_dir <- file.path(temp_dir, "empty_test_dir")
  dir.create(empty_dir, showWarnings = FALSE)
  on.exit(unlink(empty_dir, recursive = TRUE))

  result <- detect_models_from_first_trait(empty_dir)
  expect_null(result)
})

test_that("detect_models_from_first_trait finds models from metadata.json", {
  # Create temp structure with trait directory and metadata
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "detect_test_1")
  trait_dir <- file.path(test_dir, "trait_001_test")
  dir.create(trait_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create metadata file
  metadata <- list(
    parameters = list(
      model = "MLM,MLMM"
    )
  )
  write_json(metadata, file.path(trait_dir, "metadata.json"), auto_unbox = TRUE)

  result <- detect_models_from_first_trait(test_dir)
  expect_equal(result, c("MLM", "MLMM"))
})

test_that("detect_models_from_first_trait prefers gapit_metadata.json over metadata.json", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "detect_test_2")
  trait_dir <- file.path(test_dir, "trait_002_test")
  dir.create(trait_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create both metadata files with different models
  gapit_metadata <- list(parameters = list(model = "BLINK,FarmCPU"))
  legacy_metadata <- list(parameters = list(model = "MLM"))

  write_json(gapit_metadata, file.path(trait_dir, "gapit_metadata.json"), auto_unbox = TRUE)
  write_json(legacy_metadata, file.path(trait_dir, "metadata.json"), auto_unbox = TRUE)

  result <- detect_models_from_first_trait(test_dir)
  expect_equal(result, c("BLINK", "FarmCPU"))  # From gapit_metadata.json
})

test_that("detect_models_from_first_trait selects first trait consistently", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "detect_test_3")
  dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create multiple trait directories
  for (i in c(3, 1, 2)) {  # Out of order creation
    trait_dir <- file.path(test_dir, sprintf("trait_%03d_test", i))
    dir.create(trait_dir, recursive = TRUE, showWarnings = FALSE)
    metadata <- list(parameters = list(model = paste0("MODEL", i)))
    write_json(metadata, file.path(trait_dir, "metadata.json"), auto_unbox = TRUE)
  }

  result <- detect_models_from_first_trait(test_dir)
  expect_equal(result, "MODEL1")  # trait_001 should be selected (alphabetically first)
})

test_that("detect_models_from_first_trait returns NULL when metadata has no models", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "detect_test_4")
  trait_dir <- file.path(test_dir, "trait_001_test")
  dir.create(trait_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create metadata without model field
  metadata <- list(parameters = list(`PCA.total` = 3))
  write_json(metadata, file.path(trait_dir, "metadata.json"), auto_unbox = TRUE)

  result <- detect_models_from_first_trait(test_dir)
  expect_null(result)
})

# ==============================================================================
# Tests: select_best_trait_dirs() - Basic functionality
# ==============================================================================

test_that("select_best_trait_dirs returns empty for empty input", {
  result <- select_best_trait_dirs(character(0), c("BLINK", "FarmCPU", "MLM"))
  expect_equal(length(result), 0)
})

test_that("select_best_trait_dirs returns all unique traits", {
  temp_base <- tempdir()
  dirs <- c(
    file.path(temp_base, "unique_test", "trait_001_20231101_120000"),
    file.path(temp_base, "unique_test", "trait_002_20231101_120000"),
    file.path(temp_base, "unique_test", "trait_003_20231101_120000")
  )

  for (d in dirs) {
    dir.create(d, showWarnings = FALSE, recursive = TRUE)
    # Add model files
    for (model in c("BLINK", "FarmCPU", "MLM")) {
      file.create(file.path(d, paste0("GAPIT.Association.GWAS_Results.", model, ".trait.csv")))
    }
  }

  on.exit(unlink(file.path(temp_base, "unique_test"), recursive = TRUE))

  result <- select_best_trait_dirs(dirs, c("BLINK", "FarmCPU", "MLM"))

  expect_equal(length(result), 3)
  expect_true(all(dirs %in% result))
})

# ==============================================================================
# Tests: Sourcing modules has no side effects
# ==============================================================================

test_that("sourcing aggregation_utils.R does not execute aggregation", {
  # Re-source and verify no output
  output <- capture.output({
    source(file.path(project_root, "scripts", "lib", "aggregation_utils.R"))
  })

  # Should only have potential path resolution output, not aggregation output
  aggregation_keywords <- c("Scanning", "Found", "trait", "SNP", "aggregat")
  has_aggregation <- any(sapply(aggregation_keywords, function(kw) {
    any(grepl(kw, output, ignore.case = TRUE))
  }))

  expect_false(has_aggregation, info = paste("Unexpected output:", paste(output, collapse = "\n")))
})

test_that("sourcing aggregation_utils.R makes functions available", {
  # Functions should be available after sourcing
  expect_true(exists("extract_models_from_metadata"))
  expect_true(exists("validate_model_names"))
  expect_true(exists("detect_models_from_first_trait"))
  expect_true(exists("get_gapit_param"))
  expect_true(exists("select_best_trait_dirs"))
  expect_true(exists("check_trait_completeness"))
  expect_true(exists("read_filter_file"))

  # Functions should be callable
  expect_type(extract_models_from_metadata, "closure")
  expect_type(validate_model_names, "closure")
  expect_type(detect_models_from_first_trait, "closure")
  expect_type(get_gapit_param, "closure")
  expect_type(select_best_trait_dirs, "closure")
  expect_type(check_trait_completeness, "closure")
  expect_type(read_filter_file, "closure")
})

test_that("aggregation_utils.R functions work without CLI arguments", {
  # Functions should not require any CLI arguments or global state
  # Just calling them with valid parameters should work

  # extract_models_from_metadata - works with just a path
  result1 <- extract_models_from_metadata("/nonexistent/path")
  expect_null(result1)

  # validate_model_names - works with just a vector
  result2 <- validate_model_names(c("BLINK"))
  expect_true(result2$valid)

  # get_gapit_param - works with just a list
  result3 <- get_gapit_param(list(), "test", "test", default = "ok")
  expect_equal(result3, "ok")
})

# ==============================================================================
# Tests: format_duration() edge cases
# ==============================================================================

test_that("format_duration returns N/A for NaN input", {
  expect_equal(format_duration(NaN), "N/A")
})

test_that("format_duration returns N/A for NA input", {
  expect_equal(format_duration(NA), "N/A")
})

test_that("format_duration returns N/A for NULL input", {
  expect_equal(format_duration(NULL), "N/A")
})

test_that("format_duration formats minutes correctly", {
  expect_equal(format_duration(90), "90.0 minutes")
  expect_equal(format_duration(90, "minutes"), "90.0 minutes")
})

test_that("format_duration formats hours correctly", {
  expect_equal(format_duration(1.5, "hours"), "1.5 hours")
})

# ==============================================================================
# Tests: format_pvalue() vector safety
# ==============================================================================

test_that("format_pvalue handles vector input with NA", {
  result <- format_pvalue(c(NA, 1e-5, 3.2e-10))
  expect_type(result, "character")
  expect_equal(length(result), 3)
  expect_equal(result[1], "NA")
  expect_match(result[2], "1\\.00e-05")
  expect_match(result[3], "3\\.20e-10")
})

test_that("format_pvalue handles scalar NA", {
  expect_equal(format_pvalue(NA), "NA")
})

test_that("format_pvalue handles NULL", {
  expect_equal(format_pvalue(NULL), "NA")
})

# ==============================================================================
# Tests: format_number() vector safety
# ==============================================================================

test_that("format_number handles vector input with NA", {
  result <- format_number(c(NA, 42, 1000000))
  expect_type(result, "character")
  expect_equal(length(result), 3)
  expect_equal(result[1], "NA")
  expect_match(result[3], "1,000,000")
})

test_that("format_number handles scalar NA", {
  expect_equal(format_number(NA), "NA")
})

test_that("format_number handles NULL", {
  expect_equal(format_number(NULL), "NA")
})
