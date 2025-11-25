# Proposal: Add Environment Validation and Dry-Run Mode

## Problem Statement

Users can submit 186 parallel GAPIT GWAS jobs with incorrect configuration and only discover errors after jobs fail, wasting cluster resources, time, and causing frustration. There is currently no pre-flight validation to catch configuration errors before submission.

### Real-World Scenario

**What happens now:**
1. User creates `.env` file with configuration
2. Sets `DATA_PATH_HOST=/mnt/hpi_dev/users/wrong/path`
3. Runs `submit-all-traits-runai.sh`
4. Script submits 186 jobs successfully
5. All 186 jobs start initializing
6. All 186 jobs fail: "File not found: /data/phenotype/iron_traits_edited.txt"
7. User realizes path was wrong
8. Must cleanup 186 failed jobs: `cleanup-runai.sh --all --force`
9. Fix configuration
10. Resubmit 186 jobs
11. **Total time wasted: 30-60 minutes of debugging + cleanup + resubmission**

**What we want:**
1. User creates `.env` file
2. Runs `validate-env.sh` (or `submit-all-traits-runai.sh --dry-run`)
3. Validation catches: "❌ Phenotype file not found: /mnt/hpi_dev/users/wrong/path/data/phenotype/iron_traits_edited.txt"
4. User fixes path in `.env`
5. Revalidates: "✅ All checks passed"
6. Submits with confidence
7. **Jobs run successfully**

### Configuration Errors We Want to Catch

**1. File Path Errors** (Most Common)
```bash
# Wrong cluster path
DATA_PATH_HOST=/mnt/hpi_dev/users/wrong_user/data
# → All jobs fail: "File not found"

# Typo in filename
PHENOTYPE_FILE=/data/phenotype/iron_traits_EDITED.txt  # should be iron_traits_edited.txt
# → All jobs fail: "No such file"
```

**2. Trait Index Errors**
```bash
# END_TRAIT exceeds column count
START_TRAIT=2
END_TRAIT=200  # But phenotype file only has 187 columns
# → Jobs 188-200 fail: "Trait index out of bounds"

# Invalid range
START_TRAIT=10
END_TRAIT=5  # End before start
# → No jobs submitted (logic error)
```

**3. Invalid GAPIT Parameters**
```bash
# Invalid model name
MODELS=BLINK,FarmCPU,INVALID
# → Jobs fail: "Unknown model: INVALID"

# PCA out of range
PCA_COMPONENTS=50  # Max is 20
# → Jobs fail: "PCA components must be 0-20"

# Invalid threshold
SNP_THRESHOLD=1.5  # Should be < 1.0 (p-value)
# → Jobs produce invalid results
```

**4. Docker Image Errors**
```bash
# Non-existent image tag
IMAGE=ghcr.io/.../gapit3-gwas-pipeline:nonexistent
# → All 186 jobs fail: ImagePullBackOff
# → Already addressed by improve-docker-workflow-ux
```

**5. Resource Allocation Errors**
```bash
# Insufficient memory
MEMORY=2G  # But GAPIT needs 16G minimum
# → Jobs fail: OOMKilled

# Too many concurrent jobs
MAX_CONCURRENT=500  # Cluster only has 100 nodes
# → Cluster overloaded, jobs stuck in pending
```

**6. Job Name Conflicts**
```bash
# Jobs already exist with same names
JOB_PREFIX=eberrigan-gapit-gwas
# → Jobs 2-187 already running
# → New submission fails or creates duplicate jobs
```

### Impact Analysis

**Without Validation:**
- **Frequency**: High (every new dataset or configuration change)
- **Time to discover error**: 5-30 minutes (after submission)
- **Recovery time**: 10-60 minutes (cleanup + resubmission)
- **Wasted resources**: 186 jobs × cluster time
- **User frustration**: High

**With Validation:**
- **Time to validate**: <30 seconds
- **Time to discover error**: Immediate (pre-submission)
- **Recovery time**: Seconds (just edit .env and revalidate)
- **Wasted resources**: None
- **User confidence**: High

## Proposed Solution

### Approach 1: Standalone Validation Script (Primary)

Create `scripts/validate-env.sh` that performs comprehensive pre-flight checks.

**Design Philosophy:**
- **Fast**: Complete validation in <30 seconds
- **Thorough**: Check all common failure points
- **Clear**: Actionable error messages
- **Graceful**: Work offline (skip network checks)
- **Standalone**: Can be run independently

**Validation Categories:**

