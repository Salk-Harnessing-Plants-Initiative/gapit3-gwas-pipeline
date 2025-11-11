#!/usr/bin/env bash
# ==============================================================================
# Integration Tests for Environment Variable Configuration
# ==============================================================================
# Tests the complete pipeline: env vars → entrypoint → R script
# ==============================================================================

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_IMAGE="${TEST_IMAGE:-gapit3:test-$(date +%s)}"
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
        log_error "  In output:"
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
        log_error "  But found in output:"
        echo "$output" | grep "$unexpected" || true
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
    log_info "Setting up integration tests..."
    log_info "Project root: $PROJECT_ROOT"

    # Skip building if CI_SKIP_BUILD is set (CI already built the image)
    if [ "${CI_SKIP_BUILD:-}" = "true" ]; then
        log_info "Skipping Docker build (CI_SKIP_BUILD=true)"
        log_info "Using existing image: $TEST_IMAGE"

        # Verify image exists
        if ! docker image inspect "$TEST_IMAGE" >/dev/null 2>&1; then
            log_error "Image $TEST_IMAGE not found!"
            exit 1
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

    # Skip cleanup if CI_SKIP_CLEANUP is set (CI will handle cleanup)
    if [ "${CI_SKIP_CLEANUP:-}" = "true" ]; then
        log_info "Skipping Docker cleanup (CI_SKIP_CLEANUP=true)"
        return 0
    fi

    # Remove test Docker image
    if docker image inspect "$TEST_IMAGE" >/dev/null 2>&1; then
        log_info "Removing test Docker image: $TEST_IMAGE"
        docker rmi "$TEST_IMAGE" || log_warning "Failed to remove test image"
    fi
}

# ==============================================================================
# Test Cases
# ==============================================================================

