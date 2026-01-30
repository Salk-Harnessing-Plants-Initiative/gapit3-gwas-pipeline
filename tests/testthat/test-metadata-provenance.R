# ==============================================================================
# Tests for Metadata and Provenance Tracking
# ==============================================================================
# Tests for enhanced metadata schema v2.0.0 with provenance
# ==============================================================================

library(testthat)
library(jsonlite)
library(tools)

# Note: helper.R is automatically sourced by testthat

# ==============================================================================
# Source modules directly (preferred approach)
# ==============================================================================

# Get project root (handle different test execution contexts)
.get_project_root <- function() {
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

.project_root <- .get_project_root()

# Source the utility modules
# read_filter_file is now in aggregation_utils.R
source(file.path(.project_root, "scripts", "lib", "constants.R"))
source(file.path(.project_root, "scripts", "lib", "aggregation_utils.R"))

# ==============================================================================
# Helper functions for metadata tests
# ==============================================================================

#' Source the helper functions from run_gwas_single_trait.R
source_gwas_helpers <- function() {
  script_path <- file.path("..", "..", "scripts", "run_gwas_single_trait.R")
  script_lines <- readLines(script_path)

  # Find get_env_or_null function
  get_env_start <- grep("^get_env_or_null <- function", script_lines)[1]
  get_env_end <- grep("^}", script_lines)

  get_env_end <- get_env_end[get_env_end > get_env_start][1]

  # Find compute_file_md5 function
  md5_start <- grep("^compute_file_md5 <- function", script_lines)[1]
  md5_end <- grep("^}", script_lines)
  md5_end <- md5_end[md5_end > md5_start][1]

  # Extract and evaluate function definitions
  if (!is.na(get_env_start)) {
    get_env_code <- paste(script_lines[get_env_start:get_env_end], collapse = "\n")
    eval(parse(text = get_env_code), envir = .GlobalEnv)
  }

  if (!is.na(md5_start)) {
    md5_code <- paste(script_lines[md5_start:md5_end], collapse = "\n")
    eval(parse(text = md5_code), envir = .GlobalEnv)
  }
}

# Source the functions
source_gwas_helpers()

# ==============================================================================
# Test: get_env_or_null() function
# ==============================================================================
test_that("get_env_or_null returns value when set", {
  Sys.setenv(TEST_VAR = "test_value")
  on.exit(Sys.unsetenv("TEST_VAR"))

  result <- get_env_or_null("TEST_VAR")
  expect_equal(result, "test_value")
})

test_that("get_env_or_null returns NULL for empty string", {
  Sys.setenv(TEST_VAR = "")
  on.exit(Sys.unsetenv("TEST_VAR"))

  result <- get_env_or_null("TEST_VAR")
  expect_null(result)
})

test_that("get_env_or_null returns NULL for unset variable", {
  Sys.unsetenv("NONEXISTENT_VAR")

  result <- get_env_or_null("NONEXISTENT_VAR")
  expect_null(result)
})

test_that("get_env_or_null returns NULL for 'null' string", {
  Sys.setenv(TEST_VAR = "null")
  on.exit(Sys.unsetenv("TEST_VAR"))

  result <- get_env_or_null("TEST_VAR")
  expect_null(result)
})

test_that("get_env_or_null returns NULL for 'NULL' string", {
  Sys.setenv(TEST_VAR = "NULL")
  on.exit(Sys.unsetenv("TEST_VAR"))

  result <- get_env_or_null("TEST_VAR")
  expect_null(result)
})

test_that("get_env_or_null returns default when provided", {
  Sys.unsetenv("NONEXISTENT_VAR")

  result <- get_env_or_null("NONEXISTENT_VAR", default = "fallback")
  expect_equal(result, "fallback")
})

# ==============================================================================
# Test: compute_file_md5() function
# ==============================================================================
test_that("compute_file_md5 returns MD5 hash for existing file", {
  # Ensure checksums are not skipped
  old_val <- Sys.getenv("SKIP_INPUT_CHECKSUMS", unset = NA)
  Sys.unsetenv("SKIP_INPUT_CHECKSUMS")
  on.exit({
    if (is.na(old_val)) Sys.unsetenv("SKIP_INPUT_CHECKSUMS")
    else Sys.setenv(SKIP_INPUT_CHECKSUMS = old_val)
  })

  # Create temp file with known content
  temp_file <- tempfile()
  writeLines("test content", temp_file)
  on.exit(unlink(temp_file), add = TRUE)

  result <- compute_file_md5(temp_file)

  expect_type(result, "character")
  expect_equal(nchar(result), 32)  # MD5 is 32 hex characters
})

test_that("compute_file_md5 returns NULL for non-existent file", {
  old_val <- Sys.getenv("SKIP_INPUT_CHECKSUMS", unset = NA)
  Sys.unsetenv("SKIP_INPUT_CHECKSUMS")
  on.exit({
    if (is.na(old_val)) Sys.unsetenv("SKIP_INPUT_CHECKSUMS")
    else Sys.setenv(SKIP_INPUT_CHECKSUMS = old_val)
  })

  result <- compute_file_md5("/nonexistent/path/file.txt")
  expect_null(result)
})

test_that("compute_file_md5 returns NULL when SKIP_INPUT_CHECKSUMS is TRUE", {
  Sys.setenv(SKIP_INPUT_CHECKSUMS = "TRUE")
  on.exit(Sys.unsetenv("SKIP_INPUT_CHECKSUMS"))

  # Create temp file
  temp_file <- tempfile()
  writeLines("test content", temp_file)
  on.exit(unlink(temp_file), add = TRUE)

  result <- compute_file_md5(temp_file)
  expect_null(result)
})

test_that("compute_file_md5 returns NULL when SKIP_INPUT_CHECKSUMS is true (lowercase)", {
  Sys.setenv(SKIP_INPUT_CHECKSUMS = "true")
  on.exit(Sys.unsetenv("SKIP_INPUT_CHECKSUMS"))

  temp_file <- tempfile()
  writeLines("test content", temp_file)
  on.exit(unlink(temp_file), add = TRUE)

  result <- compute_file_md5(temp_file)
  expect_null(result)
})

test_that("compute_file_md5 returns NULL for NULL file path", {
  old_val <- Sys.getenv("SKIP_INPUT_CHECKSUMS", unset = NA)
  Sys.unsetenv("SKIP_INPUT_CHECKSUMS")
  on.exit({
    if (is.na(old_val)) Sys.unsetenv("SKIP_INPUT_CHECKSUMS")
    else Sys.setenv(SKIP_INPUT_CHECKSUMS = old_val)
  })

  result <- compute_file_md5(NULL)
  expect_null(result)
})

test_that("compute_file_md5 produces consistent hash for same content", {
  old_val <- Sys.getenv("SKIP_INPUT_CHECKSUMS", unset = NA)
  Sys.unsetenv("SKIP_INPUT_CHECKSUMS")
  on.exit({
    if (is.na(old_val)) Sys.unsetenv("SKIP_INPUT_CHECKSUMS")
    else Sys.setenv(SKIP_INPUT_CHECKSUMS = old_val)
  })

  temp_file1 <- tempfile()
  temp_file2 <- tempfile()
  writeLines("identical content", temp_file1)
  writeLines("identical content", temp_file2)
  on.exit(unlink(c(temp_file1, temp_file2)), add = TRUE)

  result1 <- compute_file_md5(temp_file1)
  result2 <- compute_file_md5(temp_file2)

  expect_equal(result1, result2)
})

# ==============================================================================
# Test: Metadata schema v2.0.0 structure
# ==============================================================================
test_that("test fixture metadata has schema_version field", {
  fixture_path <- get_fixture_path(file.path("aggregation", "trait_001_single_model", "metadata.json"))
  meta <- fromJSON(fixture_path)

  expect_true("schema_version" %in% names(meta))
  expect_equal(meta$schema_version, "2.0.0")
})

test_that("test fixture metadata has argo section", {
  fixture_path <- get_fixture_path(file.path("aggregation", "trait_001_single_model", "metadata.json"))
  meta <- fromJSON(fixture_path)

  expect_true("argo" %in% names(meta))

  argo <- meta$argo
  expect_true("workflow_name" %in% names(argo))
  expect_true("workflow_uid" %in% names(argo))
  expect_true("namespace" %in% names(argo))
  expect_true("pod_name" %in% names(argo))
  expect_true("node_name" %in% names(argo))
  expect_true("retry_attempt" %in% names(argo))
  expect_true("max_retries" %in% names(argo))
})

test_that("test fixture metadata has container section", {
  fixture_path <- get_fixture_path(file.path("aggregation", "trait_001_single_model", "metadata.json"))
  meta <- fromJSON(fixture_path)

  expect_true("container" %in% names(meta))
  expect_true("image" %in% names(meta$container))
})

test_that("test fixture metadata has input checksums", {
  fixture_path <- get_fixture_path(file.path("aggregation", "trait_001_single_model", "metadata.json"))
  meta <- fromJSON(fixture_path)

  expect_true("inputs" %in% names(meta))

  inputs <- meta$inputs
  expect_true("genotype_file" %in% names(inputs))
  expect_true("genotype_md5" %in% names(inputs))
  expect_true("phenotype_file" %in% names(inputs))
  expect_true("phenotype_md5" %in% names(inputs))
})

test_that("test fixture metadata has thread configuration in parameters", {
  fixture_path <- get_fixture_path(file.path("aggregation", "trait_001_single_model", "metadata.json"))
  meta <- fromJSON(fixture_path)

  expect_true("parameters" %in% names(meta))

  params <- meta$parameters
  expect_true("openblas_threads" %in% names(params))
  expect_true("omp_threads" %in% names(params))
})

# ==============================================================================
# Test: Aggregation reads provenance from metadata
# ==============================================================================
test_that("aggregation can read argo section from metadata", {
  fixture_path <- get_fixture_path(file.path("aggregation", "trait_001_single_model", "metadata.json"))
  meta <- fromJSON(fixture_path)

  # Verify argo section is readable
  expect_equal(meta$argo$workflow_name, "gapit3-gwas-test-abc123")
  expect_equal(meta$argo$namespace, "runai-talmo-lab")
  expect_equal(meta$argo$retry_attempt, 0)
})

test_that("aggregation can track workflow UIDs across traits", {
  fixture_base <- get_fixture_path("aggregation")
  trait_dirs <- c("trait_001_single_model", "trait_002_multi_model", "trait_003_period_in_name")

  workflow_uids <- character(0)

  for (trait_dir in trait_dirs) {
    meta_path <- file.path(fixture_base, trait_dir, "metadata.json")
    if (file.exists(meta_path)) {
      meta <- fromJSON(meta_path)
      if (!is.null(meta$argo) && !is.null(meta$argo$workflow_uid)) {
        if (!(meta$argo$workflow_uid %in% workflow_uids)) {
          workflow_uids <- c(workflow_uids, meta$argo$workflow_uid)
        }
      }
    }
  }

  # All fixtures share same workflow UID
  expect_equal(length(workflow_uids), 1)
  expect_equal(workflow_uids[1], "test-uid-001-0000-0000-000000000001")
})

# ==============================================================================
# Test: Graceful handling of missing provenance fields
# ==============================================================================
test_that("aggregation handles metadata without argo section", {
  # Create temp metadata without argo section (old schema)
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE))

  old_metadata <- list(
    execution = list(
      trait_index = 1,
      status = "success",
      duration_minutes = 15.0
    ),
    trait = list(
      name = "test_trait",
      column_index = 2,
      n_total = 500,
      n_valid = 490,
      n_missing = 10
    ),
    genotype = list(
      n_snps = 1400000,
      n_accessions = 500
    )
  )

  meta_file <- file.path(temp_dir, "metadata.json")
  write_json(old_metadata, meta_file, pretty = TRUE, auto_unbox = TRUE)

  # Read and verify no crash
  meta <- fromJSON(meta_file)

  expect_null(meta$argo)
  expect_null(meta$schema_version)
  expect_null(meta$container)
})