#### 1. Environment File Validation
```bash
✅ .env file exists
✅ .env file is readable
✅ All required variables defined
✅ No syntax errors (malformed lines)
```

#### 2. Docker Image Validation
```bash
✅ IMAGE variable defined
✅ Image exists in registry (docker manifest inspect or gh CLI)
✅ Image tag format valid
```

#### 3. Cluster Path Validation
```bash
✅ DATA_PATH_HOST exists on cluster
✅ OUTPUT_PATH_HOST exists or parent directory writable
✅ Paths are absolute (not relative)
✅ Paths don't contain invalid characters
```

#### 4. Data File Validation
```bash
✅ GENOTYPE_FILE exists and readable
✅ PHENOTYPE_FILE exists and readable
✅ ACCESSION_IDS_FILE exists (if specified)
✅ File sizes reasonable (genotype >1MB, phenotype >1KB)
```

#### 5. Phenotype File Structure Validation
```bash
✅ File is tab-delimited
✅ First column is "Taxa"
✅ Column count matches expected traits
✅ Header row present
✅ At least 2 data rows (minimum samples)
```

#### 6. Trait Index Validation
```bash
✅ START_TRAIT >= 2 (column 1 is Taxa)
✅ END_TRAIT <= total columns
✅ START_TRAIT <= END_TRAIT
✅ Range produces >0 jobs
✅ Number of traits reasonable (<1000)
```

#### 7. GAPIT Parameter Validation
```bash
✅ MODELS contains valid model names
✅ PCA_COMPONENTS in range 0-20
✅ SNP_THRESHOLD is valid p-value (0 < x < 1)
✅ MAF_FILTER in range 0-0.5
✅ MULTIPLE_ANALYSIS is TRUE/FALSE
```

#### 8. RunAI Configuration Validation
```bash
✅ PROJECT defined and accessible (runai config project)
✅ JOB_PREFIX defined and valid format
✅ MAX_CONCURRENT reasonable (1-200)
✅ No conflicting jobs exist with same prefix
```

#### 9. Resource Allocation Validation
```bash
✅ CPU is reasonable (1-64)
✅ MEMORY is sufficient (>=16G recommended)
✅ Total resource request reasonable (CPU × MAX_CONCURRENT)
```

**Implementation:**

```bash
#!/bin/bash
# scripts/validate-env.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

# Parse arguments
ENV_FILE=".env"
VERBOSE=false
QUICK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quick|-q)
            QUICK=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

echo "🔍 Validating GAPIT GWAS Configuration"
echo "Environment file: $ENV_FILE"
echo ""

# Load .env file
if [[ ! -f "$ENV_FILE" ]]; then
    error ".env file not found: $ENV_FILE"
    exit 1
fi

source <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r$//')

# Run validation checks
check_environment_file
check_docker_image
check_cluster_paths
check_data_files
check_phenotype_structure
check_trait_indices
check_gapit_parameters
check_runai_config
check_resources

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✅ All validation checks passed!${NC}"
    echo ""
    echo "Configuration is ready for submission:"
    echo "  ./scripts/submit-all-traits-runai.sh"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Validation passed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Configuration is usable but review warnings above."
    exit 0
else
    echo -e "${RED}❌ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors above before submitting."
    exit 1
fi
```

### Approach 2: Dry-Run Mode for Submission Script (Secondary)

Add `--dry-run` flag to existing `submit-all-traits-runai.sh`.

**Benefits:**
- Shows exact job submission plan
- User sees what WOULD be submitted
- Integrated into existing workflow
- Can still use standalone validation for early checks

**Implementation:**

```bash
# In submit-all-traits-runai.sh, add flag parsing:

DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        # ... other flags
    esac
done

# Before job submission loop:
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Dry-run mode: No jobs will be submitted"
    echo ""

    # Run all validation
    validate_all

    # Show submission plan
    echo "Would submit $((END_TRAIT - START_TRAIT + 1)) jobs:"
    for trait_idx in $(seq $START_TRAIT $END_TRAIT); do
        echo "  - $JOB_PREFIX-$trait_idx"
    done

    echo ""
    echo "Ready to submit with: $0 (without --dry-run)"
    exit 0
fi
```

## Alternatives Considered

### Alternative 1: Validate Only at Submission Time

**Approach**: Add validation directly into `submit-all-traits-runai.sh` without standalone script or dry-run flag.

**Pros**:
- Automatic validation before every submission
- No extra script to maintain
- Users can't forget to validate

