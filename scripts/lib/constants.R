# ==============================================================================
# GAPIT3 Pipeline Constants
# ==============================================================================
# Authoritative constants for GAPIT model configuration.
# This file should be sourced by modules that need model definitions.
#
# To update when GAPIT adds new models:
# 1. Add the new model name to KNOWN_GAPIT_MODELS
# 2. Run tests to verify no regressions
# 3. Update documentation if needed
# ==============================================================================

#' Known GAPIT statistical models
#'
#' Authoritative list of all GAPIT models supported by the pipeline.
#' Used for validation of user input and auto-detection from metadata.
#'
#' Models are case-sensitive and must match GAPIT's internal naming.
#' Compound models (e.g., FarmCPU.LM) use period as separator.
#'
#' @seealso https://github.com/jiabowang/GAPIT3 for model documentation
KNOWN_GAPIT_MODELS <- c(
  "BLINK",
  "FarmCPU",
  "MLM",
  "MLMM",
  "GLM",
  "SUPER",
  "CMLM",
  "FarmCPU.LM",
  "Blink.LM"
)

#' Default models when not specified or auto-detected
#'
#' Used when:
#' - CLI --models flag not provided
#' - Auto-detection from metadata fails
#' - Backward compatibility with pre-metadata workflows
DEFAULT_MODELS <- c("BLINK", "FarmCPU", "MLM")

#' Default models as comma-separated string (for CLI default)
DEFAULT_MODELS_STRING <- "BLINK,FarmCPU,MLM"
