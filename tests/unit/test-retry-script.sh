#!/usr/bin/env bash
# ==============================================================================
# Unit Tests for retry-failed-traits.sh
# ==============================================================================
# Tests the retry script logic without requiring RunAI cluster access.
# Uses mock data and pattern matching to validate script behavior.
# ==============================================================================

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RETRY_SCRIPT="${PROJECT_ROOT}/scripts/retry-failed-traits.sh"
BULK_SCRIPT="${PROJECT_ROOT}/scripts/bulk-resubmit-traits.sh"
SUBMIT_SCRIPT="${PROJECT_ROOT}/scripts/submit-all-traits-runai.sh"

TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local test_name="$3"

    if [[ "$actual" == "$expected" ]]; then
        log_info "PASS: $test_name"
        ((TESTS_PASSED++)) || true
        return 0
    else
        log_error "FAIL: $test_name"
        log_error "  Expected: '$expected'"
        log_error "  Actual:   '$actual'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"

    if echo "$output" | grep -qF -- "$expected"; then
        log_info "PASS: $test_name"
        ((TESTS_PASSED++)) || true
        return 0
    else
        log_error "FAIL: $test_name"
        log_error "  Expected to find: '$expected'"
        log_error "  In output: '$output'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_exit_code() {
    local actual="$1"
    local expected="$2"
    local test_name="$3"

    if [[ "$actual" -eq "$expected" ]]; then
        log_info "PASS: $test_name"
        ((TESTS_PASSED++)) || true
        return 0
    else
        log_error "FAIL: $test_name"
        log_error "  Expected exit code: $expected"
        log_error "  Actual exit code:   $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# ==============================================================================
# Test: Script Syntax Validation
# ==============================================================================

test_syntax_validation() {
    echo ""
    echo "=== Test: Script Syntax Validation ==="

    # Test retry script syntax
    if bash -n "$RETRY_SCRIPT" 2>/dev/null; then
        log_info "PASS: retry-failed-traits.sh has valid syntax"
        ((TESTS_PASSED++)) || true
    else
        log_error "FAIL: retry-failed-traits.sh has syntax errors"
        ((TESTS_FAILED++))
    fi

    # Test bulk resubmit script syntax
    if bash -n "$BULK_SCRIPT" 2>/dev/null; then
        log_info "PASS: bulk-resubmit-traits.sh has valid syntax"
        ((TESTS_PASSED++)) || true
    else
        log_error "FAIL: bulk-resubmit-traits.sh has syntax errors"
        ((TESTS_FAILED++))
    fi

    # Test submit script syntax
    if bash -n "$SUBMIT_SCRIPT" 2>/dev/null; then
        log_info "PASS: submit-all-traits-runai.sh has valid syntax"
        ((TESTS_PASSED++)) || true
    else
        log_error "FAIL: submit-all-traits-runai.sh has syntax errors"
        ((TESTS_FAILED++))
    fi
}

# ==============================================================================
# Test: Help Flag
# ==============================================================================

test_help_flag() {
    echo ""
    echo "=== Test: Help Flag ==="

    local help_output
    help_output=$("$RETRY_SCRIPT" --help 2>&1) || true

    assert_contains "$help_output" "Usage:" "Help shows usage"
    assert_contains "$help_output" "--dry-run" "Help mentions --dry-run"
    assert_contains "$help_output" "--max-retries" "Help mentions --max-retries"
    assert_contains "$help_output" "--retry-delay" "Help mentions --retry-delay"
    assert_contains "$help_output" "EXIT CODES:" "Help shows exit codes"
    assert_contains "$help_output" "EXAMPLES:" "Help shows examples"
}

# ==============================================================================
# Test: Trait Index Extraction
# ==============================================================================

test_trait_index_extraction() {
    echo ""
    echo "=== Test: Trait Index Extraction ==="

    # Test various job name formats
    local job_prefix="eberrigan-gapit-gwas"

    # Test simple numeric index
    local job_name="eberrigan-gapit-gwas-42"
    local trait_idx
    trait_idx=$(echo "$job_name" | sed "s/^${job_prefix}-//")
    assert_equals "$trait_idx" "42" "Extract index 42 from job name"

    # Test single digit
    job_name="eberrigan-gapit-gwas-5"
    trait_idx=$(echo "$job_name" | sed "s/^${job_prefix}-//")
    assert_equals "$trait_idx" "5" "Extract single digit index"

    # Test triple digit
    job_name="eberrigan-gapit-gwas-187"
    trait_idx=$(echo "$job_name" | sed "s/^${job_prefix}-//")
    assert_equals "$trait_idx" "187" "Extract triple digit index"

    # Test different prefix
    job_prefix="gapit3-trait"
    job_name="gapit3-trait-100"
    trait_idx=$(echo "$job_name" | sed "s/^${job_prefix}-//")
    assert_equals "$trait_idx" "100" "Extract index with different prefix"
}

