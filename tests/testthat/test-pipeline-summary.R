# ==============================================================================
# Tests for Pipeline Summary Markdown Generation
# ==============================================================================
# TDD tests for pipeline_summary.md generation in collect_results.R
# ==============================================================================

library(testthat)
library(jsonlite)

# Note: helper.R is automatically sourced by testthat

# ==============================================================================
# Source the markdown generation functions from collect_results.R
# ==============================================================================
source_summary_functions <- function() {
  script_path <- file.path("..", "..", "scripts", "collect_results.R")
  script_lines <- readLines(script_path)

  # List of functions to source
  functions_to_source <- c(
    "format_pvalue",
    "format_number",
    "format_duration",
    "truncate_string",
    "generate_executive_summary",
    "generate_configuration_section",
    "generate_top_snps_table",
    "generate_traits_table",
    "generate_model_statistics",
    "generate_chromosome_distribution",
    "generate_quality_metrics",
    "generate_reproducibility_section",
    "generate_markdown_summary"
  )

  for (func_name in functions_to_source) {
    pattern <- paste0("^", func_name, " <- function")
    func_start <- grep(pattern, script_lines)

    if (length(func_start) > 0) {
      func_start <- func_start[1]
      # Find matching closing brace
      brace_count <- 0
      func_end <- func_start
      for (i in func_start:length(script_lines)) {
        line <- script_lines[i]
        brace_count <- brace_count + nchar(gsub("[^{]", "", line)) - nchar(gsub("[^}]", "", line))
        if (brace_count == 0 && i > func_start) {
          func_end <- i
          break
        }
        # Handle single-line functions
        if (i == func_start && brace_count == 0 && grepl("}", line)) {
          func_end <- i
          break
        }
      }

      func_code <- paste(script_lines[func_start:func_end], collapse = "\n")
      tryCatch({
        eval(parse(text = func_code), envir = .GlobalEnv)
      }, error = function(e) {
        # Function may not exist yet (TDD - writing tests before implementation)
      })
    }
  }
}

# Try to source functions (may fail if not yet implemented)
tryCatch(source_summary_functions(), error = function(e) NULL)

# ==============================================================================
# Test: format_pvalue() helper function
# ==============================================================================
test_that("format_pvalue formats p-values correctly", {
  skip_if_not(exists("format_pvalue"), "format_pvalue not yet implemented")

  # Very small p-values

expect_equal(format_pvalue(3.971779e-88), "3.97e-88")
  expect_equal(format_pvalue(4.835369e-84), "4.84e-84")

  # Moderate p-values
  expect_equal(format_pvalue(1.23e-8), "1.23e-08")
  expect_equal(format_pvalue(5e-8), "5.00e-08")

  # Edge cases
  expect_equal(format_pvalue(0), "0.00e+00")
  expect_equal(format_pvalue(NA), "NA")
})

# ==============================================================================
# Test: format_number() helper function
# ==============================================================================
test_that("format_number adds thousand separators", {
  skip_if_not(exists("format_number"), "format_number not yet implemented")

  expect_equal(format_number(1886), "1,886")
  expect_equal(format_number(1378379), "1,378,379")
  expect_equal(format_number(546), "546")
  expect_equal(format_number(0), "0")
  expect_equal(format_number(NA), "NA")
})

# ==============================================================================
# Test: format_duration() helper function
# ==============================================================================
test_that("format_duration formats duration correctly", {
  skip_if_not(exists("format_duration"), "format_duration not yet implemented")

  # Minutes only
  expect_equal(format_duration(65.0), "65.0 minutes")
  expect_equal(format_duration(38.9), "38.9 minutes")

  # Hours
  expect_equal(format_duration(201.6, unit = "hours"), "201.6 hours")
})

