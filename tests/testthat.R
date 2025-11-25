#!/usr/bin/env Rscript
# ==============================================================================
# Test Runner for GAPIT3 GWAS Pipeline
# ==============================================================================
# Executes all unit tests using testthat framework
# ==============================================================================

library(testthat)

# Set working directory to project root
if (basename(getwd()) == "tests") {
  setwd("..")
}

# Run all tests
test_check("gapit3-gwas-pipeline", reporter = "progress")
