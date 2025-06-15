#!/bin/zsh
# -------------------------------------------------------------------
# slog - Makes logging in POSIX shell scripting suck less
# Copyright (c) Fred Palmer
# POSIX version Copyright Joe Cooper
# Licensed under the MIT license
# http://github.com/swelljoe/slog
# -------------------------------------------------------------------

# Exit on error
set -e

LOG_PRINT_USAGE() {
	cat <<EOF
Usage: ./your_script.sh [options]

Options:
  sh|zsh|bash                 Set the script extension (affects \$SCRIPT_EXTENSION)
  -h, --help                  Show this help message and exit
  -c, --config                Configuration file location
  -o, --output                Set the output log file path
                              Same as \$LOG_PATH



Styles:                       Availabel: enhanced, standard, classic
  -s, --style                 Set the log output format, default is enhanced
      --no-custom-labels      Enable custom labels (boolean)

Logging levels:               Availabel: info, success, warning, error, debug
  -L, --log-level-global      Override global log levels, default is info
                              Same as \$LOG_LEVEL_DEFAULT
      --log-level-log         Set the minimum log level to log to file 
                              Same as \$LOG_LEVEL_LOG
      --log-level-stdout      Set the minimum log level to print to stdout 
                              Same as \$LOG_LEVEL_STDOUT

Examples:
  ./your_script.sh bash -f symmetric -c DEBUG -o /tmp/log.txt
  ./your_script.sh --help

EOF
}

# TODO: log usage documentation
# Usage log [label] [text] -l 10 -t 10

# TODO: install.sh
LOG_CONFIG_DEFAULT_LOCATION="${XDG_CONFIG_HOME:-$HOME/.config}/shlog"
LOG_CONFIG_CUSTOM_LOCATION="" # This should be set as a global env path
LOG_CONFIG_AUTO_LOCATION="${LOG_CONFIG_CUSTOM_LOCATION:-$LOG_CONFIG_DEFAULT_LOCATION}"

# Move default to custom if needed
if [ -n "$LOG_CONFIG_CUSTOM_LOCATION" ] && [ -d "$LOG_CONFIG_DEFAULT_LOCATION" ] && [ ! -d "$LOG_CONFIG_CUSTOM_LOCATION" ]; then
	mkdir -p "$(dirname "$LOG_CONFIG_CUSTOM_LOCATION")"
	mv -n "$LOG_CONFIG_DEFAULT_LOCATION" "$LOG_CONFIG_CUSTOM_LOCATION"
fi

# Create auto location if still missing
if [ ! -d "$LOG_CONFIG_AUTO_LOCATION" ]; then
	mkdir -p "$LOG_CONFIG_AUTO_LOCATION" || echo "Failed to create directory: $LOG_CONFIG_AUTO_LOCATION" >&2
fi

# TODO: shlog_parse.sh

LOG_CHECK_FLAG() { [ -z "$2" ] && echo "$1 requires an argument" >&2 }
while [ $# -gt 0 ]; do
	case "$1" in
		sh|zsh|bash)
			SCRIPT_EXTENSION="$1"
			shift
			;;

		-h|--help)
      LOG_PRINT_USAGE
      exit 0
      ;;

    -c|--config)
      LOG_CHECK_FLAG "-c, --config" "$2" || return 1
      LOG_CONFIG_LOCATION
      shift 2
      continue
      ;;

    -o|--output)
      LOG_CHECK_FLAG "-o, --output" "$2" || return 1
      LOG_PATH="$2"
      shift 2
      continue
      ;;

    -s|--style)
      LOG_CHECK_FLAG "-S, --style" "$2" || return 1
      LOG_PRESET_FORMAT="$2"
      shift 2
      continue
      ;;

    --no-custom-labels)
      LOG_USE_CUSTOM_LABELS="off"
			shift
			continue
      ;;

    -L|--log-level-global)
      LOG_CHECK_FLAG "-L, --log-level" "$2" || return 1
      LOG_LEVEL_DEFAULT=$(echo "$2" | tr '[:lower:]' '[:upper:]')
      shift 2
      continue
      ;;

    --log-level-log)
      LOG_CHECK_FLAG "--log-level-log" "$2" || return 1
			LOG_LEVEL_DEFAULT=$(echo "$2" | tr '[:lower:]' '[:upper:]')
      LOG_LEVEL_LOG="$2"
      shift 2
      continue
      ;;

    --log-level-stdout)
      LOG_CHECK_FLAG "--log-level-stdout" "$2" || return 1
      LOG_LEVEL_STDOUT="$2"
      shift 2
      continue
      ;;

    *) 
      echo "Unknown option: $1" >&2
      shift
      continue
      ;;
  esac
done


# LOG_PATH - Define $LOG_PATH in your script to log a file, otherwise 
# just write to STDOUT
# LOG_PATH="./my.log"

# LOG_LEVEL_MODE - Define $LOG_LEVEL_MODE to change the log level preset,
# By default, this value is set to INFO
LOG_LEVEL_DEFAULT="${LOG_LEVEL_DEFAULT:-INFO}"

# LOG_LEVEL_STDOUT - Define the lowest level which goes to STDOUT
# By default, all logs will be written to STDOUT
LOG_LEVEL_STDOUT="${LOG_LEVEL_DEFAULT:-INFO}"

# LOG_LEVEL_LOG - Define to determine which level goes to LOG_PATH 
# By default, all log levels will be written to LOG_PATH
LOG_LEVEL_LOG="${LOG_LEVEL_DEFAULT:-INFO}"

# LOG_USE_CUSTOM_LABELS - Boolean to determine if custom labels are allowed. 
# By default, custom labels are enabled.
# If disabled, custom tags will be overwritten to INFO
LOG_USE_CUSTOM_LABELS="${LOG_USE_CUSTOM_LABELS:-"on"}"

# Useful global variables that users may wish to reference
SCRIPT_ARGS="$@"
SCRIPT_NAME="$0"
SCRIPT_NAME="${SCRIPT_NAME#\./}"
SCRIPT_NAME="${SCRIPT_NAME##/*/}"
SCRIPT_EXTENSION=$(ps -p "$$" -o comm=)
SCRIPT_EXTENSION="${SCRIPT_EXTENSION##*.}"
LOG_FORMAT_PRESET="enhanced"

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
  LOG_TEXT_COLOR=""
  LOG_LABEL_COLOR=""
else
	LOG_DEFAULT_COLOR="$(tput sgr0)"
	LOG_ERROR_COLOR="$(tput setaf 1)"
	LOG_INFO_COLOR="$(tput sgr0)"
	LOG_SUCCESS_COLOR="$(tput setaf 2)"
	LOG_WARNING_COLOR="$(tput setaf 3)"
	LOG_DEBUG_COLOR="$(tput setaf 4)"
	LOG_TRACE_COLOR="$(tput setaf 8)"
  LOG_TEXT_COLOR=""
  LOG_LABEL_COLOR=""
fi

# Formatting helper
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g' }


repeat_char() {
	char=$1; count=$2
	while [ "$count" -gt 0 ]; do
		printf "%s" "$char"
		count=$((count - 1))
	done
	return 0
}

find_substring_offset() {
	search=$1; input=$2; index=${3:-1}
	set -f
	while [ -n "$input" ]; do
		case "$input" in
			"$search"*) echo "$index"; return 0 ;;
			?*) input="${input#?}"; index=$((index + 1)) ;;
		esac
	done
	#printf "ERROR: No match found for '%s' in '%s'\n" "$1" "$2" >&2
	set +f
	unset search input index
	return 0
}

replace_substring() { 
	search=$1; input=$2; match=$3
	output=""
	set -f
	set -- "$string"
	for word; do
	if [ "$word" = "$search" ]; then
	  output="${output:+$output }$match"
	else
		output="${output:+$output }$word"
	fi
	done
	set +f
	printf "%s\n" "$output"
	unset search input match
	return 0
}

# Arithmetic
is_int() {
	case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
	esac
}

in_range() {
	x=$1 a=$2; b=$3
	for num in "$x" "$a" "$b"; do
		if ! is_int "$num"; then
			printf "%s is not an integer \n" "$num"
			return 1
		fi	
	done
  if [ "$x" -lt "$a" ] || [ "$x" -gt "$b" ]; then
		return 1
	fi
	return 0
} 

# Helper functions
log_add_args() { log_args="${log_args:+$log_args }$1" }

log_add_badopt() { log_badopt="${log_badopt:-$1}" }



