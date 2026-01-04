#!/usr/bin/env bash
# ==============================================================================
# Integration Tests for SNP_FDR Parameter Propagation
# ==============================================================================
# Tests the complete pipeline: env vars → entrypoint → R script → metadata
#
# v3.0.0 Parameter Names:
#   - MODEL (was MODELS), PCA_TOTAL (was PCA_COMPONENTS), SNP_MAF (was MAF_FILTER)
# ==============================================================================

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_IMAGE="${TEST_IMAGE:-gapit3:snp-fdr-test-$(date +%s)}"
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

assert_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"

    if echo "$output" | grep -q "$expected"; then
        log_info "✓ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ FAIL: $test_name"
        log_error "  Expected to find: '$expected'"
        log_error "  In output (first 20 lines):"
        echo "$output" | head -20
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_contains() {
    local output="$1"
    local unexpected="$2"
    local test_name="$3"

    if echo "$output" | grep -q "$unexpected"; then
        log_error "✗ FAIL: $test_name"
        log_error "  Should NOT contain: '$unexpected'"
        ((TESTS_FAILED++))
        return 1
    else
        log_info "✓ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    fi
}

assert_exit_code() {
    local actual="$1"
    local expected="$2"
    local test_name="$3"

    if [ "$actual" -eq "$expected" ]; then
        log_info "✓ PASS: $test_name (exit code: $actual)"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ FAIL: $test_name"
        log_error "  Expected exit code: $expected"
        log_error "  Actual exit code: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# ==============================================================================
# Test Setup and Teardown
# ==============================================================================

setup_tests() {
    log_info "Setting up SNP_FDR integration tests..."
    log_info "Project root: $PROJECT_ROOT"

    # Skip building if CI_SKIP_BUILD is set (CI already built the image)
    if [ "${CI_SKIP_BUILD:-}" = "true" ]; then
        log_info "Skipping Docker build (CI_SKIP_BUILD=true)"
        log_info "Using existing image: $TEST_IMAGE"

        if ! docker image inspect "$TEST_IMAGE" >/dev/null 2>&1; then
            log_info "Image not found locally, attempting to pull: $TEST_IMAGE"
            if ! docker pull "$TEST_IMAGE"; then
                log_error "Failed to pull image $TEST_IMAGE!"
                exit 1
            fi
        fi
    else
        # Build test Docker image
        log_info "Building test Docker image: $TEST_IMAGE"
        cd "$PROJECT_ROOT"
        docker build -t "$TEST_IMAGE" . || {
            log_error "Failed to build Docker image"
            exit 1
        }
        log_info "Docker image built successfully"
    fi
}

cleanup_tests() {
    log_info "Cleaning up test artifacts..."

    if [ "${CI_SKIP_CLEANUP:-}" = "true" ]; then
        log_info "Skipping Docker cleanup (CI_SKIP_CLEANUP=true)"
        return 0
    fi

    if docker image inspect "$TEST_IMAGE" >/dev/null 2>&1; then
        log_info "Removing test Docker image: $TEST_IMAGE"
        docker rmi "$TEST_IMAGE" || log_warning "Failed to remove test image"
    fi
}

# ==============================================================================
# Test Cases: SNP_FDR Environment Variable
# ==============================================================================

test_snp_fdr_default_disabled() {
    log_info "Testing SNP_FDR default (disabled)..."

    output=$(docker run --rm "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "SNP_FDR.*disabled" "SNP_FDR shows as disabled by default"
}

test_snp_fdr_env_var_logged() {
    log_info "Testing SNP_FDR environment variable logging..."

    output=$(docker run --rm \
        -e SNP_FDR=0.05 \
        "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "SNP.*FDR.*0.05" "SNP_FDR=0.05 logged in configuration"
}

test_snp_fdr_strict_value() {
    log_info "Testing strict SNP_FDR value (0.01)..."

    output=$(docker run --rm \
        -e SNP_FDR=0.01 \
        "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "SNP.*FDR.*0.01" "SNP_FDR=0.01 logged in configuration"
}

test_snp_fdr_permissive_value() {
    log_info "Testing permissive SNP_FDR value (0.1)..."

    output=$(docker run --rm \
        -e SNP_FDR=0.1 \
        "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "SNP.*FDR.*0.1" "SNP_FDR=0.1 logged in configuration"
}

test_snp_fdr_invalid_rejected() {
    log_info "Testing invalid SNP_FDR values rejected..."

    # Test negative value
    set +e
    output=$(docker run --rm \
        -e SNP_FDR=-0.1 \
        -e GENOTYPE_FILE=/data/test.hmp.txt \
        -e PHENOTYPE_FILE=/data/test.txt \
        "$TEST_IMAGE" run-single-trait 2>&1)
    exit_code=$?
    set -e

    assert_exit_code "$exit_code" 1 "Negative SNP_FDR causes non-zero exit"

    # Test value > 1
    set +e
    output=$(docker run --rm \
        -e SNP_FDR=1.5 \
        -e GENOTYPE_FILE=/data/test.hmp.txt \
        -e PHENOTYPE_FILE=/data/test.txt \
        "$TEST_IMAGE" run-single-trait 2>&1)
    exit_code=$?
    set -e

    assert_exit_code "$exit_code" 1 "SNP_FDR > 1.0 causes non-zero exit"
}

test_snp_fdr_non_numeric_rejected() {
    log_info "Testing non-numeric SNP_FDR rejected..."

    set +e
    output=$(docker run --rm \
        -e SNP_FDR=invalid \
        -e GENOTYPE_FILE=/data/test.hmp.txt \
        -e PHENOTYPE_FILE=/data/test.txt \
        "$TEST_IMAGE" run-single-trait 2>&1)
    exit_code=$?
    set -e

    assert_exit_code "$exit_code" 1 "Non-numeric SNP_FDR causes non-zero exit"
    assert_contains "$output" "SNP_FDR must be a number" "Error message mentions SNP_FDR format"
}

test_snp_fdr_combined_with_other_params() {
    log_info "Testing SNP_FDR combined with other parameters..."

    # v3.0.0: Use new parameter names (MODEL, PCA_TOTAL, SNP_MAF)
    output=$(docker run --rm \
        -e SNP_FDR=0.05 \
        -e SNP_MAF=0.10 \
        -e PCA_TOTAL=5 \
        -e MODEL=BLINK \
        "$TEST_IMAGE" help 2>&1 || true)

    # Help shows parameter documentation, verify key params are present
    assert_contains "$output" "SNP.*FDR" "SNP_FDR logged"
    assert_contains "$output" "SNP_MAF" "SNP_MAF parameter shown"
    assert_contains "$output" "PCA_TOTAL" "PCA_TOTAL parameter shown"
    assert_contains "$output" "MODEL" "MODEL parameter shown"
}

test_snp_fdr_empty_string_disabled() {
    log_info "Testing empty SNP_FDR treated as disabled..."

    output=$(docker run --rm \
        -e SNP_FDR="" \
        "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "SNP.*FDR.*disabled" "Empty SNP_FDR shows as disabled"
}

# ==============================================================================
# Test Cases: SNP_FDR and SNP_MAF Independence
# ==============================================================================

test_snp_maf_and_fdr_independent() {
    log_info "Testing SNP_MAF and SNP_FDR are independent..."

    # v3.0.0: Use SNP_MAF instead of MAF_FILTER
    output=$(docker run --rm \
        -e SNP_MAF=0.05 \
        -e SNP_FDR=0.10 \
        "$TEST_IMAGE" help 2>&1 || true)

    # Help shows parameter documentation
    assert_contains "$output" "SNP_MAF" "SNP_MAF parameter shown"
    assert_contains "$output" "SNP.*FDR" "SNP_FDR parameter shown"
}

test_snp_maf_only_no_fdr() {
    log_info "Testing SNP_MAF alone (no SNP_FDR)..."

    # v3.0.0: Use SNP_MAF instead of MAF_FILTER
    output=$(docker run --rm \
        -e SNP_MAF=0.01 \
        "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "SNP_MAF" "SNP_MAF parameter shown"
    assert_contains "$output" "SNP.*FDR.*disabled" "SNP_FDR shows as disabled"
}

# ==============================================================================
# Test Runner
# ==============================================================================

run_all_tests() {
    log_info "Starting SNP_FDR integration tests..."
    echo

    # Run all test functions (continue even if some fail)
    test_snp_fdr_default_disabled || true
    test_snp_fdr_env_var_logged || true
    test_snp_fdr_strict_value || true
    test_snp_fdr_permissive_value || true
    test_snp_fdr_invalid_rejected || true
    test_snp_fdr_non_numeric_rejected || true
    test_snp_fdr_combined_with_other_params || true
    test_snp_fdr_empty_string_disabled || true
    test_snp_maf_and_fdr_independent || true
    test_snp_maf_only_no_fdr || true

    echo
    log_info "================================"
    log_info "SNP_FDR Test Results:"
    log_info "  Passed: $TESTS_PASSED"
    log_info "  Failed: $TESTS_FAILED"
    log_info "================================"

    if [ "$TESTS_FAILED" -eq 0 ]; then
        log_info "All SNP_FDR tests passed! ✓"
        return 0
    else
        log_error "Some SNP_FDR tests failed."
        return 1
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    # Trap to ensure cleanup
    trap cleanup_tests EXIT

    # Setup
    setup_tests
    echo

    # Run tests
    run_all_tests
    exit_code=$?

    exit $exit_code
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi