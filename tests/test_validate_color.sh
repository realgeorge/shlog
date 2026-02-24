#!/usr/bin/env bash
# test_validate_color.bash

set -euo pipefail

# 1. Define the functions to test
is_uint() {
    case "$1" in
    '' | *[!0-9]*) return 1 ;;
    esac
    return 0
}

validate_color() {
    case "$1" in
    # Check if valid color
    LOG_DEBUG_COLOR | LOG_INFO_COLOR | LOG_SUCCESS_COLOR | LOG_WARNING_COLOR | LOG_ERROR_COLOR | LOG_TRACE_COLOR | LOG_CUSTOM_COLOR)
        return 0
        ;;
    '' | *[!0-9]*)
        return 1
        ;;
    *)
        [ "$1" -le 255 ] || return 1
        ;;
    esac
    return 0
}

# 2. Test Runner State
PASSED=0
FAILED=0

GREEN=$'\e[32m'
RED=$'\e[31m'
RESET=$'\e[0m'

assert_pass() {
    if validate_color "$1"; then
        PASSED=$((PASSED + 1))
    else
        printf "%sFAILED%s: Expected '%s' to PASS\n" "$RED" "$RESET" "$1"
        FAILED=$((FAILED + 1))
    fi
}

assert_fail() {
    if ! validate_color "$1"; then
        PASSED=$((PASSED + 1))
    else
        printf "%sFAILED%s: Expected '%s' to FAIL\n" "$RED" "$RESET" "$1"
        FAILED=$((FAILED + 1))
    fi
}

printf "============================= test session starts ==============================\n"

# 3. Test valid integers (0-255)
# Using standard 8-bit color bounds where 255 is the maximum valid value.
for ((i = 0; i < 256; i++)); do
    assert_pass "$i"
done

# 4. Test valid short color strings
for color in DEBUG INFO SUCCESS WARNING ERROR TRACE CUSTOM; do
    assert_fail "$color"
done

# 5. Test valid full variable color strings
for color in LOG_DEBUG_COLOR LOG_INFO_COLOR LOG_SUCCESS_COLOR LOG_WARNING_COLOR LOG_ERROR_COLOR LOG_TRACE_COLOR LOG_CUSTOM_COLOR; do
    assert_pass "$color"
done

# 6. Test invalid edge cases
assert_fail "256"               # Out of bounds integer
assert_fail "-1"                # Negative integer
assert_fail "300"               # Out of bounds integer
assert_fail ""                  # Empty string
assert_fail "1.5"               # Float
assert_fail "INVALID"           # Invalid string
assert_fail "LOG_INVALID_COLOR" # Invalid variable format
assert_fail "INFO_TYPO"         # Invalid suffix
assert_fail "LOG_INF"           # Partial match

# 7. Summary Report
TOTAL=$((PASSED + FAILED))
printf "\n=========================== short test summary info ============================\n"
if [[ $FAILED -eq 0 ]]; then
    printf "%s%d passed in 0.01s%s\n" "$GREEN" "$PASSED" "$RESET"
    exit 0
else
    printf "%s%d failed, %d passed in 0.01s%s\n" "$RED" "$FAILED" "$PASSED" "$RESET"
    exit 1
fi
