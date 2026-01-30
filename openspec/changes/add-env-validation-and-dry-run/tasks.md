# Tasks: Add Environment Validation and Dry-Run Mode

## Overview

Implementation tasks for comprehensive .env validation and dry-run mode.

**Total Estimated Time**: 4-5 hours

---

## Phase 1: Validation Script Core (2 hours)

### Task 1.1: Create validate-env.sh skeleton (20 min)

**File**: `scripts/validate-env.sh`

**Steps**:
1. [ ] Create script file with shebang and set options
2. [ ] Add color definitions for output
3. [ ] Implement argument parsing (--env-file, --verbose, --quick, --help)
4. [ ] Add error/warning/success/info helper functions
5. [ ] Add section header function
6. [ ] Implement exit code logic (0/1/2)

**Acceptance Criteria**:
- [ ] Script is executable
- [ ] Help text displays correctly
- [ ] Arguments parse correctly
- [ ] Error counters work

---

### Task 1.2: Implement Environment File Validation (15 min)

**Function**: `check_environment_file()`

**Steps**:
1. [ ] Check .env file exists
2. [ ] Check .env file is readable
3. [ ] Load .env with error handling
4. [ ] Check required variables defined
5. [ ] Report missing variables

**Required variables**:
```bash
IMAGE DATA_PATH_HOST OUTPUT_PATH_HOST
GENOTYPE_FILE PHENOTYPE_FILE
START_TRAIT END_TRAIT
MODELS PCA_COMPONENTS
PROJECT JOB_PREFIX
```

**Acceptance Criteria**:
- [ ] Detects missing .env file
- [ ] Reports all missing required variables
- [ ] Handles malformed .env gracefully

---

### Task 1.3: Implement Docker Image Validation (10 min)

**Function**: `check_docker_image()`

**Steps**:
1. [ ] Reuse existing image validation from submit script
2. [ ] Check IMAGE variable defined
3. [ ] Validate tag format
4. [ ] Check image exists (docker manifest or gh CLI)
5. [ ] Handle missing validation tools gracefully

**Acceptance Criteria**:
- [ ] Detects invalid image tags
- [ ] Verifies image exists in registry
- [ ] Works offline (warns if tools unavailable)

---

### Task 1.4: Implement Cluster Path Validation (20 min)

**Function**: `check_cluster_paths()`

**Steps**:
1. [ ] Check DATA_PATH_HOST is absolute path
2. [ ] Check OUTPUT_PATH_HOST is absolute path
3. [ ] Validate no invalid characters in paths
4. [ ] Check DATA_PATH_HOST directory exists
5. [ ] Check OUTPUT_PATH_HOST exists or parent writable
6. [ ] Handle cluster not accessible gracefully

**Acceptance Criteria**:
- [ ] Detects relative paths
- [ ] Detects non-existent data directories
- [ ] Warns if cluster not accessible
- [ ] Works on Windows with mounted Z: drive

---

### Task 1.5: Implement Data File Validation (25 min)

**Function**: `check_data_files()`

**Steps**:
1. [ ] Check GENOTYPE_FILE exists
2. [ ] Check PHENOTYPE_FILE exists
3. [ ] Check ACCESSION_IDS_FILE exists (if set)
4. [ ] Validate file sizes reasonable
5. [ ] Check files are readable

**File size checks**:
- Genotype: >1MB (should be GB-scale)
- Phenotype: >1KB
- Accession IDs: >100 bytes

**Acceptance Criteria**:
- [ ] Detects missing files
- [ ] Warns about suspiciously small files
- [ ] Handles cluster access issues

---

### Task 1.6: Implement Phenotype Structure Validation (30 min)

**Function**: `check_phenotype_structure()`

**Steps**:
1. [ ] Read first line of phenotype file
2. [ ] Check file is tab-delimited
3. [ ] Count total columns
4. [ ] Check first column is "Taxa"
5. [ ] Check at least 2 data rows exist
6. [ ] Store column count for trait validation

**Acceptance Criteria**:
- [ ] Detects wrong delimiter (comma, space)
- [ ] Detects missing Taxa column
- [ ] Accurately counts columns
- [ ] Stores PHENOTYPE_COLUMNS variable

---

### Task 1.7: Implement Trait Index Validation (20 min)

**Function**: `check_trait_indices()`

**Steps**:
1. [ ] Check START_TRAIT >= 2
2. [ ] Check END_TRAIT <= PHENOTYPE_COLUMNS
3. [ ] Check START_TRAIT <= END_TRAIT
4. [ ] Calculate number of traits
5. [ ] Warn if trait range very large (>500)

**Acceptance Criteria**:
- [ ] Detects START_TRAIT = 1 (should be 2)
- [ ] Detects END_TRAIT exceeding columns
- [ ] Detects inverted range
- [ ] Shows number of traits to be processed

---

### Task 1.8: Implement GAPIT Parameter Validation (20 min)