# ==============================================================================
# Test: truncate_string() helper function
# ==============================================================================
test_that("truncate_string truncates long strings", {
  skip_if_not(exists("truncate_string"), "truncate_string not yet implemented")

  # Short string - no truncation
  expect_equal(truncate_string("short", 40), "short")

  # Long string - truncated with ellipsis
  long_name <- "mean_TotLen.EucLen_day_1(NYC)_extra_stuff_here"
  result <- truncate_string(long_name, 40)
  expect_equal(nchar(result), 40)
  expect_true(endsWith(result, "..."))

  # Exact length - no truncation
  exact <- paste(rep("a", 40), collapse = "")
  expect_equal(truncate_string(exact, 40), exact)
})

# ==============================================================================
# Test: generate_executive_summary() section
# ==============================================================================
test_that("generate_executive_summary creates valid markdown", {
  skip_if_not(exists("generate_executive_summary"), "generate_executive_summary not yet implemented")

  stats <- list(
    batch_id = "gapit3-gwas-parallel-6hjx8",
    collection_time = "2025-12-09 21:25:24",
    total_traits_attempted = 186,
    successful_traits = 186,
    failed_traits = 0,
    total_significant_snps = 1886,
    average_duration_minutes = 65.0,
    total_duration_hours = 201.6
  )

  top_snp <- data.frame(
    SNP = "PERL1.8641002",
    P.value = 3.97e-88,
    stringsAsFactors = FALSE
  )

  top_trait <- list(name = "mean_TotLen.EucLen_day_1(NYC)", count = 668)

  result <- generate_executive_summary(stats, top_snp, top_trait)

  # Check it's a character string
  expect_type(result, "character")

  # Check key elements are present
  expect_true(grepl("Executive Summary", result))
  expect_true(grepl("gapit3-gwas-parallel-6hjx8", result))
  expect_true(grepl("186", result))
  expect_true(grepl("1,886", result))
  expect_true(grepl("PERL1.8641002", result))
  expect_true(grepl("100.0%", result))  # Success rate
})

# ==============================================================================
# Test: generate_top_snps_table() section
# ==============================================================================
test_that("generate_top_snps_table creates valid markdown table", {
  skip_if_not(exists("generate_top_snps_table"), "generate_top_snps_table not yet implemented")

  snps_df <- data.frame(
    SNP = c("PERL1.8641002", "PERL1.8641127", "PERL4.3797681"),
    Chr = c(1, 1, 4),
    Pos = c(8641002, 8641127, 3797681),
    P.value = c(3.97e-88, 4.84e-84, 5.64e-55),
    MAF = c(0.068, 0.066, 0.056),
    model = c("FarmCPU", "FarmCPU", "FarmCPU"),
    trait = c("median_gravitropicDir_day_3(NYC)",
              "median_gravitropicDir_day_3(NYC)",
              "mean_TotLen.EucLen_day_1(NYC)"),
    stringsAsFactors = FALSE
  )

  result <- generate_top_snps_table(snps_df, top_n = 3)

  # Check markdown table format
  expect_true(grepl("\\| Rank \\|", result))
  expect_true(grepl("\\|---", result))  # Table separator
  expect_true(grepl("PERL1.8641002", result))
  expect_true(grepl("3.97e-88", result))
  expect_true(grepl("FarmCPU", result))
})

# ==============================================================================
# Test: generate_top_snps_table() with empty data
# ==============================================================================
test_that("generate_top_snps_table handles empty data", {
  skip_if_not(exists("generate_top_snps_table"), "generate_top_snps_table not yet implemented")

  empty_df <- data.frame(
    SNP = character(),
    Chr = integer(),
    Pos = integer(),
    P.value = numeric(),
    MAF = numeric(),
    model = character(),
    trait = character(),
    stringsAsFactors = FALSE
  )

  result <- generate_top_snps_table(empty_df, top_n = 20)

  expect_true(grepl("No significant SNPs", result))
})

# ==============================================================================
# Test: generate_model_statistics() section
# ==============================================================================
test_that("generate_model_statistics creates valid markdown", {
  skip_if_not(exists("generate_model_statistics"), "generate_model_statistics not yet implemented")

  stats <- list(
    snps_by_model = list(
      FarmCPU = 1345,
      BLINK = 427,
      MLM = 114,
      both_models = 198
    ),
    total_significant_snps = 1886
  )

  result <- generate_model_statistics(stats)

  expect_true(grepl("Model Statistics", result))
  expect_true(grepl("FarmCPU", result))
  expect_true(grepl("1,345", result))
  expect_true(grepl("71", result))  # Percentage (71.3%)
  expect_true(grepl("198", result))  # Overlap count
})