# ==============================================================================
# Test: Mount Failure Detection Patterns
# ==============================================================================

test_mount_failure_detection() {
    echo ""
    echo "=== Test: Mount Failure Detection Patterns ==="

    # Pattern 1: INFRASTRUCTURE MOUNT FAILURE
    local logs="[2024-12-10 10:00:00] [ERROR] INFRASTRUCTURE MOUNT FAILURE: /data is not a mount point"
    if echo "$logs" | grep -qi "INFRASTRUCTURE MOUNT FAILURE"; then
        log_info "PASS: Detect INFRASTRUCTURE MOUNT FAILURE pattern"
        ((TESTS_PASSED++)) || true
    else
        log_error "FAIL: Did not detect INFRASTRUCTURE MOUNT FAILURE pattern"
        ((TESTS_FAILED++))
    fi

    # Pattern 2: mount not mount point
    logs="[ERROR] /data mount is not a mount point, volumes may not be attached"
    if echo "$logs" | grep -qi "mount.*not.*mount point"; then
        log_info "PASS: Detect 'mount not mount point' pattern"
        ((TESTS_PASSED++)) || true
    else
        log_error "FAIL: Did not detect 'mount not mount point' pattern"
        ((TESTS_FAILED++))
    fi

    # Pattern 3: Should NOT match config errors
    logs="[ERROR] Missing required files: /data/genotype.hmp.txt"
    if echo "$logs" | grep -qi "INFRASTRUCTURE MOUNT FAILURE\|mount.*not.*mount point"; then
        log_error "FAIL: Incorrectly matched config error as mount failure"
        ((TESTS_FAILED++))
    else
        log_info "PASS: Correctly ignored config error (not mount failure)"
        ((TESTS_PASSED++)) || true
    fi

    # Pattern 4: Should NOT match general errors
    logs="[ERROR] R script failed with exit code 1"
    if echo "$logs" | grep -qi "INFRASTRUCTURE MOUNT FAILURE\|mount.*not.*mount point"; then
        log_error "FAIL: Incorrectly matched R error as mount failure"
        ((TESTS_FAILED++))
    else
        log_info "PASS: Correctly ignored R error (not mount failure)"
        ((TESTS_PASSED++)) || true
    fi
}

# ==============================================================================
# Test: Job Prefix Filtering
# ==============================================================================

test_job_prefix_filtering() {
    echo ""
    echo "=== Test: Job Prefix Filtering ==="

    local job_prefix="gapit3-trait"

    # Simulate runai workspace list output with various job names
    local runai_output="  gapit3-trait-2     Running    2h
  gapit3-trait-10    Pending    5m
  other-job-1        Running    1h
  gapit3-trait-100   Failed     10m
  different-prefix-5 Succeeded  30m"

    # Filter by prefix
    local filtered
    filtered=$(echo "$runai_output" | grep "^[[:space:]]*$job_prefix-" | wc -l)
    assert_equals "$filtered" "3" "Filter matches 3 jobs with correct prefix"

    # Verify specific job is included
    if echo "$runai_output" | grep -q "^[[:space:]]*$job_prefix-100"; then
        log_info "PASS: Filter includes gapit3-trait-100"
        ((TESTS_PASSED++)) || true
    else
        log_error "FAIL: Filter should include gapit3-trait-100"
        ((TESTS_FAILED++))
    fi

    # Verify other jobs are excluded
    if echo "$runai_output" | grep "^[[:space:]]*$job_prefix-" | grep -q "other-job"; then
        log_error "FAIL: Filter should exclude other-job-1"
        ((TESTS_FAILED++))
    else
        log_info "PASS: Filter excludes other-job-1"
        ((TESTS_PASSED++)) || true
    fi
}

# ==============================================================================
# Test: Active State Counting
# ==============================================================================

test_active_state_counting() {
    echo ""
    echo "=== Test: Active State Counting ==="

    local job_prefix="gapit3-trait"

    # Simulate runai output with various states
    local runai_output="  gapit3-trait-1   Running           2h
  gapit3-trait-2   Pending           5m
  gapit3-trait-3   ContainerCreating 1m
  gapit3-trait-4   Succeeded         30m
  gapit3-trait-5   Failed            10m
  gapit3-trait-6   Completed         1h"

    # Count active (non-terminal) jobs
    local active_count
    active_count=$(echo "$runai_output" | grep "^[[:space:]]*$job_prefix-" | grep -vE "Succeeded|Failed|Completed" | wc -l)
    assert_equals "$active_count" "3" "Count 3 active jobs (Running, Pending, ContainerCreating)"

    # Count terminal jobs
    local terminal_count
    terminal_count=$(echo "$runai_output" | grep "^[[:space:]]*$job_prefix-" | grep -E "Succeeded|Failed|Completed" | wc -l)
    assert_equals "$terminal_count" "3" "Count 3 terminal jobs (Succeeded, Failed, Completed)"
}

# ==============================================================================
# Test: Exponential Backoff Calculation
# ==============================================================================

