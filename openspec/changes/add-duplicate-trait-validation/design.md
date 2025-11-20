# Design: Add Duplicate Trait Name Validation

## Overview

Extend the existing `scripts/validate-env.sh` script to detect duplicate trait column names in phenotype files before GAPIT GWAS job submission. This prevents wasting cluster resources on analyzing the same trait multiple times.

## Architectural Context

### Current State

```
User prepares phenotype file
    ↓
User runs validate-env.sh (optional)
    ├─ Validates .env file
    ├─ Validates Docker image
    ├─ Validates cluster paths
    ├─ Validates data files exist
    ├─ Validates phenotype structure (column count, header)
    └─ Validates trait indices
    ↓
User runs submit-all-traits-runai.sh
    ├─ Sources .env
    ├─ Checks if jobs already exist (by name, not trait)
    └─ Submits 186 jobs for traits 2-187
    ↓
Jobs execute on cluster
    └─ No duplicate trait checking
```

**Gap**: No validation of trait name uniqueness. Users can submit jobs for duplicate traits, wasting resources.

### Proposed State

```
User prepares phenotype file
    ↓
User runs validate-env.sh (optional)
    ├─ Validates .env file
    ├─ Validates Docker image
    ├─ Validates cluster paths
    ├─ Validates data files exist
    ├─ Validates phenotype structure (column count, header)
    ├─ **NEW: Validates trait name uniqueness**
    │   ├─ Detects exact duplicates
    │   ├─ Detects whitespace-only differences
    │   └─ Warns about case-only differences
    └─ Validates trait indices
    ↓
User runs submit-all-traits-runai.sh
    ├─ Sources .env
    ├─ Checks if jobs already exist
    └─ Submits jobs (with confidence no duplicates)
    ↓
Jobs execute on cluster
    └─ No duplicate work performed
```

## Design Decisions

### Decision 1: Where to Validate

**Options:**
1. **Pre-flight validation (validate-env.sh)** ← SELECTED
2. Runtime validation (validate_inputs.R in container)
3. Submission-time validation (submit-all-traits-runai.sh)
4. Post-processing validation (after jobs complete)

**Rationale for Selection:**

| Criterion | Pre-flight | Runtime | Submission-time | Post-processing |
|-----------|-----------|---------|----------------|-----------------|
| Prevents resource waste | ✅ Yes | ❌ No | ✅ Yes | ❌ No |
| Fast feedback | ✅ <5s | ❌ After job start | ⚠️ Before jobs | ❌ After jobs |
| Single validation | ✅ Once | ❌ 186 times | ✅ Once | ❌ 186 times |
| User-friendly | ✅ Explicit check | ❌ Job failure | ⚠️ Mixed concerns | ❌ Too late |
| Optional | ✅ Yes | ❌ Always | ❌ Always | ❌ Always |

**Selected: Pre-flight validation**
- Prevents resource waste (best ROI)
- Fast user feedback
- Keeps submission script focused on submission logic
- Integrates with existing validation workflow

### Decision 2: Validation Strictness

**Options:**
1. **Exact duplicates = ERROR, case/whitespace = WARNING** ← SELECTED
2. All duplicates = ERROR (strict)
3. All duplicates = WARNING (permissive)
4. Configurable via flag

**Rationale:**
- **Exact duplicates are always wrong** → ERROR (blocks submission)
- **Case differences may be intentional** (e.g., "IRT1" gene vs "irt1" mutant) → WARNING
- **Whitespace differences are likely mistakes** but could be hidden Excel artifacts → ERROR
- **Keep it simple**: No configurability needed for MVP

### Decision 3: Replicate Handling

**Options:**
1. **Support naming convention (trait.rep1, trait_rep1)** ← SELECTED
2. Always flag duplicates, no exceptions
3. Add --allow-duplicates flag
4. Use separate metadata file for replicates

**Rationale:**
- Technical replicates are a legitimate use case
- Naming convention is simple, self-documenting
- No extra configuration files needed
- Can be implemented incrementally (Task 5 is optional)

**Supported conventions:**
```
trait_name.rep1, trait_name.rep2, ...  (period separator)
trait_name_rep1, trait_name_rep2, ...  (underscore separator)
trait_name_1, trait_name_2, ...        (numeric suffix)
```

Strip suffix before duplicate checking, but preserve in output.

### Decision 4: Performance Strategy

**Target**: <5 seconds for 200-column phenotype file

**Strategy:**
1. Use native bash tools (awk, sort, uniq) for speed
2. Single-pass extraction of trait names
3. Avoid nested loops where possible
4. Only perform expensive checks if initial checks pass

**Implementation:**
```bash
# Efficient approach:
# 1. Extract trait names once
TRAITS=$(head -1 "$PHENOTYPE_FILE_HOST" | cut -f2- | tr '\t' '\n')

# 2. Check for duplicates with sort/uniq (O(n log n))
DUPLICATES=$(echo "$TRAITS" | sort | uniq -d)

# 3. Only if duplicates exist, find their positions
if [ -n "$DUPLICATES" ]; then
    # For each duplicate, find line numbers (columns)
    while IFS= read -r dup; do
        COLS=$(echo "$TRAITS" | awk -v trait="$dup" '$0==trait {print NR+1}')
        # Report duplicate with columns
    done <<< "$DUPLICATES"
fi
```

