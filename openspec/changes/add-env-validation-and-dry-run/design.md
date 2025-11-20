# Design: Environment Validation and Dry-Run Mode

## Architecture Overview

Two complementary validation mechanisms:
1. **Standalone validator** (`validate-env.sh`) - Comprehensive pre-flight checks
2. **Dry-run mode** (`--dry-run` flag) - Integrated submission preview

```
┌─────────────────────────────────────────────────────────────┐
│                    User Workflow                            │
│                                                              │
│  ┌──────────────┐                                           │
│  │ Create .env  │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────────────────────────────┐                   │
│  │  Option 1: Standalone Validation    │                   │
│  │  ./scripts/validate-env.sh          │                   │
│  └──────┬───────────────────────────────┘                   │
│         │                                                    │
│         ├─ ✅ Pass → Continue                               │
│         └─ ❌ Fail → Fix .env, retry                        │
│                                                              │
│  ┌──────────────────────────────────────┐                   │
│  │  Option 2: Dry-Run Submission       │                   │
│  │  ./scripts/submit-all-traits-runai.sh --dry-run        │
│  └──────┬───────────────────────────────┘                   │
│         │                                                    │
│         ├─ ✅ Pass → Shows submission plan                  │
│         └─ ❌ Fail → Fix .env, retry                        │
│                                                              │
│  ┌──────────────────────────────────────┐                   │
│  │  Actual Submission                   │                   │
│  │  ./scripts/submit-all-traits-runai.sh                   │
│  └──────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

## Validation Architecture

### Validation Categories (9 Total)

```
validate-env.sh
│
├─ 1. Environment File
│    ├─ File exists
│    ├─ Readable
│    ├─ No syntax errors
│    └─ Required vars defined
│
├─ 2. Docker Image
│    ├─ Variable defined
│    ├─ Tag format valid
│    └─ Image exists (reuse existing validation)
│
├─ 3. Cluster Paths
│    ├─ Paths absolute
│    ├─ No invalid chars
│    ├─ DATA_PATH_HOST exists
│    └─ OUTPUT_PATH_HOST writable
│
├─ 4. Data Files
│    ├─ GENOTYPE_FILE exists
│    ├─ PHENOTYPE_FILE exists
│    ├─ ACCESSION_IDS_FILE exists (if set)
│    └─ File sizes reasonable
│
├─ 5. Phenotype Structure
│    ├─ Tab-delimited
│    ├─ First column = "Taxa"
│    ├─ Column count
│    └─ Minimum rows
│
├─ 6. Trait Indices
│    ├─ START_TRAIT >= 2
│    ├─ END_TRAIT <= columns
│    ├─ START <= END
│    └─ Range reasonable
│
├─ 7. GAPIT Parameters
│    ├─ MODELS valid
│    ├─ PCA_COMPONENTS 0-20
│    ├─ SNP_THRESHOLD valid
│    └─ MAF_FILTER 0-0.5
│
├─ 8. RunAI Config
│    ├─ PROJECT accessible
│    ├─ JOB_PREFIX valid
│    ├─ No conflicts
│    └─ MAX_CONCURRENT reasonable
│
└─ 9. Resources
     ├─ CPU reasonable
     ├─ MEMORY sufficient
     └─ Total resources OK
```

## Component Design

### 1. Validation Functions

Each validation category is a separate bash function:

```bash
check_environment_file() {
    section "Environment File"

    # Check file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        error ".env file not found: $ENV_FILE"
        return
    fi
    success ".env file exists"

    # Check required variables
    local required_vars=(
        "IMAGE" "DATA_PATH_HOST" "OUTPUT_PATH_HOST"
        "GENOTYPE_FILE" "PHENOTYPE_FILE"
        "START_TRAIT" "END_TRAIT"
        "MODELS" "PCA_COMPONENTS"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required variable not set: $var"
        else
            [[ "$VERBOSE" == "true" ]] && success "$var is set"
        fi
    done
}

check_phenotype_structure() {
    section "Phenotype File Structure"

    local phenotype_path="$DATA_PATH_HOST/phenotype/${PHENOTYPE_FILE##*/}"

    # Count columns
    local total_columns=$(head -1 "$phenotype_path" | awk -F'\t' '{print NF}')
    success "Columns: $total_columns"

    # Check first column is Taxa
    local first_col=$(head -1 "$phenotype_path" | cut -f1)
    if [[ "$first_col" != "Taxa" ]]; then
        error "First column should be 'Taxa', found: '$first_col'"
    else
        success "First column is 'Taxa'"
    fi

    # Store for trait validation
    PHENOTYPE_COLUMNS=$total_columns
}

check_trait_indices() {
    section "Trait Indices"

    if [[ $START_TRAIT -lt 2 ]]; then
        error "START_TRAIT must be >= 2 (column 1 is Taxa)"
    fi

    if [[ $END_TRAIT -gt $PHENOTYPE_COLUMNS ]]; then
        error "END_TRAIT ($END_TRAIT) exceeds column count ($PHENOTYPE_COLUMNS)"
    fi

    if [[ $START_TRAIT -gt $END_TRAIT ]]; then
        error "START_TRAIT ($START_TRAIT) > END_TRAIT ($END_TRAIT)"
    fi

    local num_traits=$((END_TRAIT - START_TRAIT + 1))
    success "Trait range: $START_TRAIT-$END_TRAIT ($num_traits traits)"

    if [[ $num_traits -gt 500 ]]; then
        warning "Large number of traits ($num_traits) - submission may take a while"
    fi
}
```

### 2. Dry-Run Mode Integration

```bash
# In submit-all-traits-runai.sh

DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        # ... other flags
    esac
done

# Before submission
if [[ "$DRY_RUN" == "true" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "DRY-RUN MODE: No jobs will be submitted"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Run validation (call validate-env.sh or inline checks)
    validate_configuration

    # Show submission plan
    echo ""
    echo "📋 Job Submission Plan"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Jobs to submit: $((END_TRAIT - START_TRAIT + 1))"
    echo "Job names: $JOB_PREFIX-$START_TRAIT to $JOB_PREFIX-$END_TRAIT"
    echo "Max concurrent: $MAX_CONCURRENT"
    echo "Resources per job: $CPU CPU, $MEMORY memory"
    echo "Total peak resources: $((CPU * MAX_CONCURRENT)) CPU, ~$((${MEMORY%G} * MAX_CONCURRENT))G memory"
    echo ""

    # List first few jobs
    echo "First 5 jobs:"
    for i in $(seq $START_TRAIT $((START_TRAIT + 4))); do
        [[ $i -gt $END_TRAIT ]] && break
        echo "  $JOB_PREFIX-$i: Trait index $i"
    done
    echo "  ..."
    echo ""

    echo "✅ Configuration validated successfully"
    echo ""
    echo "To submit these jobs, run:"
    echo "  $0"
    exit 0
fi
```

## Error Handling Strategy

### Error Levels

```bash
# ERROR - Must fix before submission
error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    ((ERRORS++))
}

# WARNING - Should review but not blocking
warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}" >&2
    ((WARNINGS++))
}

