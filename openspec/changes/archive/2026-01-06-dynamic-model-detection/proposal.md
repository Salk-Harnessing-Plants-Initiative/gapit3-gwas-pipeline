# Proposal: Dynamic Model Detection from Workflow Metadata

## Why

The `collect_results.R` script has two inconsistent hardcoded model lists that create potential for silent failures when workflows use non-standard model combinations:

1. **CLI default** (line 46): `"BLINK,FarmCPU,MLM"` - used for completeness checking
2. **Validation list** (lines 894-895): `c("BLINK", "FarmCPU", "GLM", "MLM", "MLMM", "FarmCPU.LM", "Blink.LM")` - used for model name validation

This creates several problems:
- Workflows using models like `GLM` or `MLMM` require manual `--models` flag specification
- No mechanism to auto-detect the expected models from workflow metadata
- Silent failures when completeness checking uses wrong model list
- Inconsistency between the two hardcoded lists

The existing `get_gapit_param()` helper (line 252) already reads model information from trait metadata, demonstrating this capability exists but isn't used for the aggregation's own completeness checking.

## What Changes

- **ADDED**: Auto-detect expected models from workflow metadata when `--models` not specified
- **MODIFIED**: `select_best_trait_dirs()` function to use detected models for completeness checking
- **ADDED**: Validate detected models against known GAPIT model list
- **ADDED**: Unit tests (TDD) for model detection and validation logic
- **MODIFIED**: Console output to report detected vs specified models

## Impact

- **Affected specs**: `results-aggregation`
- **Affected code**:
  - `scripts/collect_results.R` (model detection, completeness checking)
  - `tests/testthat/test-collect_results.R` (new tests)
- **Backward compatibility**: Existing `--models` flag behavior preserved; auto-detection only used when flag not provided

## Technical Approach

### Model Detection Strategy

1. Read first trait's `gapit_metadata.json` file
2. Extract `model` parameter (v3.0.0 naming) or `models` parameter (legacy)
3. Parse comma-separated list into vector
4. Validate each model against known GAPIT models
5. Use detected models for completeness checking in `select_best_trait_dirs()`

### Why First Trait Metadata?

- All traits in a workflow use the same model configuration
- Reading one metadata file is O(1), not O(n) for n traits
- Metadata is already written by the pipeline as part of provenance tracking
- Falls back to CLI default if metadata unavailable

### Test-Driven Development

Tests will be written BEFORE implementation:
1. Test model extraction from metadata JSON
2. Test validation against known models
3. Test fallback behavior when metadata unavailable
4. Test completeness checking with detected models
5. Integration test with actual trait directories

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Metadata file missing | Medium | Fall back to CLI default with warning |
| Metadata has unexpected format | Low | Validate JSON structure, warn and fall back |
| Model name case mismatch | Low | Case-insensitive comparison for known models |
| Performance impact | Low | Read only one metadata file, not all |

## Dependencies

- **BLOCKER**: `refactor-collect-results-testable` must be completed first
  - Provides testable module architecture
  - Enables proper TDD without script execution side effects

## Success Criteria

- [ ] All new tests pass before implementation (TDD green)
- [ ] Auto-detection works for standard workflows without `--models` flag
- [ ] Backward compatibility: `--models` flag still overrides detection
- [ ] Clear console output showing detected vs specified models
- [ ] No regression in existing aggregation functionality
