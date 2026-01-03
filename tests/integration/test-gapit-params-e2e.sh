#!/bin/bash
# =============================================================================
# Integration tests for GAPIT parameter handling
# =============================================================================
# Tests:
# 1. New parameter names are accepted (MODEL, PCA_TOTAL, SNP_MAF)
# 2. Deprecated names trigger warnings but still work
# 3. New parameters are validated correctly
# 4. Invalid values are rejected with clear errors
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Configuration
TEST_IMAGE="${TEST_IMAGE:-gapit3-gwas:test}"
CI_SKIP_BUILD="${CI_SKIP_BUILD:-false}"
CI_SKIP_CLEANUP="${CI_SKIP_CLEANUP:-false}"

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

# =============================================================================
# Test: New parameter names are accepted
# =============================================================================

test_new_param_model() {
    log_test "MODEL env var is accepted"
    ((TESTS_RUN++))

    output=$(docker run --rm \
        -e MODEL="BLINK,FarmCPU" \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    # Should not show error about MODEL
    if echo "$output" | grep -qi "invalid.*model\|error.*model"; then
        log_fail "MODEL was rejected"
        echo "$output"
        return 1
    fi
    log_pass "MODEL env var accepted"
}

test_new_param_pca_total() {
    log_test "PCA_TOTAL env var is accepted"
    ((TESTS_RUN++))

    output=$(docker run --rm \
        -e PCA_TOTAL=5 \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    if echo "$output" | grep -qi "invalid.*pca_total\|error.*pca_total"; then
        log_fail "PCA_TOTAL was rejected"
        echo "$output"
        return 1
    fi
    log_pass "PCA_TOTAL env var accepted"
}

test_new_param_snp_maf() {
    log_test "SNP_MAF env var is accepted"
    ((TESTS_RUN++))

    output=$(docker run --rm \
        -e SNP_MAF=0.05 \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    if echo "$output" | grep -qi "invalid.*snp_maf\|error.*snp_maf"; then
        log_fail "SNP_MAF was rejected"
        echo "$output"
        return 1
    fi
    log_pass "SNP_MAF env var accepted"
}

# =============================================================================
# Test: Deprecated names trigger warnings
# =============================================================================

test_deprecated_models_warning() {
    log_test "MODELS triggers deprecation warning"
    ((TESTS_RUN++))

    output=$(docker run --rm \
        -e MODELS="BLINK" \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    if ! echo "$output" | grep -qi "deprecat.*models\|models.*deprecat"; then
        log_fail "No deprecation warning for MODELS"
        echo "$output"
        return 1
    fi
    log_pass "MODELS shows deprecation warning"
}

test_deprecated_pca_components_warning() {
    log_test "PCA_COMPONENTS triggers deprecation warning"
    ((TESTS_RUN++))

    output=$(docker run --rm \
        -e PCA_COMPONENTS=3 \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    if ! echo "$output" | grep -qi "deprecat.*pca_components\|pca_components.*deprecat"; then
        log_fail "No deprecation warning for PCA_COMPONENTS"
        echo "$output"
        return 1
    fi
    log_pass "PCA_COMPONENTS shows deprecation warning"
}

test_deprecated_maf_filter_warning() {
    log_test "MAF_FILTER triggers deprecation warning"
    ((TESTS_RUN++))

    output=$(docker run --rm \
        -e MAF_FILTER=0.05 \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    if ! echo "$output" | grep -qi "deprecat.*maf_filter\|maf_filter.*deprecat"; then
        log_fail "No deprecation warning for MAF_FILTER"
        echo "$output"
        return 1
    fi
    log_pass "MAF_FILTER shows deprecation warning"
}

test_new_name_takes_precedence() {
    log_test "New name takes precedence over deprecated"
    ((TESTS_RUN++))

    # Set both MODEL and MODELS - MODEL should win
    output=$(docker run --rm \
        -e MODEL="BLINK" \
        -e MODELS="FarmCPU" \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    # Should NOT show deprecation warning when new name is set
    if echo "$output" | grep -qi "deprecat.*models"; then
        log_fail "Deprecation warning shown when new name is set"
        echo "$output"
        return 1
    fi
    log_pass "New name takes precedence"
}

# =============================================================================
# Test: New GAPIT parameters (Tier 2)
# =============================================================================

test_kinship_algorithm_valid() {
    log_test "KINSHIP_ALGORITHM accepts valid values"
    ((TESTS_RUN++))

    for algo in VanRaden Zhang Loiselle EMMA; do
        output=$(docker run --rm \
            -e KINSHIP_ALGORITHM="$algo" \
            -e TRAIT_INDEX=2 \
            "$TEST_IMAGE" help 2>&1) || true

        if echo "$output" | grep -qi "invalid.*kinship\|error.*kinship"; then
            log_fail "KINSHIP_ALGORITHM=$algo was rejected"
            return 1
        fi
    done
    log_pass "KINSHIP_ALGORITHM accepts valid values"
}

test_kinship_algorithm_invalid() {
    log_test "KINSHIP_ALGORITHM rejects invalid values"
    ((TESTS_RUN++))

    output=$(docker run --rm \
        -e KINSHIP_ALGORITHM="Invalid" \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    if ! echo "$output" | grep -qi "invalid\|error"; then
        log_fail "Invalid KINSHIP_ALGORITHM was not rejected"
        echo "$output"
        return 1
    fi
    log_pass "KINSHIP_ALGORITHM rejects invalid values"
}

test_snp_effect_valid() {
    log_test "SNP_EFFECT accepts valid values"
    ((TESTS_RUN++))

    for effect in Add Dom; do
        output=$(docker run --rm \
            -e SNP_EFFECT="$effect" \
            -e TRAIT_INDEX=2 \
            "$TEST_IMAGE" help 2>&1) || true

        if echo "$output" | grep -qi "invalid.*snp_effect\|error.*snp_effect"; then
            log_fail "SNP_EFFECT=$effect was rejected"
            return 1
        fi
    done
    log_pass "SNP_EFFECT accepts valid values"
}

test_snp_impute_valid() {
    log_test "SNP_IMPUTE accepts valid values"
    ((TESTS_RUN++))

    for impute in Middle Major Minor; do
        output=$(docker run --rm \
            -e SNP_IMPUTE="$impute" \
            -e TRAIT_INDEX=2 \
            "$TEST_IMAGE" help 2>&1) || true

        if echo "$output" | grep -qi "invalid.*snp_impute\|error.*snp_impute"; then
            log_fail "SNP_IMPUTE=$impute was rejected"
            return 1
        fi
    done
    log_pass "SNP_IMPUTE accepts valid values"
}

# =============================================================================
# Test: Runtime configuration display
# =============================================================================

test_log_config_shows_gapit_params() {
    log_test "log_config shows GAPIT parameters"
    ((TESTS_RUN++))

    output=$(docker run --rm \
        -e MODEL="BLINK,FarmCPU" \
        -e PCA_TOTAL=5 \
        -e SNP_MAF=0.05 \
        -e KINSHIP_ALGORITHM="VanRaden" \
        -e TRAIT_INDEX=2 \
        "$TEST_IMAGE" help 2>&1) || true

    # Should show new parameter names in config display
    if ! echo "$output" | grep -qi "model.*blink\|blink.*model"; then
        log_fail "Config display missing model"
        return 1
    fi
    log_pass "log_config shows GAPIT parameters"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo "=============================================================================="
    echo "GAPIT Parameters Integration Tests"
    echo "=============================================================================="
    echo "Test image: $TEST_IMAGE"
    echo ""

    # Run new parameter name tests
    test_new_param_model || true
    test_new_param_pca_total || true
    test_new_param_snp_maf || true

    # Run deprecation warning tests
    test_deprecated_models_warning || true
    test_deprecated_pca_components_warning || true
    test_deprecated_maf_filter_warning || true
    test_new_name_takes_precedence || true

    # Run new GAPIT parameter tests
    test_kinship_algorithm_valid || true
    test_kinship_algorithm_invalid || true
    test_snp_effect_valid || true
    test_snp_impute_valid || true

    # Run config display test
    test_log_config_shows_gapit_params || true

    # Summary
    echo ""
    echo "=============================================================================="
    echo "Test Summary"
    echo "=============================================================================="
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo ""
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
}

main "$@"
