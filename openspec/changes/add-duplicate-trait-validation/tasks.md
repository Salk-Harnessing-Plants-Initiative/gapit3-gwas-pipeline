# Tasks: Add Duplicate Trait Name Validation

## Task List

### 1. Implement duplicate trait name detection function
- [ ] Add `check_trait_duplicates()` function to `scripts/validate-env.sh`
- [ ] Extract trait names from phenotype file (skip Taxa column)
- [ ] Detect exact duplicate trait names using sort + uniq
- [ ] For each duplicate, list all column indices where it appears
- [ ] Format error messages with trait name and column list
- [ ] Increment ERRORS counter when duplicates found

**Validation**: Run validate-env.sh on phenotype file with known duplicates, verify all duplicates detected with correct column indices

**Dependencies**: None (extends existing validate-env.sh)

---

### 2. Add whitespace normalization check
- [ ] Create normalized version of trait names (trim leading/trailing, collapse internal whitespace)
- [ ] Compare normalized names against original names
- [ ] Detect duplicates that only differ in whitespace
- [ ] Format error message explaining whitespace difference
- [ ] Increment ERRORS counter for whitespace-only duplicates

**Validation**: Test with trait names containing leading spaces, trailing spaces, and multiple internal spaces

**Dependencies**: Task 1 (uses same validation framework)

---

### 3. Add case-insensitive duplicate check (warning)
- [ ] Create lowercase version of trait names
- [ ] Detect duplicates in lowercase that weren't duplicates in original
- [ ] Format warning message with original capitalizations
- [ ] Explain that these will be treated as separate traits
- [ ] Increment WARNINGS counter

**Validation**: Test with trait pairs like "Root_Length" and "root_length"

**Dependencies**: Task 1 (uses same validation framework)

---

### 4. Integrate validation into existing check sequence
- [ ] Add call to `check_trait_duplicates()` in main validation flow
- [ ] Position after `check_phenotype_structure()` (line ~267 in proposal example)
- [ ] Ensure error/warning counts propagate to final summary
- [ ] Update success message to show "X unique traits" count

**Validation**: Run full validate-env.sh workflow, verify duplicate check executes and affects exit code

**Dependencies**: Tasks 1-3 (all validation functions implemented)

---

### 5. Add replicate naming convention support (optional)
- [ ] Document replicate naming conventions (trait.rep1, trait_rep1, trait_1)
- [ ] Add logic to strip replicate suffix before duplicate checking
- [ ] Add note in output when replicates detected: "ℹ️  Technical replicates detected: X traits with replicate suffixes"
- [ ] Test with phenotype files containing legitimate replicates

**Validation**: Create test phenotype with trait.rep1, trait.rep2, verify no false positive

**Dependencies**: Task 1 (extends duplicate detection logic)

**Note**: This is optional and can be deferred if not immediately needed

---

### 6. Create test fixtures for duplicate scenarios
- [ ] Create `tests/fixtures/phenotype_duplicates_exact.txt` (exact duplicate trait names)
- [ ] Create `tests/fixtures/phenotype_duplicates_whitespace.txt` (whitespace variations)
- [ ] Create `tests/fixtures/phenotype_duplicates_case.txt` (case-only differences)
- [ ] Create `tests/fixtures/phenotype_valid_unique.txt` (no duplicates, control)
- [ ] Create `tests/fixtures/phenotype_replicates.txt` (technical replicates with .rep suffix)

**Validation**: Run validate-env.sh with each fixture, verify expected behavior

**Dependencies**: None (can be done in parallel with implementation)

---

### 7. Test validation with real phenotype files
- [ ] Test with actual phenotype file (iron_traits_edited.txt - 187 columns)
- [ ] Verify validation completes in <5 seconds
- [ ] Confirm no false positives on known-good file
- [ ] Manually add duplicates and verify detection
- [ ] Test with large phenotype file (500+ columns) for performance

**Validation**: Benchmark validation time, ensure <5 second target met

**Dependencies**: Tasks 1-4 (validation implemented and integrated)

---

### 8. Update documentation
- [ ] Update `scripts/validate-env.sh --help` to mention duplicate checking
- [ ] Add section to README.md explaining duplicate validation
- [ ] Document replicate naming conventions (if Task 5 implemented)
- [ ] Add examples of error messages to troubleshooting guide
- [ ] Update TESTING.md with duplicate validation test scenarios

**Validation**: Review documentation for clarity and completeness

**Dependencies**: Tasks 1-5 (all features implemented)

---

### 9. Add validation to dry-run mode integration
- [ ] Verify duplicate checking runs when `submit-all-traits-runai.sh --dry-run` is used
- [ ] Confirm error messages appear before submission plan
- [ ] Test that invalid configs prevent showing submission plan
- [ ] Update dry-run output to mention duplicate checking

**Validation**: Run `submit-all-traits-runai.sh --dry-run` with duplicate phenotype, verify caught

**Dependencies**: Task 4 (validation integrated into validate-env.sh)

---

### 10. Performance optimization (if needed)
- [ ] Profile validation with 1000+ column phenotype file
- [ ] If >5 seconds, optimize with awk instead of bash loops
- [ ] Consider pre-sorting trait names to avoid repeated sorts
- [ ] Add benchmark test to ensure future changes don't regress performance

**Validation**: Benchmark script on large phenotype files

**Dependencies**: Task 7 (performance tested and found lacking)

**Note**: Only if Task 7 reveals performance issues

---

## Task Summary

**Critical Path**: Tasks 1 → 2 → 3 → 4 → 7 → 8 → 9
**Parallelizable**: Task 6 (test fixtures) can run alongside Tasks 1-4
**Optional**: Tasks 5 (replicates) and 10 (optimization)
**Estimated Total Time**: ~3-4 hours
**User-Visible Milestone**: After Task 4, validation catches duplicates

## Testing Strategy

1. **Unit-level**: Test each validation function independently with test fixtures (Task 6)
2. **Integration**: Test full validate-env.sh workflow with various scenarios (Task 7)
3. **Performance**: Benchmark with large files to ensure <5 second target (Task 7, Task 10)
4. **End-to-end**: Test with real submission workflow including dry-run (Task 9)

## Rollback Plan

If validation causes issues:
1. Comment out call to `check_trait_duplicates()` in validate-env.sh
2. Validation script returns to previous behavior
3. No impact on submission or execution scripts

## Success Metrics

- ✅ 0% false negative rate (all duplicates caught)
- ✅ <5% false positive rate (legitimate replicates not flagged)
- ✅ <5 seconds validation time for 200-column files
- ✅ Clear, actionable error messages
- ✅ No breaking changes to existing validation workflow