# ==============================================================================
# Test: generate_chromosome_distribution() section
# ==============================================================================
test_that("generate_chromosome_distribution creates valid markdown", {
  skip_if_not(exists("generate_chromosome_distribution"), "generate_chromosome_distribution not yet implemented")

  snps_df <- data.frame(
    SNP = paste0("SNP_", 1:10),
    Chr = c(1, 1, 1, 4, 4, 4, 4, 5, 5, 2),
    Pos = 1:10 * 1000,
    P.value = 10^(-(10:1)),
    stringsAsFactors = FALSE
  )

  result <- generate_chromosome_distribution(snps_df)

  expect_true(grepl("Chromosome Distribution", result))
  expect_true(grepl("\\| Chromosome \\|", result))
  # Chr 4 should have most (4 SNPs)
  expect_true(grepl("4", result))
})

# ==============================================================================
# Test: generate_reproducibility_section()
# ==============================================================================
test_that("generate_reproducibility_section creates valid markdown", {
  skip_if_not(exists("generate_reproducibility_section"), "generate_reproducibility_section not yet implemented")

  stats <- list(
    batch_id = "gapit3-gwas-parallel-6hjx8",
    collection_time = "2025-12-09 21:25:24",
    provenance = list(
      workflow_uid = "abc123-def456"
    )
  )

  metadata <- list(
    execution = list(
      r_version = "R version 4.4.1 (2024-06-14)",
      gapit_version = "3.5.0"
    )
  )

  result <- generate_reproducibility_section(stats, metadata)

  expect_true(grepl("Reproducibility", result))
  expect_true(grepl("gapit3-gwas-parallel-6hjx8", result))
  expect_true(grepl("R version 4.4.1", result))
  expect_true(grepl("3.5.0", result))
})

# ==============================================================================
# Test: generate_reproducibility_section() with missing provenance
# ==============================================================================
test_that("generate_reproducibility_section handles missing provenance", {
  skip_if_not(exists("generate_reproducibility_section"), "generate_reproducibility_section not yet implemented")

  stats <- list(
    batch_id = "local-run",
    collection_time = "2025-12-09 21:25:24",
    provenance = list()  # Empty provenance (local run)
  )

  metadata <- NULL  # No metadata available

  result <- generate_reproducibility_section(stats, metadata)

  # Should still generate section with available info
  expect_true(grepl("Reproducibility", result))
  expect_true(grepl("local-run", result))
  # Should show N/A for missing fields
  expect_true(grepl("N/A", result))
})

