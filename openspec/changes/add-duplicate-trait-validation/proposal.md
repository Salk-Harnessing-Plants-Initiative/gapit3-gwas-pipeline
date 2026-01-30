# Proposal: Add Duplicate Trait Name Validation

## Problem Statement

Users can submit GAPIT GWAS jobs for phenotype files with duplicate trait column names, wasting cluster resources by analyzing the same trait multiple times. There is currently no validation to detect or prevent duplicate trait names in phenotype files before submission.

### Real-World Scenario

**What happens now:**
1. User creates phenotype file with duplicate trait names (e.g., column 15 and column 42 both named "root_length")
2. User runs `submit-all-traits-runai.sh` to submit 186 jobs
3. Script submits jobs for traits 2-187 successfully
4. Jobs run for ~4 hours consuming cluster resources
5. User analyzes results and discovers:
   - Trait 15 results identical to trait 42 results
   - Wasted compute: 2 jobs × 12 CPU × 32GB × 30 min = significant resource waste
6. User must identify all duplicates manually
7. Unclear which trait index to keep (which was "correct"?)

**What we want:**
1. User creates phenotype file
2. Runs `validate-env.sh` (or `submit-all-traits-runai.sh --dry-run`)
3. Validation catches: "❌ Duplicate trait names found: 'root_length' (columns 15, 42)"
4. User investigates and fixes phenotype file
5. Revalidates: "✅ All checks passed"
6. Submits with confidence
7. **Jobs run successfully without duplicate work**

### Configuration Errors We Want to Catch

**1. Exact Duplicate Trait Names** (Most Critical)
```bash
# Phenotype file has identical trait names
# Taxa   trait_A   trait_B   trait_A   trait_C
#        ^col 2              ^col 4 (duplicate!)
# → ERROR: Jobs 2 and 4 will analyze identical data
```

**2. Whitespace-Only Differences** (Hidden Duplicates)
```bash
# Phenotype file has names differing only in whitespace
# Taxa   trait_A   trait_A    trait_B
#        ^col 2    ^col 3 (trailing space!)
# → ERROR: Names appear different but are functionally identical
```

**3. Case-Only Differences** (Potentially Intentional)
```bash
# Phenotype file has names differing only in case
# Taxa   Root_Length   root_length   ROOT_LENGTH
#        ^col 2        ^col 3        ^col 4
# → WARNING: Case-only differences - are these intentional?
```

**4. Suspiciously Similar Names** (Likely Typos)
```bash
# Phenotype file has very similar trait names
# Taxa   mean_root_length   mean_root_lenght   mean_root_length_cm
#        ^col 2             ^col 3 (typo?)     ^col 4
# → WARNING: Similar names detected - verify these are distinct traits
```

**5. Technical Replicates with Same Name** (Intentional Duplicates)
```bash
# User has technical replicates that SHOULD have same name
# Taxa   iron_content   iron_content   iron_content
#        ^rep1          ^rep2          ^rep3
# → Need way to allow this with explicit flag or naming convention
```

### Impact Analysis

**Without Validation:**
- **Frequency**: Low to Medium (depends on data preparation workflow)
- **Time to discover error**: Hours to days (after analysis completes)
- **Recovery time**: Hours (manual duplicate identification + reanalysis)
- **Wasted resources**:
  - N duplicates × 12 CPU × 32GB × 30 min per duplicate
  - Example: 10 duplicates = 10 jobs worth of compute wasted
- **User frustration**: High (hard to detect, unclear which results to keep)

**With Validation:**
- **Time to validate**: <5 seconds (added to existing validate-env.sh)
- **Time to discover error**: Immediate (pre-submission)
- **Recovery time**: Minutes (fix phenotype file, revalidate)
- **Wasted resources**: None
- **User confidence**: High

## Proposed Solution

### Approach: Extend Existing validate-env.sh Script

Add duplicate trait name validation to the existing `scripts/validate-env.sh` script created in the `add-env-validation-and-dry-run` change. This keeps all validation logic in one place and integrates seamlessly with the existing validation workflow.

**Design Philosophy:**
- **Fast**: Validation adds <5 seconds to existing validation time
- **Thorough**: Detect exact duplicates, whitespace issues, case differences
- **Clear**: Actionable error messages with column indices
- **Flexible**: Support for technical replicates via naming convention
- **Non-breaking**: Works with existing phenotype files

**Validation Logic:**

#### 1. Extract Trait Names from Phenotype File
```bash
# Skip first column (Taxa), extract trait names
TRAIT_NAMES=$(head -1 "$PHENOTYPE_FILE_HOST" | cut -f2-)
# Convert to array for processing
IFS=$'\t' read -ra TRAITS <<< "$TRAIT_NAMES"
```

#### 2. Check for Exact Duplicates
```bash
# Find traits that appear more than once (exact match)
DUPLICATES=$(printf '%s\n' "${TRAITS[@]}" | sort | uniq -d)
if [ -n "$DUPLICATES" ]; then
    error "Duplicate trait names found:"
    while IFS= read -r dup; do
        # Find all column indices for this duplicate
        COLS=$(printf '%s\n' "${TRAITS[@]}" | \
               awk -v trait="$dup" '$0==trait {print NR+1}' | \
               paste -sd,)
        error "  - '$dup' appears in columns: $COLS"
    done <<< "$DUPLICATES"
    ((ERRORS++))
fi
```