**Function**: `check_gapit_parameters()`

**Steps**:
1. [ ] Validate MODELS (comma-separated list)
2. [ ] Check each model name valid
3. [ ] Check PCA_COMPONENTS in range 0-20
4. [ ] Check SNP_THRESHOLD is valid p-value (0 < x < 1)
5. [ ] Check MAF_FILTER in range 0-0.5
6. [ ] Check MULTIPLE_ANALYSIS is TRUE/FALSE

**Valid models**: `BLINK, FarmCPU, MLM, MLMM, SUPER, CMLM`

**Acceptance Criteria**:
- [ ] Detects invalid model names
- [ ] Detects PCA out of range
- [ ] Detects invalid threshold values

---

## Phase 2: RunAI and Resource Validation (1 hour)

### Task 2.1: Implement RunAI Config Validation (30 min)

**Function**: `check_runai_config()`

**Steps**:
1. [ ] Check PROJECT variable defined
2. [ ] Test runai CLI accessible
3. [ ] Check project accessible (`runai config project`)
4. [ ] Check JOB_PREFIX defined and valid format
5. [ ] Check for conflicting jobs (`runai workspace list`)
6. [ ] Validate MAX_CONCURRENT reasonable (1-200)

**Acceptance Criteria**:
- [ ] Detects runai CLI not installed
- [ ] Detects inaccessible project
- [ ] Warns about existing jobs with same prefix
- [ ] Validates MAX_CONCURRENT range

---

### Task 2.2: Implement Resource Validation (15 min)

**Function**: `check_resources()`

**Steps**:
1. [ ] Check CPU is reasonable (1-64)
2. [ ] Check MEMORY is sufficient (warn if <16G)
3. [ ] Calculate total resource request
4. [ ] Warn if very large resource request

**Resource checks**:
- CPU: 1-64 cores (error if outside)
- MEMORY: >=8G (warn if <16G, error if <8G)
- Total: Warn if CPU × MAX_CONCURRENT > 1000

**Acceptance Criteria**:
- [ ] Detects unreasonable CPU values
- [ ] Warns about low memory
- [ ] Calculates peak resource usage

---

### Task 2.3: Implement Summary Output (15 min)

**Steps**:
1. [ ] Add summary section at end
2. [ ] Show total errors and warnings
3. [ ] Display appropriate exit message
4. [ ] Return correct exit code

**Output examples**:
```
✅ All validation checks passed!
Ready to submit: ./scripts/submit-all-traits-runai.sh

⚠ Validation passed with 2 warning(s)
Review warnings above. Configuration is usable.

❌ Validation failed with 3 error(s) and 1 warning(s)
Please fix errors above before submitting.
```

**Acceptance Criteria**:
- [ ] Summary shows correct counts
- [ ] Exit code matches validation result
- [ ] Helpful next-step messages

---

## Phase 3: Dry-Run Integration (45 min)

### Task 3.1: Add --dry-run Flag to Submit Script (20 min)

**File**: `scripts/submit-all-traits-runai.sh`

**Steps**:
1. [ ] Add `--dry-run` flag parsing
2. [ ] Add `DRY_RUN=false` variable
3. [ ] Update help text with --dry-run
4. [ ] Add dry-run mode header

**Acceptance Criteria**:
- [ ] Flag parses correctly
- [ ] Help text updated
- [ ] Can combine with other flags

---

### Task 3.2: Implement Dry-Run Validation (15 min)

**File**: `scripts/submit-all-traits-runai.sh`

**Steps**:
1. [ ] Call validation functions in dry-run mode
2. [ ] OR call `validate-env.sh` as subprocess
3. [ ] Exit if validation fails
4. [ ] Continue to submission plan if passes

**Acceptance Criteria**:
- [ ] Runs same validation as standalone script
- [ ] Exits on validation failure
- [ ] Shows validation results

---

### Task 3.3: Implement Submission Plan Display (10 min)

**File**: `scripts/submit-all-traits-runai.sh`

**Steps**:
1. [ ] Show number of jobs to be submitted
2. [ ] Show job name range
3. [ ] Show resource allocation (per job and peak)
4. [ ] List first 5 job names as examples
5. [ ] Show command to actually submit

**Acceptance Criteria**:
- [ ] Plan is clear and accurate
- [ ] Shows peak resource usage
- [ ] Provides submit command

---

## Phase 4: Documentation (1 hour)

### Task 4.1: Create VALIDATION.md Documentation (30 min)

**File**: `docs/VALIDATION.md`

**Sections**:
1. [ ] Overview
2. [ ] Quick Start
3. [ ] Validation Checks (all 9 categories)
4. [ ] Command Line Options
5. [ ] Dry-Run Mode
6. [ ] Exit Codes
7. [ ] Troubleshooting
8. [ ] Examples

**Acceptance Criteria**:
- [ ] All validation checks documented
- [ ] Examples for each scenario
- [ ] Troubleshooting common issues

---