LOG_PARSE_ARGS() {
	unset log_args log_badopt
	unset log_label log_text log_level
	unset log_label_color log_text_color
	unset t_flag l_flag 

	# Reset all loging-related states
	# Parse args for log function call
	while [ "$#" -gt 0 ]; do
		case $1 in
			-t|-T|-l|-L)
				if [ -z "$text_flag" ]; then log_add_args "$1"; t_flag=1
				elif [ -z "$label_flag" ]; then log_add_args "$1"; l_flag=1
				else log_add_badopt "$1"
				fi
				;;

			LOG_*_COLOR|[0-9]|[0-9][0-9]|[0-9][0-9][0-9])
				log_add_args "$1"
				if [ -z "$log_label_color" ]; then log_label_color=$1
				elif [ -z "$log_text_color" ]; then log_text_color=$1
				else log_add_badopt "$1"
				fi
				;;

			-*) log_add_args "$1"; log_add_badopt "$1" ;;

			*)
				log_add_args "$1"
				if [ -z "$log_label" ]; then log_label="$1"
				elif [ -z "$log_text" ]; then log_text="$1"
				else log_add_badopt "$1"
				fi
				;;
		esac
		shift
	done
	# Infer color behavior if only one color flag is used:
	if [ "$text_flag" = "1" ] && [ "$label_flag" != "1" ]; then
		# -t was used, -l was not
		log_label_color="LOG_INFO_COLOR"
	elif [ "$label_flag" = "1" ] && [ "$text_flag" != "1" ]; then
		# -l was used, -t was not
		log_text_color="LOG_INFO_COLOR"
	elif [ -n "$log_label_color" ] && [ -z "$log_text_color" ]; then
		log_text_color=$log_label_color
	elif [ -z "$log_label_color" ] && [ -n "$log_text_color" ]; then
		log_label_color=$log_text_color
	fi	

	# If custom labels are disable, move label into text
	if [ "$LOG_USE_CUSTOM_LABELS" = "0" ]; then
		log_text="$log_label $log_text"
		log_label=""
	fi

	print_log_vars 
	return 0
}

print_log_vars() {
	#log_args_len=${#log_args}
	echo "log_args: $log_args"
	echo "log_level: $log_level"
	echo "log_label: $log_label"
	echo "log_text: $log_text"
	echo "log_text_color: $log_text_color"
	echo "log_label_color: $log_label_color"
	echo "log_badopt: $log_badopt"
	echo
}

# Function: LOG_PARSE_OPTERR
# Prints a warning for unrecognized log option, with offsets to show error location visually.
LOG_PARSE_OPTERR() {
	search="$1"; input="$2"; func_call="log $input"
	#echo "$search"
	#echo "$input"
	len=$(expr "x$search" : 'x.*' - 1)
	pos=$(find_substring_offset "$search" "$input" 0)
	ws=$(find_substring_offset " " "$search" 0)
	z=$"*[[:space:]]*"
	case "$search" in
		$z)   offset=$((pos + ws)); match=$((len = 1)) ;;
		-)	  offset=$((pos + 0));  match=$((len = 1)) ;;
		--)	  offset=$((pos + 0));  match=$((len = 2)) ;;
		---*) offset=$((pos + 0));  match=$((len = 3)) ;;
		--*)  offset=$((pos + 2));  match=$((len - 2)) ;;
		-*)	  offset=$((pos + 1));  match=$((len - 1)) ;;
		*)	  offset=$((pos + 0));  match=$((len - 0)) ;;
	esac
	output=$(replace_substring "$search" "$func_call" "\`"$search"\`")

	#printf "Matched pattern '%s' at index: %d\n" "$search" "$offset"
	printf "%s\n" "$output"
	repeat_char "~" "$offset"
	repeat_char "^" "$match"
	printf "\n"

	# Cleanup
	unset search input offset match
	return 0
}

