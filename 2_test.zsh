#!/bin/zsh

# Optional: Define LOG_PATH to capture logs
# Optional: Define LOG_LEVEL_STDOUT to  
# LOG_PATH="./my.log"
LOG_LEVEL_MODE="DEBUG"
source ./includes/zlog.sh

for style in "standard" "enhanced" "classic"; do
	LOG_FORMAT_PRESET=$style
	printf			"-----------------------Style: %s-----------------------\n" "$style"
	trace_in		"Here we enter"
	log info		"This is warning";
	log success "This is success"
	log warning "This is warning"
	log error		"This is error"
	log debug		"This is debug"
	trace_out		"Here we exit"
done
printf "%s\n"		"-------------------------------------------------------" 

LOG_LEVEL_DEBUG="INFO"
LOG_LEVEL_LOG="INFO"

sleep 2
log_success "We successfully passed the first test!"

log_info "Begin second test with log set to debug mode"

# Set log level thresholds for testing
LOG_LEVEL_STDOUT="DEBUG"
LOG_LEVEL_LOG="DEBUG"

function dig_pirate_gold() {
  trace_in   # We add "trace_in" in top of every function

  log_info    "Digging for pirate gold..."
  log_debug   "Searching on island: Hisingen"
  
  sleep 2

  log_warning "This is taking a longer time than expected..."
  log_success "We successfully got some pirate gold!"

  trace_out  # We add "trace_out" in end of every function
}

function get_hostname() {
  trace_in   # We add "trace_in" in top of every function

  log_info    "Getting hosting..."
  log_info    "Hostname is: $(hostname)"

  trace_out   # We add "trace_out" in end of every function
}

#############################################################
# Main script
#############################################################
log_info      "Starting program"
dig_pirate_gold
get_hostname
log_error      "I'm done but I'm going to show an error instead"

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

# Script exit (run as late as possible in the script)
SCRIPTEXIT

