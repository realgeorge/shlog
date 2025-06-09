#!/bin/sh
# -------------------------------------------------------------------
# slog - Makes logging in POSIX shell scripting suck less
# Copyright (c) Fred Palmer
# POSIX version Copyright Joe Cooper
# Licensed under the MIT license
# http://github.com/swelljoe/slog
# -------------------------------------------------------------------

set -e

# LOG_PATH - Define $LOG_PATH in your script to log a file, otherwise 
# just write to STDOUT

# LOG_LEVEL_STDOUT - Define the lowest level which goes to STDOUT
# By default, all logs will be written to STDOUT
LOG_LEVEL_STDOUT="INFO"

# LOG_LEVEL_LOG - Define to determine which level goes to LOG_PATH 
# By default all log levels will be written to LOG_PATH
LOG_LEVEL_LOG="INFO"

# Useful global variables that users wish to reference
SCRIPT_ARGS="$@"
SCRIPT_NAME="$0"
SCRIPT_NAME="${SCRIPT_NAME#\./}"
SCRIPT_NAME="${SCRIPT_NAME##/*/}"

# This or passed as argument
# SCRIPT_EXTENSION=
SCRIPT_EXTENSION=$(ps -p "$$" -o comm=)
SCRIPT_EXTENSION="${SCRIPT_EXTENSION##*.}"

# Determines if we print color or not
if [ $(tty -s) ]; then
	readonly INTERACTIVE_MODE="off"
else
	readonly INTERACTIVE_MODE="on"
fi

# -------------------------------------------------------------------
# Begin logging section
if [ "${INTERACTIVE_MODE}" = "off" ]
then
	# We don't care about log colors
	LOG_DEFAULT_COLOR=""
	LOG_ERROR_COLOR=""
	LOG_INFO_COLOR=""
	LOG_SUCCESS_COLOR=""
	LOG_WARNING_COLOR=""
	LOG_DEBUG_COLOR=""
else
	LOG_DEFAULT_COLOR="$(tput sgr 0)"
	LOG_INFO_COLOR="$(tput sgr 0)"
	LOG_ERROR_COLOR="$(tput setaf 1)"
	LOG_SUCCESS_COLOR="$(tput setaf 2)"
	LOG_WARNING_COLOR="$(tput setaf 3)"
	LOG_DEBUG_COLOR="$(tput setaf 4)"
fi

# Formatting
strip_ansi() {
	sed 's/\x1b\[[0-9;]*m//g'
}

log() {
	local log_text="$1"
	local log_level="$2"
	local log_color="$3"

	local clean_level=$(echo "$log_level" | tr -d '[]' | xargs)

	# Levels for comparing against LOG_LEVEL_STDOUT and LOG_LEVEL_LOG
	local LOG_LEVEL_DEBUG=0
	local LOG_LEVEL_TRACE_ENTRY=1 
	local LOG_LEVEL_TRACE_EXIT=2

	local LOG_LEVEL_INFO=3
	local LOG_LEVEL_SUCCESS=4
	local LOG_LEVEL_WARNING=5
	local LOG_LEVEL_ERROR=6

	# Default level to info
	[ -z ${log_level} ] && log_level="INFO"
	[ -z ${log_color} ] && log_color="LOG_INFO_COLOR"

	# Validate LOG_LEVEL_STDOUT and LOG_LEVEL_LOG since they'll be eval-ed
	case $LOG_LEVEL_STDOUT in
		DEBUG|INFO|SUCCESS|WARNING|ERROR) ;;
		TRACE_ENTRY|TRACE_EXIT)			  ;;
		*) LOG_LEVEL_STDOUT=INFO		  ;;
	esac
	case $LOG_LEVEL_LOG in
		DEBUG|INFO|SUCCESS|WARNING|ERROR) ;;
		TRACE_ENTRY|TRACE_EXIT)			  ;;
		*) LOG_LEVEL_LOG=INFO			  ;;
	esac

	# Check LOG_LEVEL_STDOUT to see if this level of entry goes to STDOUT
	# XXX This is the horror that happens when your language doesn't have a hash data struct
	eval log_level_int="\$LOG_LEVEL_${clean_level}";
	eval log_level_stdout="\$LOG_LEVEL_${LOG_LEVEL_STDOUT}"
	eval log_color="\$log_color"
	if [ $log_level_stdout -le $log_level_int ]; then
		# STDOUT
		printf "${log_color}[$(date +"%Y-%m-%d %H:%M:%S")] ${log_level} ${log_text} ${LOG_DEFAULT_COLOR}\n";
	fi
	eval log_level_log="\$LOG_LEVEL_${LOG_LEVEL_LOG}"

	# Check LOG_LEVEL_LOG to see if this level of entry goes to LOG_PATH
	if [ $log_level_log -le $log_level_int ]; then
		# LOG_PATH minus fancypants colors
		if [ ! -z $LOG_PATH ]; then
			printf "${log_color}[$(date +"%Y-%m-%d %H:%M:%S")] ${log_level} ${log_text}\n" >> $LOG_PATH;
		fi
	else
		if [ ! -z $LOG_PATH ]; then
			printf "${log_color}[$(date +"%Y-%m-%d %H:%M:%S")] ${log_level} < ${FUNC}\n" >> $LOG_PATH;
		fi
	fi
	return 0;
}

case "$SCRIPT_EXTENSION" in
	sh)
		# Enable POSIX shell features
		log_info()    { log "$1" "[INFO]    " "${LOG_INFO_COLOR}"; }
		log_success() { log "$1" "[SUCCESS] " "${LOG_SUCCESS_COLOR}"; }
		log_error()   { log "$1" "[ERROR]   " "${LOG_ERROR_COLOR}"; }
		log_warning() { log "$1" "[WARNING] " "${LOG_WARNING_COLOR}"; }
		log_debug()   { log "$1" "[DEBUG]   " "${LOG_DEBUG_COLOR}"; }
		;;
	zsh)
		# Enable zsh-specific features
		SCRIPTENTRY() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "TRACE_ENTRY" "${LOG_DEBUG_COLOR}"
		}

		SCRIPTEXIT() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "TRACE_EXIT" "${LOG_DEBUG_COLOR}"
		}

		trace_begin() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "TRACE_ENTRY" "${LOG_DEBUG_COLOR}"
		}

		log_info() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "INFO" "${LOG_INFO_COLOR}"
		}

		log_success() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "SUCCESS" "${LOG_SUCCESS_COLOR}"
		}

		log_error() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "ERROR" "${LOG_ERROR_COLOR}"
		}

		log_warning() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "WARNING" "${LOG_WARNING_COLOR}"
		}

		log_debug() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "DEBUG" "${LOG_DEBUG_COLOR}"
		}

		trace_end() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "TRACE_EXIT" "${LOG_DEBUG_COLOR}"
		}
		;;
	*)
		echo "ERROR: Filetype "$SCRIPT_EXTENSION" not compatible with logging tool "
		return 1
		;;
esac