log() {
  # Parse arguments passed to `log`
  LOG_PARSE_ARGS $@	
	
	# If we have a bad option print it to stdout
	if [ -n "$log_badopt" ]; then 
		LOG_PARSE_OPTERR "$log_badopt" "$log_args"
	fi

	# # Levels for comparing against LOG_LEVEL_STDOUT and LOG_LEVEL_LOG
	# LOG_LEVEL_TRACE=0
	# LOG_LEVEL_DEBUG=0
	# LOG_LEVEL_CUSTOM=0
	# LOG_LEVEL_INFO=1
	# LOG_LEVEL_SUCCESS=2
	# LOG_LEVEL_WARNING=3
	# LOG_LEVEL_ERROR=4
	# LOG_LEVEL_CUSTOM=5
	#
	# # Default level to info
	# [ -z "$log_level" ] && log_level="INFO"
	# [ -z "$log_text_color" ] && log_text_color="LOG_INFO_COLOR"
	# [ -z "$log_label_color" ] && log_label_color="LOG_INFO_COLOR"
	#
	#  # Extract the log_level from the label
	#  case $log_label in
	#    DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE)
	#       log_level="$1"                             ;;
	#    *) log_level="CUSTOM"                         ;;
	#  esac
	# # Validate levels since they'll be eval-ed
	# case $LOG_LEVEL_STDOUT in
	# 	DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE|CUSTOM) ;;
	# 	*) LOG_LEVEL_STDOUT=INFO				               ;;
	# esac
	# case $LOG_LEVEL_LOG in
	# 	DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE|CUSTOM) ;;
	# 	*) LOG_LEVEL_LOG=INFO                          ;;
	# esac
	#  # Validate custom color
	#  case $log_text_color in
	#    DEBUG*|INFO*|SUCCESS*|WARNING*|ERROR*|TRACE)    ;;
	# 	*)
	# 		if in_range "$(($log_text_color))" "0" "255"; then
	# 			LOG_TEXT_COLOR="$(tput setaf $log_text_color)"
	# 		else
	# 			LOG_PARSE_ERR "$log_text_color" "$@"
	# 			return 1
	# 		fi
	#  esac
	# case $log_label_color in
	# 	#*[0-9]*) LOG_LABEL_COLOR=$(tput setaf $log_label_color)         ;;
	#    DEBUG*|INFO*|SUCCESS*|WARNING*|ERROR*|TRACE*)		;;
	#    *) ;;
	#  esac
	#
	# # Check LOG_LEVEL_STDOUT to see if this level of entry goes to STDOUT
	# # XXX This is the horror that happens when your language doesn't have a hash data struct
	# eval log_level_int="\$LOG_LEVEL_${log_level}";
	# eval log_level_stdout="\$LOG_LEVEL_${LOG_LEVEL_STDOUT}";
	# if ! is_int $log_label_color; then 
	# 	eval log_label_color="\$LOG_${log_level}_COLOR"
	# fi
	# if ! is_int $log_text_color; then
	# 	eval log_text_color="\$LOG_${log_level}_COLOR"
	# fi
	#
	#  # This is where we format the different styles
	# case "$LOG_FORMAT_PRESET" in	
	# 	enhanced)
	# 		if [ "$log_level" = "TRACE" ]; then
	# 			log_prefix="[TRACE] >"
	# 		else
	# 			log_prefix=$(printf "[%s]%*s" "$log_label" $((9 - ${#log_label} - 2)) "" )		
	# 		fi
	# 		;;
	# 	standard) 
	# 		log_prefix="[${log_label}]" ;;
	# 	classic)  
	# 		log_prefix="${log_label}:"  ;;
	# 	*) 
	# 		echo "Unknown style: $LOG_FORMAT_PRESET (use: symmetric|simple|classic)" ;;
	# esac
	#
	# #echo "$log_level_stdout $log_level_int"; return 1
	# if [ $log_level_stdout -le $log_level_int ]; then
	# 	# STDOUT
	# 	printf "${LOG_LABEL_COLOR-log_label_color}[%s] %s${LOG_DEFAULT_COLOR} ${LOG_TEXT_COLOR-log_text_color}%s${LOG_DEFAULT_COLOR}\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "$log_text"
	# fi
	# eval log_level_log="\$LOG_LEVEL_${LOG_LEVEL_LOG}"
	#
	# # Check LOG_LEVEL_LOG to see if this level of entry goes to LOG_PATH
	# if [ $log_level_log -le $log_level_int ]; then
	# 	# LOG_PATH minus fancypants colors
	# 	if [ ! -z $LOG_PATH ]; then
	# 		printf "[%s] %s %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "${log_text}" >> $LOG_PATH;
	# 	fi
	# fi
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
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "INFO" "$LOG_INFO_COLOR"
			log "INFO" "$msg" "$LOG_INFO_COLOR"
		}

		log_success() {
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "SUCCESS" "$LOG_SUCCESS_COLOR"
			log "SUCCESS" "$msg" "$LOG_SUCCESS_COLOR"
		}

		log_error() {
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "ERROR" "$LOG_ERROR_COLOR"
			log "ERROR" "$msg" "$LOG_ERROR_COLOR"
		}

		log_warning() {
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "WARNING" "$LOG_WARNING_COLOR"
			log "WARNING" "$msg" "$LOG_WARNING_COLOR"
		}

		log_debug() {
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "DEBUG" "$LOG_DEBUG_COLOR"
			log "DEBUG" "$msg" "$LOG_DEBUG_COLOR"
		}

		SCRIPTENTRY() {
			local script_name=${funcstack[2]:-${SCRIPT_NAME}}
			local msg=${1:+($1)}
			# log "> $script_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"
			log "TRACE" "$script_name:$LINENO "$msg"" "$LOG_TRACE_COLOR"
		} 

		SCRIPTEXIT() {
			local script_name=${funcstack[2]:-${SCRIPT_NAME}}
			local msg=${1:+($1)}
			# log "< $script_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"				
			log "TRACE" "$script_name:$LINENO "$msg"" "$LOG_TRACE_COLOR"				
		}

		trace_in() {
			local func_name=${funcstack[2]:-${funcfiletrace}}
			local msg=${1:+($1)}
			# log "> $func_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"				
			log "TRACE" "$func_name:$LINENO $msg" "$LOG_TRACE_COLOR"				
		}

		trace_out() {
			local func_name=${funcstack[2]:-${SCRIPT_NAME}}
			local msg=${1:+($1)}
			#log "< $func_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"				
			log "TRACE" "$func_name:$LINENO "$msg"" "$LOG_TRACE_COLOR"				
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