test_exponential_backoff() {
    echo ""
    echo "=== Test: Exponential Backoff Calculation ==="

    local base_delay=30

    # Attempt 1: 30 * 2^0 = 30
    local delay1=$((base_delay * (2 ** 0)))
    assert_equals "$delay1" "30" "Attempt 1 backoff: 30s"

    # Attempt 2: 30 * 2^1 = 60
    local delay2=$((base_delay * (2 ** 1)))
    assert_equals "$delay2" "60" "Attempt 2 backoff: 60s"

    # Attempt 3: 30 * 2^2 = 120
    local delay3=$((base_delay * (2 ** 2)))
    assert_equals "$delay3" "120" "Attempt 3 backoff: 120s"

    # Attempt 4: 30 * 2^3 = 240
    local delay4=$((base_delay * (2 ** 3)))
    assert_equals "$delay4" "240" "Attempt 4 backoff: 240s"

    # Test with different base delay
    base_delay=10
    delay1=$((base_delay * (2 ** 0)))
    delay2=$((base_delay * (2 ** 1)))
    delay3=$((base_delay * (2 ** 2)))
    assert_equals "$delay1" "10" "Custom base: Attempt 1 backoff: 10s"
    assert_equals "$delay2" "20" "Custom base: Attempt 2 backoff: 20s"
    assert_equals "$delay3" "40" "Custom base: Attempt 3 backoff: 40s"
}

# ==============================================================================
# Test: Argument Parsing - Invalid Arguments
# ==============================================================================

test_invalid_arguments() {
    echo ""
    echo "=== Test: Invalid Argument Handling ==="

    # Test unknown option
    local exit_code=0
    "$RETRY_SCRIPT" --unknown-option 2>/dev/null || exit_code=$?
    assert_equals "$exit_code" "2" "Unknown option returns exit code 2"

    # Test --max-retries without value
    exit_code=0
    "$RETRY_SCRIPT" --max-retries 2>/dev/null || exit_code=$?
    assert_equals "$exit_code" "2" "--max-retries without value returns exit code 2"

    # Test --max-retries with non-numeric value
    exit_code=0
    "$RETRY_SCRIPT" --max-retries abc 2>/dev/null || exit_code=$?
    assert_equals "$exit_code" "2" "--max-retries with non-numeric returns exit code 2"

    # Test --max-retries out of range (too high)
    exit_code=0
    "$RETRY_SCRIPT" --max-retries 100 2>/dev/null || exit_code=$?
    assert_equals "$exit_code" "2" "--max-retries > 10 returns exit code 2"

    # Test --retry-delay without value
    exit_code=0
    "$RETRY_SCRIPT" --retry-delay 2>/dev/null || exit_code=$?
    assert_equals "$exit_code" "2" "--retry-delay without value returns exit code 2"
}

# ==============================================================================
# Test: Required UNIX Tools Availability
# ==============================================================================

test_required_tools() {
    echo ""
    echo "=== Test: Required UNIX Tools Availability ==="

    local tools=("grep" "awk" "sed" "wc" "bash")

    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_info "PASS: $tool is available"
            ((TESTS_PASSED++)) || true
        else
            log_error "FAIL: $tool is not available"
            ((TESTS_FAILED++))
        fi
    done
}

# ==============================================================================
# Test: Bulk Resubmit Script Help
# ==============================================================================

test_bulk_resubmit_help() {
    echo ""
    echo "=== Test: Bulk Resubmit Script Help ==="

    local help_output
    help_output=$("$BULK_SCRIPT" 2>&1) || true

    assert_contains "$help_output" "Usage:" "Bulk script shows usage"
    assert_contains "$help_output" "--dry-run" "Bulk script mentions --dry-run"
}

# ==============================================================================
# Main Test Runner
# ==============================================================================

main() {
    echo "=============================================================================="
    echo "Unit Tests for Retry Scripts"
    echo "=============================================================================="
    echo ""
    echo "Project root: $PROJECT_ROOT"
    echo "Retry script: $RETRY_SCRIPT"
    echo ""

    # Verify scripts exist
    if [[ ! -f "$RETRY_SCRIPT" ]]; then
        log_error "Retry script not found: $RETRY_SCRIPT"
        exit 1
    fi

    if [[ ! -f "$BULK_SCRIPT" ]]; then
        log_error "Bulk resubmit script not found: $BULK_SCRIPT"
        exit 1
    fi

    # Run tests
    test_syntax_validation
    test_help_flag
    test_trait_index_extraction
    test_mount_failure_detection
    test_job_prefix_filtering
    test_active_state_counting
    test_exponential_backoff
    test_invalid_arguments
    test_required_tools
    test_bulk_resubmit_help

    # Summary
    echo ""
    echo "=============================================================================="
    echo "Test Summary"
    echo "=============================================================================="
    echo ""
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Some tests failed!"
        exit 1
    else
        log_info "All tests passed!"
        exit 0
    fi
}

main "$@"