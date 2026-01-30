# test-gapit-parameters.R
# TDD tests for GAPIT parameter handling and schema v3.0.0
#
# These tests verify:
# 1. get_gapit_param() helper reads v3.0.0 schema correctly
# 2. get_gapit_param() falls back to v2.0.0 legacy schema
# 3. generate_configuration_section() uses GAPIT native names
# 4. generate_configuration_section() groups parameters correctly

library(testthat)

# ==============================================================================
# Source modules directly (per OpenSpec design - no script execution)
# ==============================================================================
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

# Source the modules (pure functions, no side effects)
# All functions are now in the modules - no script sourcing needed
source(file.path(.project_root, "scripts", "lib", "constants.R"))
source(file.path(.project_root, "scripts", "lib", "aggregation_utils.R"))

# Get fixture path helper
get_fixture_path <- function(fixture_name) {
  # Try multiple possible locations
  paths <- c(
    file.path("fixtures", "gapit_params", fixture_name, "metadata.json"),
    file.path("tests", "fixtures", "gapit_params", fixture_name, "metadata.json"),
    file.path("..", "fixtures", "gapit_params", fixture_name, "metadata.json")
  )

  for (path in paths) {
    if (file.exists(path)) return(path)
  }

  stop(paste("Fixture not found:", fixture_name))
}

# =============================================================================
# Tests for get_gapit_param() helper function
# =============================================================================

test_that("get_gapit_param reads v3.0.0 schema correctly", {
  # get_gapit_param is now available from aggregation_utils.R module

  # Load v3 fixture
  metadata <- jsonlite::fromJSON(get_fixture_path("v3_full"), simplifyVector = TRUE)

  # Test reading GAPIT parameters from v3.0.0 schema
  expect_equal(
    get_gapit_param(metadata, "model", "models", NULL),
    c("BLINK", "FarmCPU", "MLM")
  )
  expect_equal(
    get_gapit_param(metadata, "PCA.total", "pca_components", NULL),
    3

)
  expect_equal(
    get_gapit_param(metadata, "SNP.MAF", "maf_filter", NULL),
    0.0073
  )
  expect_equal(
    get_gapit_param(metadata, "SNP.FDR", "snp_fdr", NULL),
    0.05
  )
  expect_equal(
    get_gapit_param(metadata, "kinship.algorithm", NULL, NULL),
    "VanRaden"
  )
})

test_that("get_gapit_param falls back to v2.0.0 legacy schema", {
  # get_gapit_param is now available from aggregation_utils.R module

  # Load v2 legacy fixture
  metadata <- jsonlite::fromJSON(get_fixture_path("v2_legacy"), simplifyVector = TRUE)

  # Test reading from legacy schema (no parameters.gapit section)
  expect_equal(
    get_gapit_param(metadata, "model", "models", NULL),
    c("BLINK", "FarmCPU")
  )
  expect_equal(
    get_gapit_param(metadata, "PCA.total", "pca_components", NULL),
    3
  )
  expect_equal(
    get_gapit_param(metadata, "SNP.MAF", "maf_filter", NULL),
    0.05
  )
})

test_that("get_gapit_param returns default when parameter missing", {
  # get_gapit_param is now available from aggregation_utils.R module

  # Load v3 minimal fixture (missing optional params)
  metadata <- jsonlite::fromJSON(get_fixture_path("v3_minimal"), simplifyVector = TRUE)

  # Test that missing parameters return default
  expect_null(
    get_gapit_param(metadata, "kinship.algorithm", NULL, NULL)
  )
  expect_equal(
    get_gapit_param(metadata, "kinship.algorithm", NULL, "Zhang"),
    "Zhang"
  )
})

# =============================================================================
# Tests for generate_configuration_section()
# =============================================================================

test_that("generate_configuration_section uses GAPIT native names", {
  # generate_configuration_section is sourced at top of file

  metadata <- jsonlite::fromJSON(get_fixture_path("v3_full"), simplifyVector = TRUE)
  summary_table <- data.frame(n_snps = 287000, n_samples = 1135)

  output <- generate_configuration_section(metadata, summary_table)

  # Should use GAPIT native parameter names (with dots)
  expect_match(output, "model", fixed = TRUE)
  expect_match(output, "PCA.total", fixed = TRUE)
  expect_match(output, "SNP.MAF", fixed = TRUE)
  expect_match(output, "SNP.FDR", fixed = TRUE)

  # Should NOT use old parameter names
  expect_false(grepl("Models", output, fixed = TRUE))
  expect_false(grepl("PCA Components", output, fixed = TRUE))
  expect_false(grepl("MAF Filter", output, fixed = TRUE))
})

test_that("generate_configuration_section groups parameters correctly", {
  # generate_configuration_section is sourced at top of file

  metadata <- jsonlite::fromJSON(get_fixture_path("v3_full"), simplifyVector = TRUE)
  summary_table <- data.frame(n_snps = 287000, n_samples = 1135)

  output <- generate_configuration_section(metadata, summary_table)

  # Should have grouped sections
  expect_match(output, "### GAPIT Parameters", fixed = TRUE)
  expect_match(output, "### Filtering", fixed = TRUE)
  expect_match(output, "### Data", fixed = TRUE)
})

test_that("generate_configuration_section shows optional parameters when present", {
  # generate_configuration_section is sourced at top of file

  metadata <- jsonlite::fromJSON(get_fixture_path("v3_full"), simplifyVector = TRUE)
  summary_table <- data.frame(n_snps = 287000, n_samples = 1135)

  output <- generate_configuration_section(metadata, summary_table)

  # Should include optional GAPIT parameters from v3_full fixture
  expect_match(output, "kinship.algorithm", fixed = TRUE)
  expect_match(output, "VanRaden", fixed = TRUE)
  expect_match(output, "SNP.effect", fixed = TRUE)
  expect_match(output, "SNP.impute", fixed = TRUE)
})

test_that("generate_configuration_section works with v2 legacy metadata", {
  # generate_configuration_section is sourced at top of file

  metadata <- jsonlite::fromJSON(get_fixture_path("v2_legacy"), simplifyVector = TRUE)
  summary_table <- data.frame(n_snps = 287000, n_samples = 1135)

  # Should not error on v2 legacy metadata
  output <- generate_configuration_section(metadata, summary_table)

  # Should still produce valid output
  expect_true(nchar(output) > 0)
  expect_match(output, "## Configuration", fixed = TRUE)
})