test_that("aggregation handles metadata with null provenance fields", {
  fixture_path <- get_fixture_path(file.path("aggregation", "trait_empty_no_traits", "metadata.json"))
  meta <- fromJSON(fixture_path)

  # ids_file and ids_md5 are null in this fixture
  expect_null(meta$inputs$ids_file)
  expect_null(meta$inputs$ids_md5)
})

# ==============================================================================
# Test: read_filter_file includes trait_dir column
# ==============================================================================

# read_filter_file is sourced from aggregation_utils.R at the top of this file

test_that("read_filter_file includes trait_dir column", {
  fixture_dir <- get_fixture_path(file.path("aggregation", "trait_001_single_model"))

  result <- read_filter_file(fixture_dir, threshold = 5e-8)

  expect_true("trait_dir" %in% colnames(result))
  expect_equal(unique(result$trait_dir), "trait_001_single_model")
})

test_that("aggregated results have trait_dir for provenance", {
  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  fixture_base <- get_fixture_path("aggregation")
  trait_dirs <- c("trait_001_single_model", "trait_002_multi_model")

  for (trait_dir in trait_dirs) {
    src_dir <- file.path(fixture_base, trait_dir)
    dest_dir <- file.path(temp_output, trait_dir)
    dir.create(dest_dir, recursive = TRUE)
    for (file in list.files(src_dir, full.names = TRUE)) {
      file.copy(file, dest_dir)
    }
  }

  # Aggregate
  all_snps <- data.frame()
  for (dir in list.files(temp_output, pattern = "trait_", full.names = TRUE)) {
    trait_snps <- read_filter_file(dir, threshold = 5e-8)
    if (!is.null(trait_snps) && nrow(trait_snps) > 0) {
      all_snps <- rbind(all_snps, trait_snps)
    }
  }

  expect_true("trait_dir" %in% colnames(all_snps))

  # Should have entries from both trait directories
  trait_dirs_in_results <- unique(all_snps$trait_dir)
  expect_true("trait_001_single_model" %in% trait_dirs_in_results)
  expect_true("trait_002_multi_model" %in% trait_dirs_in_results)
})
