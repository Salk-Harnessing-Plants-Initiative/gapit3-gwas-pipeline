# Spec: Phenotype Duplicate Validation

## ADDED Requirements

### Requirement: Exact duplicate trait names must be detected and reported as errors

The validation script MUST detect when two or more trait columns have identical names and report this as a validation error with all affected column indices.

#### Scenario: Phenotype file with two exact duplicate trait names

**Given** a phenotype file with header:
```
Taxa	root_length	shoot_length	root_length	biomass
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Detect that "root_length" appears in columns 2 and 4
- Report an error message: "Duplicate trait names found: 'root_length' appears in columns: 2, 4"
- Increment the error counter
- Return exit code 1 (validation failed)

#### Scenario: Phenotype file with three duplicate trait names across multiple traits

**Given** a phenotype file with header:
```
Taxa	trait_A	trait_B	trait_A	trait_C	trait_B	trait_A
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Detect that "trait_A" appears in columns 2, 4, 7
- Detect that "trait_B" appears in columns 3, 6
- Report both duplicates with all column indices
- Increment the error counter by 1 (for the duplicate detection failure)
- Return exit code 1 (validation failed)

#### Scenario: Phenotype file with all unique trait names

**Given** a phenotype file with header:
```
Taxa	root_length	shoot_length	biomass	chlorophyll
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Detect no duplicates
- Report success message: "No duplicate trait names detected (4 unique traits)"
- NOT increment the error counter
- Continue to next validation check

---

### Requirement: Whitespace-only differences in trait names must be detected as errors

The validation script MUST detect when trait names differ only in leading/trailing whitespace or internal whitespace amount and treat these as duplicates.

#### Scenario: Trait names with leading/trailing whitespace

**Given** a phenotype file with header:
```
Taxa	root_length	shoot_length	 root_length	biomass
```
(Note: column 4 has leading space before "root_length")

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Normalize whitespace (trim leading/trailing, collapse internal)
- Detect that "root_length" and " root_length" normalize to same value
- Report error: "Duplicate trait names found (whitespace difference): 'root_length' appears in columns: 2, 4"
- Increment the error counter
- Return exit code 1

#### Scenario: Trait names with internal whitespace differences

**Given** a phenotype file with header:
```
Taxa	root length	shoot length	root  length	biomass
```
(Note: column 4 has double space in "root  length")

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Normalize internal whitespace (collapse multiple spaces to single space)
- Detect that "root length" and "root  length" normalize to same value
- Report error with both column indices
- Return exit code 1

---

### Requirement: Case-only differences in trait names must be reported as warnings

The validation script MUST detect when trait names differ only in capitalization and report this as a warning (not an error), allowing submission to proceed.

#### Scenario: Trait names differing only in case

**Given** a phenotype file with header:
```
Taxa	Root_Length	root_length	ROOT_LENGTH	biomass
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Detect that "Root_Length", "root_length", and "ROOT_LENGTH" differ only in case
- Report warning: "Trait names differing only in case detected: 'Root_Length' (column 2), 'root_length' (column 3), 'ROOT_LENGTH' (column 4)"
- Explain that these will be treated as separate traits
- Increment the warning counter
- NOT increment the error counter
- Continue validation and allow submission if no other errors

---

### Requirement: Validation must provide clear column indices for all duplicates

When duplicates are detected, the validation script MUST report ALL column indices where each duplicate appears, formatted as a comma-separated list.

#### Scenario: Duplicate appearing in multiple non-consecutive columns

**Given** a phenotype file with header:
```
Taxa	trait_A	trait_B	trait_C	trait_A	trait_D	trait_A	trait_E
```

**When** the validation script reports the duplicate

**Then** the output MUST include:
- "Duplicate trait names found:"
- "  - 'trait_A' appears in columns: 2, 5, 7"
- All three column indices listed in ascending order
- Comma-separated format for easy parsing

#### Scenario: Multiple duplicates with different frequencies

**Given** a phenotype file with header:
```
Taxa	X	Y	X	Z	Y	X
```

**When** the validation script reports duplicates

**Then** the output MUST include:
- "  - 'X' appears in columns: 2, 4, 7"
- "  - 'Y' appears in columns: 3, 6"
- Each duplicate on its own line
- All column indices for each duplicate

---

### Requirement: Validation must complete in under 5 seconds for 200-column phenotype files

The validation script MUST complete duplicate checking efficiently to provide fast feedback.

#### Scenario: Validation performance with 200-column file

**Given** a phenotype file with 200 trait columns (201 total including Taxa)

**When** the validation script checks for duplicate trait names

**Then** the duplicate checking MUST complete in less than 5 seconds

#### Scenario: Validation performance with 500-column file

**Given** a phenotype file with 500 trait columns (501 total including Taxa)

**When** the validation script checks for duplicate trait names

**Then** the duplicate checking SHOULD complete in less than 10 seconds
(Note: SHOULD not MUST, as this is beyond expected typical usage)