#### 3. Check for Whitespace-Only Differences
```bash
# Normalize whitespace and check for duplicates
NORMALIZED_TRAITS=()
for i in "${!TRAITS[@]}"; do
    # Trim leading/trailing whitespace, collapse internal whitespace
    NORMALIZED=$(echo "${TRAITS[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]\+/ /g')
    NORMALIZED_TRAITS[$i]="$NORMALIZED"
done

# Check if normalized names have duplicates that original didn't
# If yes, it means whitespace-only differences exist
```

#### 4. Check for Case-Only Differences (Warning)
```bash
# Convert to lowercase and check for duplicates
LOWERCASE_TRAITS=()
for i in "${!TRAITS[@]}"; do
    LOWERCASE_TRAITS[$i]=$(echo "${TRAITS[$i]}" | tr '[:upper:]' '[:lower:]')
done

# Find case-only differences
CASE_DUPS=$(printf '%s\n' "${LOWERCASE_TRAITS[@]}" | sort | uniq -d)
if [ -n "$CASE_DUPS" ]; then
    warn "Trait names differing only in case detected:"
    # List the affected traits with their original capitalization
    ((WARNINGS++))
fi
```

#### 5. Support Technical Replicates (Optional)

Allow users to mark technical replicates using a naming convention:
```bash
# Convention: trait_name.rep1, trait_name.rep2, etc.
# OR: trait_name_rep1, trait_name_rep2, etc.
# Strip replicate suffix before checking duplicates
```

**Integration Points:**

1. **validate-env.sh**: Add new validation function `check_trait_duplicates()`
2. **Call after existing phenotype validation**: Insert after `check_phenotype_structure()`
3. **Exit codes**: Use existing error counting mechanism
4. **Output formatting**: Match existing error/warning format with colors

**User Interface:**

Success case:
```bash
$ ./scripts/validate-env.sh

🔍 Validating GAPIT GWAS Configuration
Environment file: .env

✅ .env file validation passed
✅ Docker image exists
✅ Cluster paths accessible
✅ Data files readable
✅ Phenotype structure valid
✅ No duplicate trait names detected (186 unique traits)
✅ Trait indices valid
✅ GAPIT parameters valid
✅ RunAI configuration valid

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ All validation checks passed!

Configuration is ready for submission:
  ./scripts/submit-all-traits-runai.sh
```

Error case (exact duplicates):
```bash
$ ./scripts/validate-env.sh

🔍 Validating GAPIT GWAS Configuration
Environment file: .env

✅ .env file validation passed
✅ Docker image exists
✅ Cluster paths accessible
✅ Data files readable
✅ Phenotype structure valid
❌ Duplicate trait names found:
  - 'root_length' appears in columns: 15, 42
  - 'shoot_biomass' appears in columns: 23, 67, 89

  Fix: Edit phenotype file to use unique trait names or use
       replicate naming convention (e.g., root_length.rep1, root_length.rep2)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ Validation failed with 1 error(s) and 0 warning(s)

Please fix the errors above before submitting.
```

Warning case (case-only differences):
```bash
$ ./scripts/validate-env.sh

🔍 Validating GAPIT GWAS Configuration
Environment file: .env

✅ .env file validation passed
✅ Docker image exists
✅ Cluster paths accessible
✅ Data files readable
✅ Phenotype structure valid
✅ No exact duplicate trait names
⚠️  Trait names differing only in case detected:
  - 'Root_Length' (column 15) vs 'root_length' (column 42)

  Note: These will be treated as separate traits. If they represent
        the same measurement, consider standardizing capitalization.

✅ Trait indices valid
✅ GAPIT parameters valid
✅ RunAI configuration valid

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠ Validation passed with 1 warning(s)

Configuration is usable but review warnings above.
```

## Alternatives Considered

### Alternative 1: Create Separate Validation Script

**Approach**: Create `scripts/check-phenotype-duplicates.sh` as standalone script.

**Pros**:
- Single-purpose tool
- Can be run independently
- Doesn't modify existing code

**Cons**:
- Users must remember to run two validation scripts
- Duplicate code for phenotype file reading
- Not integrated with existing workflow
- Another script to maintain

**Verdict**: REJECT - Integration with existing validate-env.sh is better UX

### Alternative 2: Validate at Runtime (Inside Container)

**Approach**: Add duplicate checking to `validate_inputs.R` that runs inside each GAPIT job.

**Pros**:
- Catches issues even if user skips validation
- Works for all execution paths (direct Docker, Argo, RunAI)

**Cons**:
- Wastes cluster resources (all 186 jobs perform same validation)
- Error discovered after job submission (too late)
- Slows down job startup
- Doesn't prevent resource waste

**Verdict**: REJECT - Pre-flight validation is more efficient

