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
# LOG_PATH="./my.log"

# LOG_LEVEL_MODE - Define $LOG_LEVEL_MODE to change the log level preset,
# By default, this value is set to INFO
LOG_LEVEL_MODE="${LOG_LEVEL_MODE:-INFO}"

# LOG_LEVEL_STDOUT - Define the lowest level which goes to STDOUT
# By default, all logs will be written to STDOUT
LOG_LEVEL_STDOUT="${LOG_LEVEL_MODE:-INFO}"

# LOG_LEVEL_LOG - Define to determine which level goes to LOG_PATH 
# By default, all log levels will be written to LOG_PATH
LOG_LEVEL_LOG="${LOG_LEVEL_MODE:-INFO}"

# Useful global variables that users may wish to reference
SCRIPT_ARGS="$@"
SCRIPT_NAME="$0"
SCRIPT_NAME="${SCRIPT_NAME#\./}"
SCRIPT_NAME="${SCRIPT_NAME##/*/}"
SCRIPT_EXTENSION=$(ps -p "$$" -o comm=)
SCRIPT_EXTENSION="${SCRIPT_EXTENSION##*.}"
LOG_FORMAT_PRESET="enhanced"

# TODO: Add parse options:


# Determines if we print color or not
if ! tty -s; then
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
	LOG_TRACE_COLOR=""
	LOG_CUSTOM_COLOR=""
else
	LOG_DEFAULT_COLOR="$(tput sgr0)"
	LOG_ERROR_COLOR="$(tput setaf 1)"
	LOG_INFO_COLOR="$(tput sgr0)"
	LOG_SUCCESS_COLOR="$(tput setaf 2)"
	LOG_WARNING_COLOR="$(tput setaf 3)"
	LOG_DEBUG_COLOR="$(tput setaf 4)"
	LOG_TRACE_COLOR="$(tput setaf 8)"
fi

# Formatting
strip_ansi() {
	sed 's/\x1b\[[0-9;]*m//g'
}

log() {
	local log_text="$1"
	local log_level="$2"
	local log_text_color="$3"
	
	# Levels for comparing against LOG_LEVEL_STDOUT and LOG_LEVEL_LOG
	# Define log level integers
	local LOG_LEVEL_DEBUG=0
	local LOG_LEVEL_TRACE=0
	local LOG_LEVEL_INFO=1
	local LOG_LEVEL_SUCCESS=2
	local LOG_LEVEL_WARNING=3
	local LOG_LEVEL_ERROR=4
	
	# Default level to info
	[ -z ${log_level} ] && log_level="INFO"
	[ -z ${log_color} ] && log_color="LOG_INFO_COLOR"

	# Validate LOG_LEVEL_STDOUT, LOG_LEVEL_LOG and LOG_FORMAT_PRESET 
	# since they'll be eval-ed
	case $LOG_LEVEL_STDOUT in
		DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE) ;;
		*) LOG_LEVEL_STDOUT=INFO				;;
	esac
	case $LOG_LEVEL_LOG in
		DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE) ;;
		*) LOG_LEVEL_LOG=INFO					;;
	esac

	# Check LOG_LEVEL_STDOUT to see if this level of entry goes to STDOUT
	# XXX This is the horror that happens when your language doesn't have a hash data struct
	eval log_level_int="\$LOG_LEVEL_${log_level}";
	eval log_level_stdout="\$LOG_LEVEL_${LOG_LEVEL_STDOUT}";
	eval log_label_color="\$LOG_${log_level}_COLOR"	

	case $LOG_FORMAT_PRESET in
		# symmetric) log_prefix=$(printf "[%s]%*s" "$log_level" $((9 - ${#log_level} - 2)) "") ;;
		enhanced) log_prefix=$( [ $log_level = "TRACE" ] && echo "[TRACE]" || printf "[%s]%*s" "$log_level" $((9 - ${#log_level} - 2)) "") ;; # Width = 9 - length of log_level - 2 (for [ and ] )
		standard) log_prefix="[${log_level}]" ;;
		classic)  log_prefix="${log_level}:"  ;;
		*)         echo "Unknown style: $LOG_FORMAT_PRESET (use: symmetric|simple|classic)" ;;
	esac

	#echo "$log_level_stdout $log_level_int"; return 1
	if [ $log_level_stdout -le $log_level_int ]; then
		# STDOUT
		printf "${log_label_color}[%s] - %s ${log_text_color}%s${LOG_DEFAULT_COLOR}\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "$log_text"
	fi
	eval log_level_log="\$LOG_LEVEL_${LOG_LEVEL_LOG}"

	# Check LOG_LEVEL_LOG to see if this level of entry goes to LOG_PATH
	if [ $log_level_log -le $log_level_int ]; then
		# LOG_PATH minus fancypants colors
		if [ ! -z $LOG_PATH ]; then
			printf "[%s] - %s %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "${log_text}" >> $LOG_PATH;
		fi
	fi
	return 0;
}

case "$SCRIPT_EXTENSION" in
	sh)
		# Enable POSIX shell features
		log_info()    { log "$1" "INFO" "$LOG_INFO_COLOR"; }
		log_success() { log "$1" "SUCCESS" "$LOG_SUCCESS_COLOR"; }
		log_error()   { log "$1" "ERROR" "$LOG_ERROR_COLOR"; }
		log_warning() { log "$1" "WARNING" "$LOG_WARNING_COLOR"; }
		log_debug()   { log "$1" "DEBUG" "$LOG_DEBUG_COLOR"; }
		;;
	zsh)
		# Enable zsh-specific features
		log_info() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "INFO" "$LOG_INFO_COLOR"
		}

		log_success() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "SUCCESS" "$LOG_SUCCESS_COLOR"
		}

		log_error() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "ERROR" "$LOG_ERROR_COLOR"
		}

		log_warning() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "WARNING" "$LOG_WARNING_COLOR"
		}

		log_debug() {
			local func_name="${FUNCNAME[1]}"
			local msg=$1
			log "$msg" "DEBUG" "$LOG_DEBUG_COLOR"
		}

		SCRIPTENTRY() {
			local func_name=${funcstack[2]:-${SCRIPT_NAME}}
			local msg=${1:+($1)}
			log "> $func_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"
		} 

		SCRIPTEXIT() {
			local func_name=${funcstack[2]:-${SCRIPT_NAME}}
			local msg=${1:+($1)}
			log "< $func_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"				
		}

		trace_in() {
			echo $funcfiletrace; return 1
			local func_name=${funcstack[2]:-${funcfiletrace}}
			local msg=${1:+($1)}
			log "> ${FUNCNAME[1]} ($1)" "TRACE" "$LOG_TRACE_COLOR"
		}

		trace_out() {
			local func_name=${funcstack[2]:-${SCRIPT_NAME}}
			local msg=${1:+($1)}
			log "< ${FUNCNAME[1]} ($1)" "TRACE" "$LOG_TRACE_COLOR"
		}
		;;
	bash) shift;
		# TODO:
		;;
	*)
		echo "ERROR: Filetype "$SCRIPT_EXTENSION" not compatible with logging tool "
		return 1
		;;
esac


