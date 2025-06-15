#!/bin/sh

. ../includes/shlog.sh

# Set test config file path
LOG_CONFIG_FILE="./test_shlog.conf"
LOG_PATH="./shlog.log"

# Set initial variables
LOG_LEVEL_DEFAULT="DEBUG"
LOG_LEVEL_STDOUT="INFO"
LOG_LEVEL_LOG="ERROR"
LOG_USE_CUSTOM_LABELS="on"
LOG_PRESET_FORMAT="simple"

# Save config to file
SAVE_CONFIG

# Reset variables to empty to test loading
unset LOG_LEVEL_DEFAULT
unset LOG_LEVEL_STDOUT
unset LOG_LEVEL_LOG
unset LOG_USE_CUSTOM_LABELS
unset LOG_PRESET_FORMAT

# Load config from file
LOAD_CONFIG "$LOG_CONFIG_FILE"

# Display loaded variables
printf "%s\n" "LOG_LEVEL_DEFAULT=$LOG_LEVEL_DEFAULT"
printf "%s\n" "LOG_LEVEL_STDOUT=$LOG_LEVEL_STDOUT"
printf "%s\n" "LOG_LEVEL_LOG=$LOG_LEVEL_LOG"
printf "%s\n" "LOG_USE_CUSTOM_LABELS=$LOG_USE_CUSTOM_LABELS"
printf "%s\n" "LOG_PRESET_FORMAT=$LOG_PRESET_FORMAT"
printf "%s\n" "LOG_PATH=$LOG_PATH"