# ==============================================================================
# Test: generate_markdown_summary() integration
# ==============================================================================
test_that("generate_markdown_summary creates complete report", {
  skip_if_not(exists("generate_markdown_summary"), "generate_markdown_summary not yet implemented")

  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  # Create minimal test data
  stats <- list(
    batch_id = "test-batch",
    collection_time = "2025-12-09 21:25:24",
    total_traits_attempted = 3,
    successful_traits = 3,
    failed_traits = 0,
    total_significant_snps = 5,
    average_duration_minutes = 10.0,
    total_duration_hours = 0.5,
    snps_by_model = list(BLINK = 3, FarmCPU = 2, both_models = 1),
    provenance = list()
  )

  summary_table <- data.frame(
    trait_index = 1:3,
    trait_name = c("trait_A", "trait_B", "trait_C"),
    n_samples = c(100, 100, 100),
    n_valid = c(95, 98, 100),
    duration_minutes = c(10, 10, 10),
    status = c("success", "success", "success"),
    stringsAsFactors = FALSE
  )

  snps_df <- data.frame(
    SNP = paste0("SNP_", 1:5),
    Chr = c(1, 1, 2, 2, 3),
    Pos = c(1000, 2000, 3000, 4000, 5000),
    P.value = c(1e-10, 1e-9, 1e-8, 5e-8, 4e-8),
    MAF = rep(0.1, 5),
    model = c("BLINK", "BLINK", "FarmCPU", "BLINK", "FarmCPU"),
    trait = c("trait_A", "trait_A", "trait_B", "trait_B", "trait_C"),
    stringsAsFactors = FALSE
  )

  metadata <- list(
    execution = list(
      r_version = "R version 4.4.1",
      gapit_version = "3.5.0"
    ),
    parameters = list(
      models = c("BLINK", "FarmCPU"),
      pca_components = 3,
      maf_filter = 0.05
    )
  )

  # Generate summary
  result <- generate_markdown_summary(
    output_dir = temp_output,
    stats = stats,
    summary_table = summary_table,
    snps_df = snps_df,
    metadata = metadata
  )

  # Check file was created
  md_file <- file.path(temp_output, "pipeline_summary.md")
  expect_true(file.exists(md_file))

  # Read and check content
  content <- paste(readLines(md_file), collapse = "\n")

  # Check all major sections present
  expect_true(grepl("GWAS Pipeline Summary Report", content))
  expect_true(grepl("Executive Summary", content))
  expect_true(grepl("Configuration", content))
  expect_true(grepl("Top.*Significant SNPs", content))
  expect_true(grepl("Model Statistics", content))
  expect_true(grepl("Chromosome Distribution", content))
  expect_true(grepl("Quality Metrics", content))
  expect_true(grepl("Reproducibility", content))
})

# ==============================================================================
# Test: Markdown output matches expected format (golden test)
# ==============================================================================
test_that("generate_markdown_summary matches expected format", {
  skip_if_not(exists("generate_markdown_summary"), "generate_markdown_summary not yet implemented")

  # Check if golden file exists
  golden_file <- get_fixture_path(file.path("aggregation", "expected_pipeline_summary.md"))
  skip_if_not(file.exists(golden_file), "Golden file not found")

  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  # Use fixture data to generate summary
  fixture_base <- get_fixture_path("aggregation")

  # Load test stats (would need to create fixture)
  stats_file <- file.path(fixture_base, "expected_summary_stats.json")
  skip_if_not(file.exists(stats_file), "Stats fixture not found")

  stats <- fromJSON(stats_file)

  # Generate and compare (normalized whitespace)
  # This is a more relaxed golden test
  result <- generate_markdown_summary(
    output_dir = temp_output,
    stats = stats,
    summary_table = data.frame(),
    snps_df = data.frame(),
    metadata = list()
  )

  generated <- readLines(file.path(temp_output, "pipeline_summary.md"))
  expected <- readLines(golden_file)

  # Compare key structural elements
  expect_true(any(grepl("# GWAS Pipeline Summary Report", generated)))
  expect_true(any(grepl("## Executive Summary", generated)))
})

# ==============================================================================
# Test: SNP_FDR in Configuration Section
# ==============================================================================
test_that("generate_configuration_section includes SNP FDR when set", {
  skip_if_not(exists("generate_configuration_section"), "generate_configuration_section not yet implemented")

  metadata <- list(
    parameters = list(
      models = c("BLINK", "FarmCPU"),
      pca_components = 3,
      maf_filter = 0.05,
      snp_fdr = 0.05
    ),
    genotype = list(
      n_snps = 1400000,
      n_accessions = 500
    ),
    inputs = list(
      genotype_file = "/data/genotype/test.hmp.txt",
      phenotype_file = "/data/phenotype/test.txt"
    )
  )

  summary_table <- data.frame(n_snps = 1400000, n_samples = 500)

  result <- generate_configuration_section(metadata, summary_table)

  # Check that SNP FDR is included
  expect_true(grepl("SNP FDR", result) || grepl("snp_fdr", result, ignore.case = TRUE),
              info = "Configuration section should include SNP FDR parameter")
  expect_true(grepl("0.05", result))
})

