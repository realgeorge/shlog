#!/bin/zsh

# Optional: Define LOG_PATH to capture logs
# Optional: Define LOG_LEVEL_STDOUT to  
# LOG_PATH="./my.log"
source ./includes/zlog.sh

local usage=(
)

log "bar" ; return 1

function foo() {
	trace_in
	log info		"This is info";
	log success "This is success"
	log wtf "Did it work?"
	trace_out
}

foo

for style in "standard" "enhanced" "classic"; do
	LOG_FORMAT_PRESET=$style
	printf "------------------Style: %s------------------\n" "$style"
	log_info "this is a test"
done
log_info "Begin first test with log set to info mode "

# This should not output anything. 
SCRIPTENTRY "This should not output anything" 
trace_in		"This should not output anything"
trace_out		"This should not output anything"
SCRIPTEXIT	"This should not output anything"

sleep 2
log_success "We successfully passed the first test!"

log_info "Begin second test with log set to debug mode"

# Set log level thresholds for testing
LOG_LEVEL_STDOUT="DEBUG"
LOG_LEVEL_LOG="DEBUG"

# Script_entry (run as early as possible after defining
SCRIPTENTRY
sleep 1; return 1
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