# SUCCESS - Check passed
success() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${GREEN}✅ $1${NC}"
}

# INFO - Additional information
info() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}ℹ️  $1${NC}"
}
```

### Exit Codes

```bash
0  = All validation passed (no errors, warnings OK)
1  = Validation failed (errors found)
2  = Script error (missing file, invalid arguments, etc.)
```

## Performance Optimization

### Quick Mode

For rapid feedback during config iteration:

```bash
# Skip slow checks in quick mode
if [[ "$QUICK" == "true" ]]; then
    # Skip cluster file checks (slow)
    # Skip Docker image pull test (slow)
    # Only validate .env syntax and parameters
fi
```

**Full mode**: ~20-30 seconds (includes cluster file checks)
**Quick mode**: ~2-5 seconds (local checks only)

### Caching

Cache expensive checks within a validation run:

```bash
# Cache phenotype column count
if [[ -z "$PHENOTYPE_COLUMNS" ]]; then
    PHENOTYPE_COLUMNS=$(head -1 "$phenotype_path" | awk -F'\t' '{print NF}')
fi
```

## Graceful Degradation

### Offline Mode

If cluster not accessible:

```bash
check_cluster_paths() {
    if [[ ! -d "/mnt/hpi_dev" ]] && [[ ! -f "$DATA_PATH_HOST" ]]; then
        warning "Cluster filesystem not accessible - skipping file checks"
        info "Cluster validation will be performed when jobs start"
        return
    fi

    # ... perform file checks
}
```

### Missing Tools

```bash
check_docker_image() {
    if ! command -v docker >/dev/null 2>&1 && ! command -v gh >/dev/null 2>&1; then
        warning "Neither docker nor gh CLI available - skipping image validation"
        info "Image will be validated when jobs start"
        return
    fi

    # ... perform image check
}
```

## Testing Strategy

### Unit Tests (BATS)

```bash
# tests/validate-env.bats

@test "validation passes with valid .env" {
    run ./scripts/validate-env.sh --env-file tests/fixtures/.env.valid
    [ "$status" -eq 0 ]
}

@test "validation fails with missing phenotype file" {
    run ./scripts/validate-env.sh --env-file tests/fixtures/.env.missing-phenotype
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Phenotype file not found" ]]
}

@test "validation catches invalid trait range" {
    run ./scripts/validate-env.sh --env-file tests/fixtures/.env.bad-trait-range
    [ "$status" -eq 1 ]
    [[ "$output" =~ "END_TRAIT" ]]
}
```

### Integration Tests

Create test .env files with known issues:

```
tests/fixtures/
├── .env.valid                   # Should pass
├── .env.missing-phenotype       # Should fail: file not found
├── .env.bad-trait-range         # Should fail: END_TRAIT > columns
├── .env.invalid-models          # Should fail: bad model name
├── .env.insufficient-memory     # Should warn: memory too low
└── .env.no-cluster-access       # Should pass with warnings
```

## Documentation Structure

```
docs/VALIDATION.md (new file)
├── Overview
├── Quick Start
│   ├── Basic usage
│   └── Common scenarios
├── Validation Checks
│   ├── Environment file
│   ├── Docker image
│   ├── Cluster paths
│   ├── Data files
│   ├── Phenotype structure
│   ├── Trait indices
│   ├── GAPIT parameters
│   ├── RunAI config
│   └── Resources
├── Command Line Options
│   ├── --env-file
│   ├── --verbose
│   ├── --quick
│   └── --help
├── Dry-Run Mode
├── Exit Codes
├── Troubleshooting
└── Examples

Update to docs/RUNAI_QUICK_REFERENCE.md:
- Add validation section
- Add dry-run examples
```

## Future Enhancements

### Phase 2

1. **JSON output mode** - For CI/CD integration
   ```bash
   ./scripts/validate-env.sh --json
   # Outputs structured JSON with all check results
   ```

2. **Fix suggestions** - Auto-suggest corrections
   ```bash
   ❌ ERROR: END_TRAIT (200) exceeds column count (187)
   💡 Suggestion: Set END_TRAIT=187
   ```

3. **Configuration templates** - Pre-validated configs
   ```bash
   ./scripts/validate-env.sh --template arabidopsis-186-traits
   # Generates .env with validated defaults
   ```

4. **Remote validation** - Validate on cluster
   ```bash
   ./scripts/validate-env.sh --remote cluster-node
   # SSH to cluster and run validation there
   ```