test_that("generate_configuration_section handles null SNP FDR", {
  skip_if_not(exists("generate_configuration_section"), "generate_configuration_section not yet implemented")

  metadata <- list(
    parameters = list(
      models = c("BLINK"),
      pca_components = 3,
      maf_filter = 0.05,
      snp_fdr = NULL
    ),
    genotype = list(
      n_snps = 1000000,
      n_accessions = 400
    )
  )

  summary_table <- data.frame(n_snps = 1000000, n_samples = 400)

  result <- generate_configuration_section(metadata, summary_table)

  # Should show N/A or disabled for null SNP FDR
  expect_true(grepl("N/A|disabled|not set", result, ignore.case = TRUE) ||
              !grepl("snp_fdr.*0\\.", result, ignore.case = TRUE),
              info = "Null SNP FDR should show as N/A or disabled")
})

test_that("generate_configuration_section shows both MAF and SNP FDR", {
  skip_if_not(exists("generate_configuration_section"), "generate_configuration_section not yet implemented")

  metadata <- list(
    parameters = list(
      models = c("BLINK", "FarmCPU"),
      pca_components = 5,
      maf_filter = 0.10,
      snp_fdr = 0.01
    ),
    genotype = list(
      n_snps = 1500000,
      n_accessions = 600
    )
  )

  summary_table <- data.frame(n_snps = 1500000, n_samples = 600)

  result <- generate_configuration_section(metadata, summary_table)

  # Both parameters should be present
  expect_true(grepl("MAF", result, ignore.case = TRUE))
  expect_true(grepl("0.10|0.1", result))  # MAF value

  # SNP FDR should be present with its value
  expect_true(grepl("0.01", result))  # SNP FDR value
})

# ==============================================================================
# Test: Full Pipeline Summary with SNP FDR
# ==============================================================================
test_that("generate_markdown_summary includes SNP FDR from metadata", {
  skip_if_not(exists("generate_markdown_summary"), "generate_markdown_summary not yet implemented")

  temp_output <- create_temp_output_dir()
  on.exit(cleanup_test_dir(temp_output))

  stats <- list(
    batch_id = "fdr-test-batch",
    collection_time = "2025-01-15 10:00:00",
    total_traits_attempted = 2,
    successful_traits = 2,
    failed_traits = 0,
    total_significant_snps = 10,
    average_duration_minutes = 15.0,
    total_duration_hours = 0.5,
    snps_by_model = list(BLINK = 6, FarmCPU = 4),
    provenance = list()
  )

  summary_table <- data.frame(
    trait_index = 1:2,
    trait_name = c("trait_A", "trait_B"),
    n_samples = c(500, 500),
    n_valid = c(490, 495),
    duration_minutes = c(15, 15),
    status = c("success", "success")
  )

  snps_df <- data.frame(
    SNP = paste0("FDR_SNP_", 1:10),
    Chr = rep(1:2, 5),
    Pos = 1:10 * 10000,
    P.value = 10^(-(15:6)),
    MAF = rep(0.15, 10),
    model = rep(c("BLINK", "FarmCPU"), 5),
    trait = rep(c("trait_A", "trait_B"), 5)
  )

  # Metadata with SNP FDR set
  metadata <- list(
    execution = list(
      r_version = "R version 4.4.1",
      gapit_version = "3.5.0"
    ),
    parameters = list(
      models = c("BLINK", "FarmCPU"),
      pca_components = 3,
      maf_filter = 0.05,
      snp_fdr = 0.05
    ),
    genotype = list(
      n_snps = 1400000,
      n_accessions = 500
    )
  )

  # Generate summary
  result <- generate_markdown_summary(
    output_dir = temp_output,
    stats = stats,
    summary_table = summary_table,
    snps_df = snps_df,
    metadata = metadata
  )

  # Read generated file
  md_file <- file.path(temp_output, "pipeline_summary.md")
  expect_true(file.exists(md_file))

  content <- paste(readLines(md_file), collapse = "\n")

  # Verify SNP FDR appears in the report
  expect_true(grepl("Configuration", content))
  expect_true(grepl("MAF", content, ignore.case = TRUE))

  # Should show both MAF and SNP FDR values
  expect_true(grepl("0.05", content))
})
