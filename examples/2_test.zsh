#!/bin/zsh

# Optional: define LOG_PATH to capture logs
LOG_PATH="./my.log"
. ./includes/zlog.sh

# Set log level thresholds for testing
LOG_LEVEL_STDOUT="DEBUG"
LOG_LEVEL_LOG="DEBUG"

echo "Starting slog zsh test..."

# Test info log
log_info "This is an INFO message."

# Test success log
log_success "This is a SUCCESS message."

# Test warning log
log_warning "This is a WARNING message."

# Test error log
log_error "This is an ERROR message."

# Test debug log
log_debug "This is a DEBUG message."

# Test trace entry and exit logs
trace_begin "Entering function test_func"
trace_end "Exiting function test_func"

# Test SCRIPTENTRY and SCRIPTEXIT (zsh specific)
SCRIPTENTRY "Script entry point"
SCRIPTEXIT "Script exit point"

# Test log level filtering by changing levels
echo "Changing LOG_LEVEL_STDOUT to WARNING"
LOG_LEVEL_STDOUT="WARNING"

log_info "This INFO message should NOT appear on STDOUT."
log_warning "This WARNING message SHOULD appear on STDOUT."
log_error "This ERROR message SHOULD appear on STDOUT."

# Show test.log content if LOG_PATH is set
if [ -f "$LOG_PATH" ]; then
  echo ""
  echo "Contents of $LOG_PATH:"
  cat "$LOG_PATH"
fi

echo "slog zsh test complete."