**Cons**:
- Can't validate configuration without submitting
- Slows down submission workflow
- No way to test configuration changes quickly
- Less flexible for CI/CD integration

**Verdict**: REJECT - Standalone validation is more flexible

### Alternative 2: Interactive Configuration Wizard

**Approach**: Create `scripts/configure-env.sh` that prompts user for each parameter and validates as they type.

**Pros**:
- Guides users through configuration
- Real-time validation
- Prevents errors from being entered

**Cons**:
- Much more complex to implement
- Less scriptable (not CI-friendly)
- Users who know what they're doing find it slow
- Hard to version control configuration

**Verdict**: REJECT - Too complex, less flexible than .env file approach

### Alternative 3: JSON Schema Validation

**Approach**: Convert .env to JSON and validate against a schema.

**Pros**:
- Formal schema definition
- Standard validation tools
- Better IDE support

**Cons**:
- Requires converting .env ↔ JSON
- More complex than bash validation
- Extra dependencies (jq, schema validator)
- Doesn't check cluster files/paths

**Verdict**: REJECT - Over-engineered for this use case

### Selected Approach: Standalone Script + Dry-Run Flag

**Rationale**:
- **Flexible**: Can validate without submitting
- **Fast**: Quick feedback loop for config changes
- **Comprehensive**: Can check files, cluster state, etc.
- **Optional**: Users can skip if confident
- **Scriptable**: Works in CI/CD pipelines
- **Graceful**: Works offline (skips network checks)

## Dependencies

**Required:**
- Bash 4.0+ (for associative arrays)
- Access to cluster filesystem (for file checks) OR SSH to cluster
- `runai` CLI (for project/job validation)

**Optional:**
- `gh` CLI or Docker CLI (for image validation - already implemented)
- `awk` (for phenotype column counting)
- `jq` (for JSON output if desired)

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Validation too slow | Low | Medium | Implement `--quick` mode, optimize checks |
| False positives (valid configs fail) | Medium | High | Thorough testing, make strict checks optional |
| False negatives (invalid configs pass) | Low | High | Comprehensive test matrix, add checks as issues discovered |
| Cluster access required | Medium | Medium | Graceful degradation, skip cluster checks if unavailable |
| Validation script has bugs | Medium | Medium | Unit tests for validation functions |

## Success Criteria

1. ✅ `validate-env.sh` catches 100% of common configuration errors
2. ✅ Validation completes in <30 seconds (full mode)
3. ✅ Validation completes in <5 seconds (quick mode)
4. ✅ No false positives on valid configurations
5. ✅ Error messages are clear and actionable
6. ✅ `--dry-run` shows accurate job submission plan
7. ✅ Works offline (skips network-dependent checks gracefully)
8. ✅ Exit codes follow convention (0=success, 1=validation failed, 2=script error)

## Timeline Estimate

- Validation script implementation: 2-3 hours
  - Environment file checks: 30 min
  - Docker image validation: 15 min (reuse existing)
  - Cluster path/file validation: 1 hour
  - Phenotype structure validation: 45 min
  - Parameter validation: 30 min
  - RunAI config validation: 30 min
- Dry-run integration: 1 hour
- Documentation: 1 hour
- Testing (create test cases): 1 hour
- **Total**: ~5-6 hours

## Open Questions

1. **Should validation require cluster access?**
   - Pro: Can verify files exist
   - Con: Can't validate offline
   - **Decision**: Make cluster checks optional, warn if skipped

2. **Should we validate data file contents (e.g., genotype format)?**
   - Pro: Catches format errors early
   - Con: Very slow for 2GB genotype file
   - **Decision**: No - too slow. Maybe add `--thorough` mode later

3. **Should validation check cluster capacity?**
   - Pro: Warns if requesting more resources than available
   - Con: Requires RunAI API access, capacity is dynamic
   - **Decision**: No - just check if MAX_CONCURRENT is reasonable (<200)

4. **Should we auto-fix common errors?**
   - Example: Convert relative paths to absolute
   - Pro: More user-friendly
   - Con: Could hide issues, unexpected behavior
   - **Decision**: No - just report errors and let user fix

5. **Should validation be mandatory before submission?**
   - Pro: Forces users to validate
   - Con: Slows down workflow, annoying for experts
   - **Decision**: No - optional but recommended

## Next Steps

1. Get approval for proposal
2. Implement `scripts/validate-env.sh`
3. Add `--dry-run` flag to `submit-all-traits-runai.sh`
4. Create comprehensive test cases
5. Update documentation
6. Test with real .env files
7. Deploy and gather user feedback
