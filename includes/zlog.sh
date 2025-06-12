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
      --custom-labels         Enable custom labels (boolean)

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

LOG_CHECK_FLAG() { [ -n "$2" ] && echo "$1 requires an argument" >&2 }
while [ $# -gt 0 ]; do
	case "$1" in
		sh|zsh|bash)
			SCRIPT_EXTENSION=$1
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

    --custom-labels)
      LOG_USE_CUSTOM_LABELS=1
      ;;

    -L|--log-level-global)
      LOG_CHECK_FLAG "-L, --log-level" "$2" || return 1
      LOG_LEVEL_DEFAULT=$(echo "$2" | tr '[:lower:]' '[:upper:]')
      shift 2
      continue
      ;;

    --log-level-log)
      LOG_CHECK_FLAG "--log-level-log" "$2" || return 1
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

# Formatting
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g' }
is_int() { [ -n "$1" ] && printf %d "$1" >/dev/null 2>&1 }
repeat_char() {
	char=$1; count=$2
	while [ "$count" -gt 0 ]; do
		printf "%s" "$char"
		count=$((count - 1))
	done
}

LOG_PARSE_ARGS() {

	# echo "fun_call: $@"
	# Reset all loging-related states
  unset log_level log_label log_text log_text_color log_label_color
	unset label_flag text_flag color_flag
	unset log_parsed_kwargs log_kwargs log_args log_parsed_arg
	unset log_add_args log_add_kwargs
	unset log_badopt log_badopt_len log_badopt_l_offset

	# Parse args for log function call
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-h|--help)
				# TODO
				;;

			-t|-T)
				# Handle text color flag
				text_flag=1
				log_add_kwargs "$1" "$2"

				[ -n "$2" ] && log_text_color=$2 
				[ -n "$2" ] && shift 2 || shift 1
				continue
				;;

			-l|-L)
				# Handle label color flag
				label_flag=1
				log_add_kwargs "$1" "$2"

				[ -n "$2" ] && log_label_color=$2
				[ -n "$2" ] && shift 2 || shift 1
				continue
				;;
			
			*[0-9]*|LOG_*_COLOR)
				# Handle direct color codes or env color vars
				log_add_args "$1"

				[ -z "$log_label_color" ] && log_label_color=$1 && shift && continue
				[ -z "$log_text_color" ] && log_text_color=$1 && shift && continue
				;;

			-*)
				echo "Should be equal to $log_count"
				log_add_kwargs "$1" "$2"
				log_badopt=${log_badopt:-$1}
				log_badopt_l_offset="${log_badopt_l_offset:-$((${#log_args} - ${#2} + ${#1}))}"
				[ -n "$2" ] && shift 2 || shift 1
				continue
				;;
			*)
				log_add_args "$1"

				# Positional arguments: label, then text
				[ -z "$log_label" ] && log_label=$1 && shift && continue
				[ -z "$log_text" ] && log_text=$1 && shift && continue
				shift
				continue
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
	elif [ -z "$log_label_color" ] && [ -n "$log_label_color" ]; then
		log_label_color=$log_text_color
	elif [ -z "$log_text_color" ] && [ -n "$log_text_color" ]; then
		log_text_color=$log_label_color
	# else
	# 	log_text_color="LOG_INFO_COLOR"
	# 	log_label_color="LOG_INFO_COLOR"
	fi

	# If custom labels are disable, move label into text
	if [ "$LOG_USE_CUSTOM_LABELS" = "0" ]; then
		log_text="$log_label $log_text"
		log_label=""
	fi

	# If we have a bad option print it to stdout
	[ -n "$log_badopt" ] && LOG_PARSE_OPTERR
	return 0
}