### Task 4.2: Update Existing Documentation (15 min)

**Files**:
- `docs/RUNAI_QUICK_REFERENCE.md`
- `README.md`

**Updates**:
1. [ ] Add validation section to quick reference
2. [ ] Add dry-run examples
3. [ ] Link to VALIDATION.md
4. [ ] Update submission workflow

**Acceptance Criteria**:
- [ ] Quick reference updated
- [ ] README mentions validation
- [ ] All links work

---

### Task 4.3: Add Help Text and Examples (15 min)

**File**: `scripts/validate-env.sh`

**Steps**:
1. [ ] Implement show_help() function
2. [ ] Add usage examples
3. [ ] Document all flags
4. [ ] Add troubleshooting hints

**Help text should include**:
- Basic usage
- All flags with descriptions
- Examples (quick, verbose, custom env file)
- Exit code meanings

**Acceptance Criteria**:
- [ ] Help is comprehensive
- [ ] Examples are accurate
- [ ] Easy to understand

---

## Phase 5: Testing (1 hour)

### Task 5.1: Create Test Fixtures (20 min)

**Directory**: `tests/fixtures/`

**Test .env files**:
1. [ ] `.env.valid` - Should pass all checks
2. [ ] `.env.missing-phenotype` - File not found
3. [ ] `.env.bad-trait-range` - END_TRAIT too high
4. [ ] `.env.invalid-models` - Bad model name
5. [ ] `.env.low-memory` - Memory warning
6. [ ] `.env.inverted-range` - START > END

**Acceptance Criteria**:
- [ ] Each fixture tests specific error
- [ ] All fixtures load without syntax errors

---

### Task 5.2: Manual Testing (30 min)

**Test Cases**:

1. [ ] **Valid configuration**
   ```bash
   ./scripts/validate-env.sh
   # Expected: All pass, exit 0
   ```

2. [ ] **Missing phenotype file**
   ```bash
   # Edit .env with wrong path
   ./scripts/validate-env.sh
   # Expected: Error, exit 1
   ```

3. [ ] **Invalid trait range**
   ```bash
   # Set END_TRAIT=300
   ./scripts/validate-env.sh
   # Expected: Error about column count
   ```

4. [ ] **Quick mode**
   ```bash
   ./scripts/validate-env.sh --quick
   # Expected: Fast (<5s), some checks skipped
   ```

5. [ ] **Verbose mode**
   ```bash
   ./scripts/validate-env.sh --verbose
   # Expected: Detailed output for all checks
   ```

6. [ ] **Dry-run mode**
   ```bash
   ./scripts/submit-all-traits-runai.sh --dry-run
   # Expected: Validation + submission plan
   ```

7. [ ] **Offline mode**
   ```bash
   # Disconnect from cluster
   ./scripts/validate-env.sh
   # Expected: Warnings, not errors
   ```

**Acceptance Criteria**:
- [ ] All test cases pass
- [ ] Error messages clear
- [ ] No false positives on valid config

---

### Task 5.3: Integration Testing (10 min)

**Workflow Test**:

```bash
# 1. Create test .env with intentional error
cp .env .env.backup
echo "END_TRAIT=300" >> .env

# 2. Validate - should fail
./scripts/validate-env.sh
# Expected: Error about trait range

# 3. Fix error
sed -i 's/END_TRAIT=300/END_TRAIT=187/' .env

# 4. Revalidate - should pass
./scripts/validate-env.sh
# Expected: All checks pass

# 5. Dry-run - should show plan
./scripts/submit-all-traits-runai.sh --dry-run
# Expected: Submission plan with 186 jobs

# 6. Restore
mv .env.backup .env
```

**Acceptance Criteria**:
- [ ] Error correctly detected
- [ ] Fix correctly applied
- [ ] Revalidation passes
- [ ] Dry-run shows accurate plan

---

## Summary

**Total Tasks**: 18 tasks across 5 phases
**Estimated Time**: 4-5 hours

**Critical Path**:
1. Tasks 1.1-1.8 (validation functions) → All subsequent tasks
2. Task 2.3 (summary) → Testing
3. Tasks 3.1-3.3 (dry-run) → Integration testing

**Parallelizable**:
- Documentation (Phase 4) can overlap with implementation
- Test fixtures (5.1) can be created early

**Verification Points**:
- After Phase 1: Test standalone validation
- After Phase 2: Test all validation categories
- After Phase 3: Test dry-run mode
- After Phase 4: Review all documentation
- After Phase 5: Full integration test

**Dependencies**:
- Phase 3 requires Phase 1 complete (reuses validation)
- Phase 5 requires Phases 1-3 complete (testing)
- Phase 4 can proceed in parallel with implementation

---

## Next Steps After Completion

1. Deploy to production
2. Update onboarding docs to recommend validation
3. Add validation to CI/CD pipeline
4. Gather user feedback
5. Consider Phase 2 enhancements (JSON output, auto-fix suggestions)
