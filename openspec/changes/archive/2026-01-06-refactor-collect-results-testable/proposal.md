# Proposal: Refactor collect_results.R for Testability

## Why

The `collect_results.R` script is a monolithic 1000+ line script that mixes:
1. CLI argument parsing and script execution
2. Reusable utility functions
3. Business logic for aggregation

This architecture creates several problems:

1. **Untestable functions**: Functions cannot be unit tested without executing the entire script
2. **No module reuse**: Helper functions (like `get_gapit_param()`, model validation) cannot be imported by other scripts
3. **Blocked features**: The `dynamic-model-detection` proposal requires testable model detection functions
4. **Reproducibility risk**: Without proper tests, aggregation correctness cannot be verified
5. **Maintenance burden**: Changes require manual end-to-end testing

### Current Architecture Problem

```r
# collect_results.R - everything in one file
suppressPackageStartupMessages({ library(...) })
option_list <- list(...)                    # CLI parsing
opt <- parse_args(opt_parser)               # Executes immediately
output_dir <- opt$`output-dir`              # Global state

# Functions defined mid-script
get_gapit_param <- function(...) { ... }
select_best_trait_dirs <- function(...) { ... }

# More execution code
cat("Scanning for trait results...\n")
# ... 500+ more lines of execution
```

**Problem**: Sourcing this file to test `get_gapit_param()` would execute the entire script.

## What Changes

- **ADDED**: New `scripts/lib/aggregation_utils.R` module with reusable functions
- **MODIFIED**: `collect_results.R` to source the module and remain executable
- **ADDED**: Proper unit tests for all extracted functions
- **ADDED**: Constants module for KNOWN_GAPIT_MODELS and defaults

## Impact

- **Affected specs**: `results-aggregation`
- **Affected code**:
  - `scripts/collect_results.R` (refactored to use modules)
  - `scripts/lib/aggregation_utils.R` (new - extracted functions)
  - `scripts/lib/constants.R` (new - shared constants)
  - `tests/testthat/test-aggregation-utils.R` (new - unit tests)
- **Backward compatibility**: Full - `collect_results.R` CLI interface unchanged
- **Enables**: `dynamic-model-detection` and future TDD features

## Proposed Architecture

```
scripts/
├── collect_results.R           # Main script (sources modules, handles CLI)
└── lib/
    ├── constants.R             # KNOWN_GAPIT_MODELS, DEFAULT_MODELS
    └── aggregation_utils.R     # Extracted pure functions

tests/testthat/
├── test-aggregation-utils.R    # Unit tests for extracted functions
└── fixtures/metadata/          # Test fixtures
```

### Module Design Principles

1. **Pure functions**: No side effects, deterministic outputs
2. **Explicit dependencies**: All inputs passed as parameters
3. **Testable in isolation**: Can be sourced without executing script
4. **Metadata preservation**: All configurables saved to output metadata

## Success Criteria

- [ ] All functions in `aggregation_utils.R` can be sourced independently
- [ ] Unit tests pass for all extracted functions
- [ ] `collect_results.R` CLI behavior unchanged
- [ ] Metadata includes all configuration parameters used
- [ ] `dynamic-model-detection` tests can import functions properly
- [ ] No regressions in existing aggregation functionality