log_add_kwargs() {
	log_parsed_kwargs="$1 $2"
	log_kwargs="${log_kwargs:+$log_kwargs }$log_parsed_kwargs"
	log_args="${log_args:+$log_args }$log_parsed_kwargs"
	log_count=${#log_args}
}

log_add_args() {
	log_parsed_arg=$1
	log_args="${log_args:+$log_args }$log_parsed_arg"
	log_count=${#log_args}
}

# Function: LOG_PARSE_OPTERR
# Prints a warning for unrecognized log option, with offsets to show error location visually.
LOG_PARSE_OPTERR() {
	log_func_name="log "
	log_func_call="log $log_args"
	printf "WARNING: Unknown option detected: %s\n" "$log_func_call"

	# Aritmetic vars to determine position of bad arg
	log_func_call_offset=$((34))
	log_args_len=${#log_args} # XXX
	log_kwargs_len=${#log_kwargs} # XXX
	log_badopt_len=${#log_badopt}

	if [ "$log_badopt_len" -eq 1 ]; then
		log_badopt_len=$((2))
		log_badopt_l_offset=$(($log_badopt_l_offset + 1))
	fi

	# See repeat_char func
	repeat_char " " "$log_func_call_offset"
	repeat_char "~" "$(($log_badopt_l_offset))"
	repeat_char "^" "$(($log_badopt_len - 1))"

	#print_log_vars
	printf "\n"
	
	# Cleanup
	unset log_badopt log_badopt_len log_badopt_l_offset
	unset log_kwargs log_kwargs_len
	unset log_args log_args_len
	unset log_func_call	log_func_call_offset
	return 1
}

print_log_vars() {
	log_args_len=${#log_args}
	log_kwargs_len=${#log_kwargs}

	echo "log_args: $log_args"
	echo "log_kwargs: $log_kwargs"
	# echo "log_level: $log_level"
	echo "log_label: $log_label"
	echo "log_text: $log_text"
	echo "log_text_color: $log_text_color"
	echo "log_label_color: $log_label_color"
	echo "log_args_len = $log_args_len"
	echo "should be equal to log_count: $log_count"
	echo
}

log() {
  # Parse arguments passed to `log`
  LOG_PARSE_ARGS $@	

	# Levels for comparing against LOG_LEVEL_STDOUT and LOG_LEVEL_LOG
	LOG_LEVEL_TRACE=0
	LOG_LEVEL_DEBUG=0
  LOG_LEVEL_CUSTOM=0
	LOG_LEVEL_INFO=1
	LOG_LEVEL_SUCCESS=2
	LOG_LEVEL_WARNING=3
  LOG_LEVEL_ERROR=4
	LOG_LEVEL_CUSTOM=5

	# Default level to info
	[ -z "$log_level" ] && log_level="INFO"
	[ -z "$log_text_color" ] && log_text_color="LOG_INFO_COLOR"
	[ -z "$log_label_color" ] && log_label_color="LOG_INFO_COLOR"

  # Extract the log_level from the label
  case $log_label in
    DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE)
       log_level="$1"                             ;;
    *) log_level="CUSTOM"                         ;;
  esac
	# Validate levels since they'll be eval-ed
	case $LOG_LEVEL_STDOUT in
		DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE|CUSTOM) ;;
		*) LOG_LEVEL_STDOUT=INFO				               ;;
	esac
	case $LOG_LEVEL_LOG in
		DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE|CUSTOM) ;;
		*) LOG_LEVEL_LOG=INFO                          ;;
	esac
  # Validate custom color
  case $log_text_color in
    *[0-9]*) LOG_TEXT_COLOR="$(tput setaf $log_text_color)"         ;;
    *DEBUG*|*INFO*|*SUCCESS*|*WARNING*|*ERROR*|*TRACE*|*CUSTOM*)    ;;
		*) 
      printf "WARNING: \`%s\` is not a valid color\n" "$log_text_color"  ;; 
  esac
	case $log_label_color in
    *[0-9]*) LOG_LABEL_COLOR=$(tput setaf $log_label_color)         ;;
    *DEBUG*|*INFO*|*SUCCESS*|*WARNING*|*ERROR*|*TRACE*|*CUSTOM*)		;;
    *)
      printf "WARNING: \`%s\` is not a valid color\n" "$log_label_color" ;; 
  esac

	# Check LOG_LEVEL_STDOUT to see if this level of entry goes to STDOUT
	# XXX This is the horror that happens when your language doesn't have a hash data struct
	eval log_level_int="\$LOG_LEVEL_${log_level}";
	eval log_level_stdout="\$LOG_LEVEL_${LOG_LEVEL_STDOUT}";
	if ! is_int $log_label_color; then 
		eval log_label_color="\$LOG_${log_level}_COLOR"
	fi
	if ! is_int $log_text_color; then
		eval log_text_color="\$LOG_${log_level}_COLOR"
	fi
  
  # This is where we format the different styles
	case "$LOG_FORMAT_PRESET" in	
		enhanced)
			if [ "$log_level" = "TRACE" ]; then
				log_prefix="[TRACE] >"
			else
				log_prefix=$(printf "[%s]%*s" "$log_label" $((9 - ${#log_label} - 2)) "" )		
			fi
			;;
		standard) log_prefix="[${log_label}]" ;;
		classic)  log_prefix="${log_label}:"  ;;
		*) echo "Unknown style: $LOG_FORMAT_PRESET (use: symmetric|simple|classic)" ;;
	esac

	#echo "$log_level_stdout $log_level_int"; return 1
	if [ $log_level_stdout -le $log_level_int ]; then
		# STDOUT
		printf "${LOG_LABEL_COLOR-log_label_color}[%s] %s${LOG_DEFAULT_COLOR} ${LOG_TEXT_COLOR-log_text_color}%s${LOG_DEFAULT_COLOR}\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "$log_text"
	fi
	eval log_level_log="\$LOG_LEVEL_${LOG_LEVEL_LOG}"

	# Check LOG_LEVEL_LOG to see if this level of entry goes to LOG_PATH
	if [ $log_level_log -le $log_level_int ]; then
		# LOG_PATH minus fancypants colors
		if [ ! -z $LOG_PATH ]; then
			printf "[%s] %s %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "${log_text}" >> $LOG_PATH;
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
