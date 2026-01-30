# Design: Refactor collect_results.R for Testability

## Context

The GAPIT3 pipeline requires high confidence in result aggregation correctness. Scientific reproducibility demands that:
1. All aggregation logic is tested
2. Configuration parameters are traceable in outputs
3. Functions can be validated independently

### Stakeholders
- Scientific researchers relying on accurate aggregation
- Pipeline maintainers adding new features (e.g., dynamic-model-detection)
- CI/CD systems running automated tests

### Constraints
- Must not change CLI interface or behavior
- Must preserve all existing functionality
- Must enable TDD for future features
- Metadata must capture all configurables for reproducibility

## Goals / Non-Goals

### Goals
- Extract pure functions into testable modules
- Enable unit testing without script execution
- Preserve backward compatibility
- Capture configuration in output metadata
- Unblock `dynamic-model-detection` implementation

### Non-Goals
- Rewriting aggregation logic (preserve existing behavior)
- Changing output formats
- Adding new CLI options (separate proposal)
- Performance optimization

## Decisions

### Decision 1: Separate lib/ directory for modules

**What**: Create `scripts/lib/` directory for reusable R modules.

**Why**:
- Clear separation between executable scripts and libraries
- Follows R package conventions
- Easy to source in tests without side effects
- Enables future module reuse across scripts

**Alternatives considered**:
- Single file with conditional execution → Fragile, unclear intent
- Full R package → Over-engineered for current needs
- Inline test mocking → Doesn't solve reuse problem

### Decision 2: Constants in separate module

**What**: Extract `KNOWN_GAPIT_MODELS`, `DEFAULT_MODELS` to `scripts/lib/constants.R`.

**Why**:
- Single source of truth for configuration
- Can be imported by multiple scripts
- Easy to update when GAPIT adds models
- Testable independently

### Decision 3: Pure functions with explicit parameters

**What**: All extracted functions must be pure - no global state, all inputs as parameters.

**Why**:
- Deterministic behavior enables reliable testing
- Explicit dependencies improve code clarity
- No hidden state means reproducible results

**Example**:
```r
# Bad: Uses global state
validate_models <- function() {
  # Uses global expected_models variable
  ...
}

# Good: Explicit parameters
validate_model_names <- function(models, known_models = KNOWN_GAPIT_MODELS) {
  # All inputs explicit
  ...
}
```

### Decision 4: Metadata captures all configurables

**What**: Output `summary_stats.json` must include all configuration parameters used.

**Why**:
- Scientific reproducibility requires knowing exact settings
- Enables audit trail for results
- Supports debugging aggregation issues
- Required for FAIR data principles

**Metadata fields**:
```json
{
  "configuration": {
    "expected_models": ["BLINK", "FarmCPU", "MLM"],
    "models_source": "auto-detected",
    "significance_threshold": 5e-8,
    "allow_incomplete": false
  }
}
```

## Module Structure

### scripts/lib/constants.R
```r
# Authoritative list of known GAPIT models
KNOWN_GAPIT_MODELS <- c(
  "BLINK", "FarmCPU", "MLM", "MLMM", "GLM",
  "SUPER", "CMLM", "FarmCPU.LM", "Blink.LM"
)

# Default models when not specified or auto-detected
DEFAULT_MODELS <- c("BLINK", "FarmCPU", "MLM")
DEFAULT_MODELS_STRING <- "BLINK,FarmCPU,MLM"
```

### scripts/lib/aggregation_utils.R
```r
# Source constants
source(file.path(dirname(sys.frame(1)$ofile), "constants.R"))

# Pure functions for aggregation

#' Extract models from metadata file
#' @param metadata_path Path to gapit_metadata.json
#' @return Character vector of model names, or NULL
extract_models_from_metadata <- function(metadata_path) { ... }

#' Validate model names against known models
#' @param models Character vector to validate
#' @param known_models Reference list (default: KNOWN_GAPIT_MODELS)
#' @return List with $valid and $invalid_models
validate_model_names <- function(models, known_models = KNOWN_GAPIT_MODELS) { ... }

#' Detect models from first trait directory
#' @param output_dir Directory containing trait_* subdirectories
#' @return Character vector of models, or NULL
detect_models_from_first_trait <- function(output_dir) { ... }

#' Select best trait directories (deduplication)
#' @param trait_dirs Vector of directory paths
#' @param expected_models Expected model names
#' @return Vector of selected directories
select_best_trait_dirs <- function(trait_dirs, expected_models) { ... }

#' Extract GAPIT parameter with legacy fallback
#' @param metadata Parsed metadata list
#' @param gapit_name V3.0.0 parameter name
#' @param legacy_name V2.0.0 parameter name
#' @param default Default if not found
#' @return Parameter value
get_gapit_param <- function(metadata, gapit_name, legacy_name, default = NULL) { ... }
```

### scripts/collect_results.R (modified)
```r
#!/usr/bin/env Rscript
# Main aggregation script - sources modules

# Load modules
script_dir <- dirname(sys.frame(1)$ofile)
source(file.path(script_dir, "lib", "constants.R"))
source(file.path(script_dir, "lib", "aggregation_utils.R"))

# CLI parsing and execution (unchanged interface)
option_list <- list(...)
opt <- parse_args(opt_parser)

# Use functions from modules
detected <- detect_models_from_first_trait(output_dir)
validation <- validate_model_names(expected_models)
# ... rest of execution
```

## Testing Strategy

### Unit Tests (test-aggregation-utils.R)
```r
# Source modules directly - no script execution
source("scripts/lib/constants.R")
source("scripts/lib/aggregation_utils.R")

test_that("extract_models_from_metadata handles v3.0.0 format", { ... })
test_that("validate_model_names accepts known models", { ... })
test_that("detect_models_from_first_trait finds metadata", { ... })
```

### Integration Tests
- Existing end-to-end tests continue to work
- CLI behavior verified through Docker tests

## Risks / Trade-offs

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing behavior | Medium | High | Comprehensive integration tests before/after |
| Module loading issues | Low | Medium | Test in CI with clean environment |
| Path resolution problems | Low | Low | Use robust path detection (sys.frame) |

## Migration Plan

1. **Create modules** - Extract functions to lib/ (functions currently in collect_results.R)
2. **Update collect_results.R** - Source modules, remove duplicated code
3. **Add unit tests** - Test all extracted functions
4. **Verify integration** - Run end-to-end tests
5. **Update metadata output** - Add configuration section

### Rollback
- Keep original `collect_results.R` in git history
- Modules are additive (can be removed if needed)
- No data migration required

## References

- `scripts/collect_results.R` - Current monolithic script
- `openspec/changes/dynamic-model-detection/` - Blocked feature proposal
- `tests/testthat/` - Existing test infrastructure