---

### Requirement: Validation must integrate into existing validate-env.sh workflow

The duplicate trait validation MUST be called as part of the existing validation flow and contribute to the overall validation exit code.

#### Scenario: Duplicate validation integrated into full validation flow

**Given** the validate-env.sh script is executed

**When** the phenotype structure validation passes

**Then** the script MUST:
- Call the duplicate trait name validation function
- Display validation result (✓ or ✗)
- Include duplicate checking in the validation summary
- Affect the final exit code (0 for success, 1 for failure)

#### Scenario: Duplicate validation affects overall validation result

**Given** all other validations pass (env file, paths, files, etc.)
**And** the phenotype file has duplicate trait names

**When** validate-env.sh completes

**Then** the script MUST:
- Display "❌ Validation failed with 1 error(s)"
- Show the duplicate trait error message
- Return exit code 1 (validation failed overall)
- Prevent user from proceeding to submission

---

### Requirement: Technical replicates with naming convention must be allowed

The validation script MUST support technical replicates by recognizing standard replicate naming conventions and not flagging them as duplicates.

#### Scenario: Technical replicates with period separator

**Given** a phenotype file with header:
```
Taxa	iron_content.rep1	iron_content.rep2	iron_content.rep3	chlorophyll
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Recognize ".rep1", ".rep2", ".rep3" as replicate suffixes
- Strip suffixes before checking duplicates (base name: "iron_content")
- Detect that all three are replicates of same trait
- NOT report these as duplicates
- Optionally report: "ℹ️  Technical replicates detected: iron_content (3 replicates)"

#### Scenario: Technical replicates with underscore separator

**Given** a phenotype file with header:
```
Taxa	iron_content_rep1	iron_content_rep2	biomass_rep1	biomass_rep2
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Recognize "_rep1", "_rep2" as replicate suffixes
- NOT report these as duplicates
- Allow validation to pass

#### Scenario: Mixed replicates and actual duplicates

**Given** a phenotype file with header:
```
Taxa	trait_A.rep1	trait_A.rep2	trait_B	trait_B
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Allow trait_A.rep1 and trait_A.rep2 (legitimate replicates)
- Detect trait_B duplicate (columns 4, 5)
- Report only the trait_B duplicate as an error
- Return exit code 1

---

### Requirement: Error messages must provide actionable fix suggestions

When duplicates are detected, the validation script MUST provide clear guidance on how to fix the issue.

#### Scenario: Error message includes fix suggestion

**Given** duplicate trait names are detected

**When** the error is reported

**Then** the error message MUST include:
- The specific duplicates and their column indices
- A "Fix:" section with actionable guidance
- Reference to replicate naming convention if applicable
- Example: "Fix: Edit phenotype file to use unique trait names or use replicate naming convention (e.g., trait.rep1, trait.rep2)"

---

### Requirement: Validation must handle edge cases gracefully

The validation script MUST handle edge cases without crashing or producing misleading results.

#### Scenario: Phenotype file with only Taxa column

**Given** a phenotype file with header:
```
Taxa
```
(No trait columns)

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Detect 0 trait columns
- Report this as an error in phenotype structure validation (different check)
- NOT attempt duplicate checking
- NOT crash

#### Scenario: Phenotype file with single trait column

**Given** a phenotype file with header:
```
Taxa	single_trait
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Detect 1 unique trait
- Report success: "No duplicate trait names detected (1 unique trait)"
- NOT report any duplicates

#### Scenario: Trait names with special characters

**Given** a phenotype file with header:
```
Taxa	trait-1	trait_2	trait.3	trait-1	trait#4
```

**When** the validation script checks for duplicate trait names

**Then** the script MUST:
- Correctly handle hyphens, underscores, periods, hashtags
- Detect that "trait-1" appears in columns 2 and 5
- Report duplicate with special characters preserved in output

#### Scenario: Very long trait names

**Given** a phenotype file where a trait name exceeds 50 characters

**When** the validation script reports a duplicate

**Then** the script MAY:
- Truncate the display name (e.g., "very_long_trait_name_that_exc... (truncated)")
- Provide full name in verbose mode

---

## MODIFIED Requirements

### Requirement: Phenotype structure validation includes duplicate checking

Phenotype structure validation MUST verify trait name uniqueness in addition to existing structural checks.

**Previously**: Phenotype structure validation only checked for header row existence and minimum row count.

**Now**: Phenotype structure validation also verifies trait name uniqueness.

#### Scenario: Complete phenotype validation includes all checks

**Given** the validate-env.sh script is executed

**When** phenotype validation runs

**Then** the script MUST check:
- Phenotype file is tab-delimited (existing)
- First column is "Taxa" (existing)
- Header row is present (existing)
- At least 2 data rows (existing)
- **NEW: Trait names are unique** (exact duplicates, whitespace, case)
- Trait names follow valid format

---

## REMOVED Requirements

None. This change only adds validation; it does not remove any existing checks.