**Worst case**: 1000 columns with 500 duplicates
- Extract: <1s
- Sort: <1s
- Find positions: <2s
- Total: <5s ✅

### Decision 5: Error Message Format

**Goal**: Clear, actionable messages with column indices

**Format:**
```
❌ Duplicate trait names found:
  - 'root_length' appears in columns: 15, 42
  - 'shoot_biomass' appears in columns: 23, 67, 89

  Fix: Edit phenotype file to use unique trait names or use
       replicate naming convention (e.g., root_length.rep1, root_length.rep2)
```

**Key elements:**
- ❌ Icon for immediate recognition
- Trait name in quotes for clarity
- All affected columns listed (user can investigate each)
- Actionable fix suggestion
- Reference to replicate convention

## Data Flow

### Phenotype File → Validation → Result

```
┌─────────────────────────────────────────────────────┐
│ Phenotype File (iron_traits_edited.txt)            │
│ ─────────────────────────────────────────────────── │
│ Taxa    trait_A    trait_B    trait_A    trait_C    │
│ acc001  1.2        3.4        5.6        7.8        │
│ acc002  2.3        4.5        6.7        8.9        │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ Extract Header Row                                   │
│ ─────────────────────────────────────────────────── │
│ head -1 | cut -f2-                                  │
│ → ["trait_A", "trait_B", "trait_A", "trait_C"]     │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ Check Exact Duplicates                               │
│ ─────────────────────────────────────────────────── │
│ sort | uniq -d                                      │
│ → ["trait_A"]                                       │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ Find Column Indices                                  │
│ ─────────────────────────────────────────────────── │
│ awk -v trait="trait_A" '$0==trait {print NR+1}'    │
│ → [2, 4] (columns 2 and 4, accounting for Taxa)    │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ Format Error Message                                 │
│ ─────────────────────────────────────────────────── │
│ ❌ Duplicate trait names found:                     │
│   - 'trait_A' appears in columns: 2, 4              │
│                                                      │
│   Fix: Edit phenotype file...                       │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ Exit Code                                            │
│ ─────────────────────────────────────────────────── │
│ exit 1 (validation failed)                          │
└─────────────────────────────────────────────────────┘
```

## Implementation Details

### Function Signature

```bash
check_trait_duplicates() {
    # Check for duplicate trait names in phenotype file
    #
    # Validates:
    #   1. Exact duplicate trait names (ERROR)
    #   2. Whitespace-only differences (ERROR)
    #   3. Case-only differences (WARNING)
    #
    # Globals:
    #   PHENOTYPE_FILE_HOST - Path to phenotype file on host
    #   ERRORS - Error counter (incremented on failure)
    #   WARNINGS - Warning counter (incremented on warning)
    #
    # Returns:
    #   0 if no duplicates found
    #   1 if duplicates found (ERRORS incremented)

    echo -n "Checking for duplicate trait names..."

    # Implementation here

    if [ $has_duplicates -eq 1 ]; then
        echo -e "${RED}✗${NC}"
        ((ERRORS++))
        return 1
    else
        echo -e "${GREEN}✓${NC} ($trait_count unique traits)"
        return 0
    fi
}
```

### Integration Point

Add to `scripts/validate-env.sh` after phenotype structure validation:

```bash
# Existing code (around line 260-270)
check_phenotype_structure

# NEW: Add duplicate checking
check_trait_duplicates

# Existing code continues
check_trait_indices
check_gapit_parameters
# ...
```

### Edge Cases

1. **Empty phenotype file**
   - Caught by existing `check_data_files` (file size check)
   - Skip duplicate check if no header

2. **Single trait column**
   - No duplicates possible
   - Quick pass: "1 unique trait"

3. **All traits have same name**
   - Report: "trait_name appears in columns: 2, 3, 4, ..., 187"
   - Single error message (not 186 separate messages)

4. **Very long trait names**
   - Truncate in error message: "very_long_trait_name_that_exce... (truncated)"
   - Show full name in verbose mode

5. **Special characters in trait names**
   - Handle properly: spaces, underscores, hyphens, periods, numbers
   - Quote trait names in output to avoid ambiguity

6. **File encoding issues**
   - Use `sed 's/\r$//'` to handle Windows line endings (already in existing code)
   - Normalize UTF-8 BOM if present

## Testing Strategy

### Test Fixtures

Create comprehensive test fixtures to cover all scenarios:

1. **phenotype_valid_unique.txt**
   ```
   Taxa	trait_A	trait_B	trait_C
   acc001	1.2	3.4	5.6
   acc002	2.3	4.5	6.7
   ```
   Expected: ✅ Pass (no duplicates)

2. **phenotype_duplicates_exact.txt**
   ```
   Taxa	trait_A	trait_B	trait_A	trait_C
   acc001	1.2	3.4	5.6	7.8
   acc002	2.3	4.5	6.7	8.9
   ```
   Expected: ❌ Error (trait_A in columns 2, 4)