test_help_command() {
    log_info "Testing help command..."

    output=$(docker run --rm "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "Usage:" "Help command shows usage"
    assert_contains "$output" "Available commands:" "Help shows available commands"
    assert_contains "$output" "run-single-trait" "Help lists run-single-trait command"
}

test_default_env_vars() {
    log_info "Testing default environment variables..."

    # Run help command which logs configuration
    output=$(docker run --rm "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "BLINK" "Default models include BLINK"
    assert_contains "$output" "FarmCPU" "Default models include FarmCPU"
}

test_custom_env_vars_logged() {
    log_info "Testing custom environment variables are logged..."

    output=$(docker run --rm \
        -e TRAIT_INDEX=5 \
        -e MODELS=BLINK \
        -e PCA_COMPONENTS=10 \
        "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "TRAIT_INDEX.*5" "Custom TRAIT_INDEX logged"
    assert_contains "$output" "MODELS.*BLINK" "Custom MODELS logged"
    assert_contains "$output" "PCA_COMPONENTS.*10" "Custom PCA_COMPONENTS logged"
}

test_invalid_model_validation() {
    log_info "Testing invalid model validation..."

    output=$(docker run --rm \
        -e MODELS=INVALID_MODEL \
        -e GENOTYPE_FILE=/data/genotype/test.hmp.txt \
        -e PHENOTYPE_FILE=/data/phenotype/test.txt \
        "$TEST_IMAGE" run-single-trait 2>&1 || true)
    exit_code=$?

    # Should fail validation
    assert_exit_code "$exit_code" 1 "Invalid model causes non-zero exit"
    assert_contains "$output" "Invalid model" "Error message mentions invalid model"

    # Should NOT reach R script
    assert_not_contains "$output" "Loading GAPIT" "Should not reach R script"
}

test_invalid_pca_validation() {
    log_info "Testing invalid PCA_COMPONENTS validation..."

    output=$(docker run --rm \
        -e PCA_COMPONENTS=100 \
        -e GENOTYPE_FILE=/data/genotype/test.hmp.txt \
        -e PHENOTYPE_FILE=/data/phenotype/test.txt \
        "$TEST_IMAGE" run-single-trait 2>&1 || true)
    exit_code=$?

    # Should fail validation
    assert_exit_code "$exit_code" 1 "Invalid PCA causes non-zero exit"
    assert_contains "$output" "between 0 and 20" "Error shows valid PCA range"

    # Should NOT reach R script
    assert_not_contains "$output" "Loading GAPIT" "Should not reach R script"
}

test_invalid_threshold_validation() {
    log_info "Testing invalid SNP_THRESHOLD validation..."

    output=$(docker run --rm \
        -e SNP_THRESHOLD=invalid \
        -e GENOTYPE_FILE=/data/genotype/test.hmp.txt \
        -e PHENOTYPE_FILE=/data/phenotype/test.txt \
        "$TEST_IMAGE" run-single-trait 2>&1 || true)
    exit_code=$?

    # Should fail validation
    assert_exit_code "$exit_code" 1 "Invalid threshold causes non-zero exit"
    assert_contains "$output" "Invalid.*threshold\|numeric" "Error mentions threshold format"
}

test_missing_required_files() {
    log_info "Testing missing required files validation..."

    output=$(docker run --rm \
        -e GENOTYPE_FILE=/nonexistent/file.hmp.txt \
        -e PHENOTYPE_FILE=/nonexistent/file.txt \
        "$TEST_IMAGE" run-single-trait 2>&1 || true)
    exit_code=$?

    # Should fail validation
    assert_exit_code "$exit_code" 1 "Missing files cause non-zero exit"
    assert_contains "$output" "not found\|does not exist\|Missing" "Error mentions missing files"
}

test_multiple_env_vars_together() {
    log_info "Testing multiple environment variables together..."

    output=$(docker run --rm \
        -e TRAIT_INDEX=3 \
        -e MODELS=BLINK,FarmCPU \
        -e PCA_COMPONENTS=5 \
        -e SNP_THRESHOLD=1e-6 \
        -e MAF_FILTER=0.01 \
        -e MULTIPLE_ANALYSIS=TRUE \
        "$TEST_IMAGE" help 2>&1 || true)

    assert_contains "$output" "TRAIT_INDEX.*3" "TRAIT_INDEX=3 logged"
    assert_contains "$output" "MODELS.*BLINK.*FarmCPU" "Multiple models logged"
    assert_contains "$output" "PCA_COMPONENTS.*5" "PCA_COMPONENTS=5 logged"
    assert_contains "$output" "SNP_THRESHOLD.*1e-6" "SNP_THRESHOLD logged"
    assert_contains "$output" "MAF_FILTER.*0.01" "MAF_FILTER logged"
    assert_contains "$output" "MULTIPLE_ANALYSIS.*TRUE" "MULTIPLE_ANALYSIS logged"
}

test_validation_order() {
    log_info "Testing validation runs before R script..."

    # Invalid model should fail in entrypoint, not R script
    output=$(docker run --rm \
        -e MODELS=INVALID \
        -e GENOTYPE_FILE=/data/test.hmp.txt \
        -e PHENOTYPE_FILE=/data/test.txt \
        "$TEST_IMAGE" run-single-trait 2>&1 || true)

    # Should fail fast
    assert_contains "$output" "Invalid model" "Validation error shown"
    assert_not_contains "$output" "Loading GAPIT" "R script not executed"
    assert_not_contains "$output" "library(GAPIT)" "GAPIT not loaded"
}

test_command_routing() {
    log_info "Testing command routing..."

    # Test help command
    output=$(docker run --rm "$TEST_IMAGE" help 2>&1 || true)
    assert_contains "$output" "Usage:" "Help command works"

    # Test invalid command
    output=$(docker run --rm "$TEST_IMAGE" invalid-command 2>&1 || true)
    exit_code=$?
    assert_exit_code "$exit_code" 1 "Invalid command returns non-zero"
    assert_contains "$output" "Unknown command\|not recognized" "Error for invalid command"
}

# ==============================================================================
# Test Runner
# ==============================================================================

run_all_tests() {
    log_info "Starting integration tests..."
    echo

    # Run all test functions (continue even if some fail)
    test_help_command || true
    test_default_env_vars || true
    test_custom_env_vars_logged || true
    test_invalid_model_validation || true
    test_invalid_pca_validation || true
    test_invalid_threshold_validation || true
    test_missing_required_files || true
    test_multiple_env_vars_together || true
    test_validation_order || true
    test_command_routing || true

    echo
    log_info "================================"
    log_info "Test Results:"
    log_info "  Passed: $TESTS_PASSED"
    log_info "  Failed: $TESTS_FAILED"
    log_info "================================"

    if [ "$TESTS_FAILED" -eq 0 ]; then
        log_info "All tests passed! ✓"
        return 0
    else
        log_error "Some tests failed."
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