### Alternative 3: Auto-Rename Duplicates

**Approach**: Automatically append suffixes to duplicate names (e.g., `root_length_1`, `root_length_2`).

**Pros**:
- User doesn't have to fix manually
- Jobs can proceed without intervention

**Cons**:
- Hides data quality issues
- User may not realize duplicates existed
- Results labeled with auto-generated names may not match expected traits
- Violates principle of explicit configuration

**Verdict**: REJECT - Explicit validation is better than silent fixes

### Alternative 4: Allow Duplicates, Deduplicate Results

**Approach**: Allow duplicate trait names, but only analyze each unique name once.

**Pros**:
- Flexible for users with complex phenotype files
- Automatically saves resources

**Cons**:
- Complex logic to track unique names vs indices
- Unclear which column index is analyzed (first occurrence?)
- Results don't match submitted job count (confusing)
- Requires major refactoring of submission logic

**Verdict**: REJECT - Too complex, validation is simpler

### Selected Approach: Extend validate-env.sh with Comprehensive Checks

**Rationale**:
- **Integrated**: Works with existing validation workflow
- **Fast**: Adds minimal overhead to validation time
- **User-friendly**: Clear error messages with column indices
- **Flexible**: Supports technical replicates via naming convention
- **Non-breaking**: Doesn't change existing scripts beyond validation
- **Preventive**: Catches errors before any resources are consumed

## Dependencies

**Required:**
- `scripts/validate-env.sh` (already exists from add-env-validation-and-dry-run)
- Bash 4.0+ (for associative arrays)
- Standard Unix tools: `awk`, `sort`, `uniq`, `cut`, `paste`

**Optional:**
- Access to phenotype file on host filesystem (already required for validation)

**No new dependencies** - uses only tools already required by existing validation script.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| False positives on legitimate replicates | Medium | Medium | Support replicate naming convention (trait.rep1, trait.rep2) |
| Validation slows down significantly for large phenotype files | Low | Low | Optimize with awk/grep, test with 1000+ column files |
| Users skip validation and still submit duplicates | Medium | Medium | Document validation as required step, consider integrating into submission script |
| Whitespace/case checks too strict | Low | Medium | Make these warnings not errors, allow users to proceed |
| Unclear error messages for complex duplicate scenarios | Low | High | Provide comprehensive examples in documentation |

## Success Criteria

1. ✅ Validation detects 100% of exact duplicate trait names
2. ✅ Validation detects whitespace-only differences
3. ✅ Validation warns about case-only differences
4. ✅ Validation completes in <5 seconds for 200-column phenotype file
5. ✅ Error messages include all column indices for each duplicate
6. ✅ No false positives for technical replicates with proper naming
7. ✅ Validation integrates seamlessly into existing validate-env.sh
8. ✅ Exit codes match existing convention (1=validation failed)
9. ✅ Documentation updated with examples

## Timeline Estimate

- Add duplicate validation function: 1 hour
  - Exact duplicate detection: 20 min
  - Whitespace normalization: 15 min
  - Case-insensitive checking: 15 min
  - Error formatting: 10 min
- Integration into validate-env.sh: 30 min
- Testing with various phenotype scenarios: 1 hour
  - Create test fixtures with duplicates
  - Test exact duplicates
  - Test whitespace variations
  - Test case variations
  - Test large files (performance)
- Documentation: 30 min
  - Update validate-env.sh help text
  - Add examples to README
  - Document replicate naming convention
- **Total**: ~3 hours

## Open Questions

1. **Should we support a --allow-duplicates flag?**
   - Pro: Flexibility for advanced users who know what they're doing
   - Con: Easy to misuse, defeats purpose of validation
   - **Decision**: No - if users need duplicates, they should use replicate naming convention

2. **Should case-insensitive check be error or warning?**
   - Pro (Error): Forces consistent naming
   - Pro (Warning): Allows legitimate case differences (e.g., "IRT1" gene vs "irt1" mutant)
   - **Decision**: Warning - case differences may be intentional

3. **Should we check for similar names (Levenshtein distance)?**
   - Pro: Catches typos (e.g., "root_lenght" vs "root_length")
   - Con: Expensive computation, high false positive rate
   - **Decision**: No for MVP - can add later with --thorough flag

4. **What naming convention for technical replicates?**
   - Options:
     - `trait_name.rep1`, `trait_name.rep2` (period separator)
     - `trait_name_rep1`, `trait_name_rep2` (underscore separator)
     - `trait_name_1`, `trait_name_2` (numeric suffix)
   - **Decision**: Support all three patterns, document in validation output

5. **Should validation be mandatory (called automatically by submission script)?**
   - Pro: Can't forget to validate
   - Con: Slows submission, annoying for experts
   - **Decision**: Optional but strongly recommended in documentation

## Next Steps

1. Get approval for proposal
2. Implement `check_trait_duplicates()` function in validate-env.sh
3. Add test fixtures with duplicate scenarios
4. Test with real phenotype files
5. Update documentation (README, validate-env.sh --help)
6. Update add-env-validation-and-dry-run change to reflect this extension
