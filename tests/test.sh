#!/usr/bin/env bash
# Rigorous test suite for shlog
# Usage: bash rigorous_test.sh [path_to_shlog.sh]
#        zsh rigorous_test.sh [path_to_shlog.sh]

# Set path to shlog. Default assumes it is in the parent directory.
SHLOG_SRC="$HOME/Projects/shlog/shlog.sh"

if [ ! -f "$SHLOG_SRC" ]; then
    printf "ERROR: Cannot find %s\n" "$SHLOG_SRC" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Test Environment Setup
# ---------------------------------------------------------------------------
export LOG_PATH="/tmp/shlog_test_$$.log"
export LOG_LEVEL_DEFAULT="INFO"
export LOG_LEVEL_STDOUT="TRACE"
export LOG_LEVEL_LOG="TRACE"

# Source the logging tool
. "$SHLOG_SRC"

debug "SCRIPT_NAME"
debug "SCRIPT_ARGS"
debug "SCRIPT_EXTENSION"

echo "============================================================"
echo " RUNNING SHLOG RIGOROUS TEST SUITE"
echo " Target: $SHLOG_SRC"
echo " Shell:  $SCRIPT_EXTENSION"
echo " Log:    $LOG_PATH"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Basic Log Levels
# ---------------------------------------------------------------------------
echo ">>> 1. Basic Log Levels"
log_trace "This is a TRACE message"
log_debug "This is a DEBUG message"
log_info "This is an INFO message"
log_success "This is a SUCCESS message"
log_warning "This is a WARNING message"
log_error "This is an ERROR message"
echo ""

# ---------------------------------------------------------------------------
# 2. Function Tracing and Stack Tracking
# ---------------------------------------------------------------------------
echo ">>> 2. Function Tracing"
test_inner_function() {
    log_trace_in "test_inner_function" "Starting inner process"
    log_trace "Processing data..."
    log_trace_out "test_inner_function" "Finished inner process"
}

test_outer_function() {
    SCRIPTENTRY "Initializing outer sequence"
    test_inner_function
    SCRIPTEXIT "Outer sequence complete"
}

test_outer_function
echo ""

# ---------------------------------------------------------------------------
# 3. Custom Labels and Color Overrides
# ---------------------------------------------------------------------------
echo ">>> 3. Custom Labels & Color Overrides"
log "CUSTOM" "This uses the default custom label mapping"
log "DB_SYNC" "This is an unregistered label (should fallback to INFO or CUSTOM)"
log -c 5 "PURPLE" "This forces color 5 (magenta/purple) for the entire line"
log -c 6 "CYAN" "This forces color 6 (cyan) for the entire line"
log -D 2 -L 3 -T 4 "RAINBOW" "Forces Date=Green(2), Label=Yellow(3), Text=Blue(4)"
echo ""

# ---------------------------------------------------------------------------
# 4. Standard Output (STDOUT) Thresholds
# ---------------------------------------------------------------------------
echo ">>> 4. STDOUT Thresholds (Setting to WARNING)"
LOG_LEVEL_STDOUT="WARNING"
log_info "FAIL: This INFO message SHOULD NOT appear on STDOUT"
log_success "FAIL: This SUCCESS message SHOULD NOT appear on STDOUT"
log_warning "PASS: This WARNING message SHOULD appear on STDOUT"
log_error "PASS: This ERROR message SHOULD appear on STDOUT"
echo ""

# Reset STDOUT threshold for the rest of the visual tests
LOG_LEVEL_STDOUT="TRACE"

# ---------------------------------------------------------------------------
# 5. File Logging Thresholds
# ---------------------------------------------------------------------------
echo ">>> 5. File Logging Thresholds (Setting to ERROR)"
LOG_LEVEL_LOG="ERROR"
log_warning "This WARNING SHOULD NOT appear in the log file"
log_error "This ERROR SHOULD appear in the log file"
LOG_LEVEL_LOG="TRACE" # Reset
echo ""

# ---------------------------------------------------------------------------
# 6. Formatting Presets
# ---------------------------------------------------------------------------
echo ">>> 6. Formatting Presets"
for style in default standard minimal invalid_style; do
    echo "--- Style: $style ---"
    LOG_FORMAT_PRESET="$style"
    log_info "Testing format output"
    log_trace "Testing format alignment"
done
echo ""

# ---------------------------------------------------------------------------
# 7. Verification of Log File Integrity
# ---------------------------------------------------------------------------
echo ">>> 7. Log File Output Verification"
echo "Reading back $LOG_PATH (ANSI codes should be stripped):"
echo "------------------------------------------------------------"
cat "$LOG_PATH"
echo "------------------------------------------------------------"

# Cleanup
rm -f "$LOG_PATH"
echo "Test suite completed. Log file cleaned up."