3. **phenotype_duplicates_whitespace.txt**
   ```
   Taxa	trait_A	trait_B	trait_A 	trait_C
   # Note: column 4 has trailing space
   ```
   Expected: ❌ Error (whitespace-only difference)

4. **phenotype_duplicates_case.txt**
   ```
   Taxa	Root_Length	root_length	ROOT_LENGTH
   ```
   Expected: ⚠️ Warning (case-only differences)

5. **phenotype_replicates.txt**
   ```
   Taxa	iron_content.rep1	iron_content.rep2	iron_content.rep3
   ```
   Expected: ✅ Pass (legitimate replicates)

### Test Commands

```bash
# Test 1: Valid file (should pass)
PHENOTYPE_FILE_HOST="tests/fixtures/phenotype_valid_unique.txt" \
    bash -c "source scripts/validate-env.sh; check_trait_duplicates"
# Expected: exit 0, "3 unique traits"

# Test 2: Exact duplicates (should fail)
PHENOTYPE_FILE_HOST="tests/fixtures/phenotype_duplicates_exact.txt" \
    bash -c "source scripts/validate-env.sh; check_trait_duplicates"
# Expected: exit 1, error message with columns

# Test 3: Case-only (should warn)
PHENOTYPE_FILE_HOST="tests/fixtures/phenotype_duplicates_case.txt" \
    bash -c "source scripts/validate-env.sh; check_trait_duplicates"
# Expected: exit 0, warning message

# Test 4: Performance (should complete <5s)
time PHENOTYPE_FILE_HOST="tests/fixtures/phenotype_large_1000cols.txt" \
    bash -c "source scripts/validate-env.sh; check_trait_duplicates"
# Expected: real time <5s
```

### Integration Tests

```bash
# Test full validate-env.sh workflow
$ ./scripts/validate-env.sh --env-file tests/fixtures/.env.duplicates
# Should fail with duplicate error

$ ./scripts/validate-env.sh --env-file tests/fixtures/.env.valid
# Should pass with "186 unique traits"

# Test dry-run integration
$ ./scripts/submit-all-traits-runai.sh --dry-run --env-file tests/fixtures/.env.duplicates
# Should fail before showing submission plan
```

## Rollout Plan

### Phase 1: Core Implementation (Tasks 1-4)
- Implement exact duplicate detection
- Implement whitespace normalization
- Implement case-insensitive check
- Integrate into validate-env.sh
- **Deliverable**: Working validation that catches common duplicates

### Phase 2: Testing & Documentation (Tasks 6-8)
- Create comprehensive test fixtures
- Test with real phenotype files
- Update documentation
- **Deliverable**: Validated, documented feature

### Phase 3: Integration & Polish (Task 9)
- Verify dry-run integration
- Test end-to-end submission workflow
- Gather user feedback
- **Deliverable**: Production-ready feature

### Phase 4: Optional Enhancements (Tasks 5, 10)
- Add replicate naming support (if requested)
- Optimize performance (if needed)
- **Deliverable**: Enhanced feature based on real usage

## Maintenance Considerations

### Code Location
- Single function in `scripts/validate-env.sh`
- ~50-80 lines of bash code
- Well-commented, follows existing style

### Dependencies
- No new external dependencies
- Uses standard Unix tools (awk, sort, uniq)
- Works on Linux, macOS, Git Bash on Windows

### Backwards Compatibility
- No breaking changes
- Existing phenotype files with unique traits: no change
- Existing phenotype files with duplicates: now caught (prevents silent waste)
- Users can skip validation if needed (though not recommended)

### Future Extensions

Possible future enhancements (not in scope for this change):

1. **Semantic similarity checking**: Detect typos (e.g., Levenshtein distance)
2. **Duplicate value detection**: Check if trait data values are identical (not just names)
3. **Cross-file validation**: Verify trait names match between multiple phenotype files
4. **Auto-fix mode**: Offer to rename duplicates automatically (with user confirmation)
5. **JSON output**: Machine-readable validation results for CI/CD integration

## Alternatives Not Selected

### Alternative A: R-based validation
Use R script instead of bash for validation.

**Rejected because:**
- Slower startup time (R interpreter)
- Requires R environment (adds dependency)
- Bash is sufficient for string comparison
- Would duplicate logic between bash and R

### Alternative B: Python-based validation
Create Python script for validation.

**Rejected because:**
- Adds Python dependency (not currently in project)
- Overkill for simple string comparison
- Would require separate installation step
- Bash keeps everything in one place

### Alternative C: CSV parsing library
Use specialized CSV/TSV parsing tool.

**Rejected because:**
- Phenotype files are simple tab-delimited
- Standard Unix tools handle them correctly
- No need for complex escaping/quoting
- Would add external dependency

## Summary

This design extends the existing validation framework with minimal complexity:
- **Single function** added to existing script
- **No new dependencies** required
- **Fast execution** (<5 seconds target)
- **Clear error messages** with actionable fixes
- **Incremental rollout** possible (core features → optional enhancements)

The approach is pragmatic, maintainable, and solves the real problem of duplicate trait waste without over-engineering.
