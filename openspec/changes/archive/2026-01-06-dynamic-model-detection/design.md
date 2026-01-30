# Design: Dynamic Model Detection from Workflow Metadata

## Context

The GAPIT3 GWAS pipeline supports multiple statistical models (BLINK, FarmCPU, MLM, etc.). The `collect_results.R` aggregation script needs to know which models to expect when checking trait completeness. Currently, this relies on hardcoded defaults that may not match the actual workflow configuration.

### Stakeholders
- Scientific researchers running GWAS workflows with various model combinations
- Pipeline maintainers ensuring aggregation correctness
- CI/CD systems validating workflow outputs

### Constraints
- Must maintain backward compatibility with existing `--models` flag
- Must not significantly increase aggregation runtime
- Must handle missing or malformed metadata gracefully

## Goals / Non-Goals

### Goals
- Auto-detect expected models from workflow metadata when CLI flag not specified
- Single source of truth for known GAPIT models (eliminate duplicate lists)
- Clear console output indicating detection vs specification
- TDD approach ensuring correctness before deployment

### Non-Goals
- Changing the metadata format (use existing `gapit_metadata.json`)
- Supporting model detection across mixed-model workflows (all traits use same models)
- GUI or interactive model selection

## Decisions

### Decision 1: Read First Trait's Metadata Only

**What**: Extract model configuration from the first trait directory's `gapit_metadata.json`.

**Why**:
- All traits in a workflow share the same model configuration
- O(1) file read vs O(n) for n traits
- Metadata already written as part of existing provenance tracking

**Alternatives considered**:
- Read all metadata and find consensus → O(n), overkill for consistent configs
- Parse workflow YAML directly → Different path structure, less portable
- Add new CLI-required parameter → Breaks backward compatibility

### Decision 2: Fallback to CLI Default with Warning

**What**: If metadata unavailable or unparseable, fall back to the existing default `"BLINK,FarmCPU,MLM"` with a warning message.

**Why**:
- Maintains backward compatibility for workflows without metadata
- Explicit warning alerts user to potential mismatch
- Fail-open behavior appropriate for aggregation (not security-critical)

**Alternatives considered**:
- Fail hard when metadata missing → Too disruptive
- Require metadata always → Breaks existing workflows
- Silent fallback → User unaware of potential issue

### Decision 3: Case-Insensitive Model Validation

**What**: Validate model names case-insensitively against known GAPIT models.

**Why**:
- GAPIT is case-sensitive but users may specify "blink" vs "BLINK"
- Prevents false negatives in validation
- Canonical form used internally for consistency

**Alternatives considered**:
- Case-sensitive strict matching → Fragile, user-unfriendly
- No validation → Silent failures with typos

### Decision 4: Single KNOWN_GAPIT_MODELS Constant

**What**: Define one authoritative list of known models at the top of `collect_results.R`.

**Why**:
- Eliminates current inconsistency between lines 46 and 894-895
- Single place to update when GAPIT adds new models
- Clear documentation of supported models

## Data Flow

```
┌─────────────────────┐
│   CLI Arguments     │
│  --models "X,Y,Z"   │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐     ┌─────────────────────────────┐
│  Models specified?  │ No  │  Read first trait's         │
│                     ├────►│  gapit_metadata.json        │
└─────────┬───────────┘     └─────────────┬───────────────┘
          │ Yes                           │
          │                               ▼
          │               ┌─────────────────────────────┐
          │               │  extract_models_from_       │
          │               │  metadata()                  │
          │               └─────────────┬───────────────┘
          │                             │
          │                   ┌─────────┴─────────┐
          │                   │                   │
          │               Found             Not found
          │                   │                   │
          │                   ▼                   ▼
          │         ┌─────────────┐    ┌──────────────────┐
          │         │  Detected   │    │  Use CLI default │
          │         │  models     │    │  + emit warning  │
          │         └──────┬──────┘    └────────┬─────────┘
          │                │                    │
          └────────────────┴────────────────────┘
                           │
                           ▼
                ┌─────────────────────┐
                │ validate_model_     │
                │ names()             │
                └─────────┬───────────┘
                          │
                          ▼
                ┌─────────────────────┐
                │ select_best_trait_  │
                │ dirs() with models  │
                └─────────────────────┘
```

## API Design

### New Functions

```r
#' Extract expected models from trait metadata
#' @param metadata_path Path to gapit_metadata.json
#' @return Character vector of model names, or NULL if unavailable
extract_models_from_metadata <- function(metadata_path) { ... }

#' Validate model names against known GAPIT models
#' @param models Character vector of model names
#' @return List with $valid (logical) and $invalid_models (character vector)
validate_model_names <- function(models) { ... }
```

### New Constant

```r
# Authoritative list of known GAPIT models
KNOWN_GAPIT_MODELS <- c(
  "BLINK", "FarmCPU", "MLM", "MLMM", "GLM",
  "SUPER", "CMLM", "FarmCPU.LM", "Blink.LM"
)
```

### Modified Behavior

```r
# Before: Always use opt$models
expected_models <- strsplit(opt$models, ",")[[1]]

# After: Auto-detect if default
if (opt$models == "BLINK,FarmCPU,MLM") {  # Default value
  detected <- detect_models_from_first_trait(output_dir)
  if (!is.null(detected)) {
    message("Auto-detected models from metadata: ", paste(detected, collapse = ", "))
    expected_models <- detected
  } else {
    warning("Could not auto-detect models; using default: BLINK,FarmCPU,MLM")
    expected_models <- c("BLINK", "FarmCPU", "MLM")
  }
} else {
  message("Using CLI-specified models: ", opt$models)
  expected_models <- strsplit(opt$models, ",")[[1]]
}
```

## Risks / Trade-offs

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Metadata format changes | Low | Medium | Validate JSON structure, fail gracefully |
| First trait deleted/moved | Low | Low | Fall back to default with warning |
| Performance regression | Very Low | Low | Single file read is negligible |
| Test coverage gaps | Medium | High | TDD approach, comprehensive test fixtures |

## Migration Plan

1. **Add tests first** (TDD) - Tests define expected behavior
2. **Implement functions** - Make tests pass
3. **Update main flow** - Integrate detection
4. **Verify backward compat** - Existing workflows unchanged
5. **Deploy** - PR review and merge

### Rollback

If issues arise:
- The `--models` flag always overrides detection
- Remove detection code, revert to hardcoded default
- No data migration required (stateless change)

## Open Questions

1. **Should we emit model detection info in `summary_stats.json`?**
   - Leaning yes: adds provenance about how models were determined
   - Defer to implementation phase

2. **Should we support wildcard model detection (e.g., "all models found in outputs")?**
   - Out of scope for this change
   - Could be future enhancement if needed

## References

- `scripts/collect_results.R:46` - Current hardcoded default
- `scripts/collect_results.R:252` - Existing `get_gapit_param()` helper
- `scripts/collect_results.R:894-895` - Inconsistent validation list
- `openspec/specs/results-aggregation/spec.md` - Current aggregation requirements
