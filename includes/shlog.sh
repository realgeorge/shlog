#!/bin/sh
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

save_var() {
  # Usage: save_var VAR_NAME
  var_name=$1
  var_value=$(eval "printf '%s' \"\$$var_name\"")
  printf "%s=\"%s\"\n" "$var_name" "$var_value"
	return 0
}

SAVE_CONFIG() {
 # Ensure directory exists
  config_dir=$(dirname "$LOG_CONFIG_FILE")
  mkdir -p "$config_dir" || {
    printf "Failed to create config directory: %s\n" "$config_dir" >&2
    exit 1
  }

  # Backup old config if it exists
  if [ -f "$LOG_CONFIG_FILE" ]; then
    cp -p "$LOG_CONFIG_FILE" "$LOG_CONFIG_FILE.bak" || {
      printf "Warning: could not backup existing config\n" >&2
    }
  fi

  # Write variables to config file
  {
    printf "# shlog config file\n"
    save_var LOG_LEVEL_DEFAULT
    save_var LOG_LEVEL_LOG
    save_var LOG_LEVEL_STDOUT
    save_var LOG_PATH
    save_var LOG_PRESET_FORMAT
    save_var LOG_USE_CUSTOM_LABELS
    # etc.    # Add more variables as needed here
  } > "$LOG_CONFIG_FILE" || {
    printf "Failed to write config file: %s\n" "$LOG_CONFIG_FILE" >&2
    exit 1
  }

  printf "Config saved to %s\n" "$LOG_CONFIG_FILE"
	return 0
}

LOAD_CONFIG() {
	# Setting 'IFS' tells 'read' where to split the string.
	while IFS='=' read -r key val; do
		# Skip over lines containing comments.
		# (Lines starting with '#').
		[ "${key##\#*}" ] || continue

		# '$key' stores the key.
		# '$val' stores the value.
		# printf '%s: %s\n' "$key" "$val"

		# Alternatively replacing 'printf' with the following
		# populates variables called '$key' with the value of '$val'.
		#
		# NOTE: I would extend this with a check to ensure 'key' is
		#       a valid variable name.
		# export "$key=$val"
		#
		# Example with error handling:
		export "$key=$val" 2>/dev/null || 
			printf 'warning %s is not a valid variable name\n' "$key"
	done < "$1"
	return 0
}

LOG_CHECK_FLAG() { [ -z "$2" ] && printf "%s\n" "$1 requires an argument" >&2 && return 1; return 0 ;}
call_args="$@"

opterr() { printf "%s: %s %s" "$2" "$1" "$3" >&2 && exit 1 ;}

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
      LOG_CHECK_FLAG "-c, --config" "$2"
			if [ -z "$2" ]; then 
				log_config_location="./";
				shift
			else
				log_config_location=$(printf "%s" "$2" | sed "s|^~|$HOME|")
				shift 2
			fi
      LOG_CONFIG_CUSTOM_LOCATION="$log_config_location/shlog"
      continue
      ;;

		-o|--output)
			LOG_CHECK_FLAG "-o, --output" "$2" || opterr "$1" "Missing argument"
			LOG_PATH="$2"
			shift 2
			continue
			;;

    -s|--style)
      LOG_CHECK_FLAG "-S, --style" "$2" || opterr "$1" "Missing argument"
      LOG_PRESET_FORMAT="$2"
      shift 2
      continue
      ;;

		-q|--quiet) # TODO: 
			;;

		--load-config) 
			LOG_CHECK_FLAG "--load-config" "$2"
			[ -z "$2" ] && log_config_location="./config/shlog.conf"
			log_config_location=$(printf "%s\n" "$2" | sed "s|^~|$HOME|")

			LOG_LOAD_CONFIG="true"
			[ -z "$LOG_SAVE_CONFIG" ] || opterr "$1" "Configuration error" "can not be used together with --load-config"
			[ -f "$2" ] && LOG_CONFIG_FILE="$log_config_location"
			[ -d "$2" ] && LOG_CONFIG_FILE="$log_config_location/shlog.conf"
			[ -z "$2" ] shift 1 || shift 2 
			continue
			;;
		
		--save-config)
			LOG_CHECK_FLAG "--save-config" "$2"
			log_config_location=$(printf "%s\n" "$2" | sed "s|^~|$HOME|")

			LOG_SAVE_CONFIG="true"
			[ -z "$LOG_SAVE_CONFIG" ] || opterr "$1" "Configuration error" "can not be used together with --load-config"
			[ -f "$2" ] && LOG_CONFIG_FILE="$log_config_location"
			[ -d "$2" ] && LOG_CONFIG_FILE="$log_config_location/shlog.conf"
			[ -z "$2" ] shift 1 || shift 2 
			continue
			;;

    --no-custom-labels)
			LOG_CHECK_FLAG "--save-config" "$2" || opterr "$1" "Missing argument"
      LOG_USE_CUSTOM_LABELS="off"
			shift
			continue
      ;;

		-L|--log-level-global)
			LOG_CHECK_FLAG "-L, --log-level" "$2" || opterr "$1" "Missing argument"
			LOG_LEVEL_DEFAULT=$(printf "%s\n" "$2" | tr '[:lower:]' '[:upper:]')
			shift 2
			continue
			;;

    --log-level-log)
      LOG_CHECK_FLAG "--log-level-log" "$2" || opterr "$1" "Missing argument"
			LOG_LEVEL_LOG=$(printf "%s\n" "$2" | tr '[:lower:]' '[:upper:]')
      shift 2
      continue
      ;;

    --log-level-stdout)
      LOG_CHECK_FLAG "--log-level-stdout" "$2" || opterr "$1" "Missing argument"
      LOG_LEVEL_STDOUT="$2"
      shift 2
      continue
      ;;

    *) 
      printf "%s\n" "Unknown option: $1" >&2
      shift
      continue
      ;;
  esac
done

# LOG_CONFIG_CUSTOM_LOCATION should be set as a global env path
LOG_CONFIG_CUSTOM_LOCATION=${LOG_CONFIG_CUSTOM_LOCATION:-""} 
LOG_CONFIG_DEFAULT_LOCATION="${XDG_CONFIG_HOME:-$HOME/.config}/shlog"
LOG_CONFIG_AUTO_LOCATION="${LOG_CONFIG_CUSTOM_LOCATION:-$LOG_CONFIG_DEFAULT_LOCATION}"

# Move default to custom if needed
if [ -n "$LOG_CONFIG_CUSTOM_LOCATION" ] &&
   [  -d "$LOG_CONFIG_DEFAULT_LOCATION" ] &&
   [ ! -d "$LOG_CONFIG_CUSTOM_LOCATION" ]; then
	mkdir -p "$(dirname "$LOG_CONFIG_CUSTOM_LOCATION")"
	mv -nv --strip-trailing-slashes "$LOG_CONFIG_DEFAULT_LOCATION" "$LOG_CONFIG_CUSTOM_LOCATION"
	printf "%s\n" "Moved default to custom (1)"
fi

# Create auto location if still missing
if [ ! -d "$LOG_CONFIG_AUTO_LOCATION" ]; then
	mkdir -p "$LOG_CONFIG_AUTO_LOCATION" || printf "%s\n" "Failed to create directory: $LOG_CONFIG_AUTO_LOCATION" >&2
	printf "%s\n" "Created auto location (2)"
fi

# LOG_PATH - Define $LOG_PATH in your script to log a file, otherwise 
# just write to STDOUT
: ${LOG_PATH:=./shlog.log}

# LOG_LEVEL_MODE - Define $LOG_LEVEL_MODE to change the log level preset,
# By default, this value is set to INFO
: ${LOG_LEVEL_DEFAULT:=DEBUG}

# LOG_LEVEL_STDOUT - Define the lowest level which goes to STDOUT
# By default, all logs will be written to STDOUT
: ${LOG_LEVEL_DEFAULT:=DEBUG}

# LOG_LEVEL_LOG - Define to determine which level goes to LOG_PATH 
# By default, all log levels will be written to LOG_PATH
: ${LOG_LEVEL_DEFAULT:=DEBUG}

# LOG_USE_CUSTOM_LABELS - Boolean to determine if custom labels are allowed. 
# If disabled, custom tags will be overwritten to INFO
# By default, custom labels are enabled.
: ${LOG_USE_CUSTOM_LABELS:=on}

# LOG_FORMAT_PRESET - Determine which style is used for the logging tool
# By default, LOG_FORMAT_PRESET is set to enhanced
: ${LOG_FORMAT_PRESET:=enhanced}

# Fallback if no config file/dir is provided
: ${LOG_CONFIG_FILE:=$LOG_CONFIG_AUTO_LOCATION/shlog.conf}

if [ "$LOG_LOAD_CONFIG" = "true" ]; then
	[ -f "$LOG_CONFIG_FILE" ] && LOAD_CONFIG "$LOG_CONFIG_FILE" ||
	[ -f "$LOG_CONFIG_FILE/config/shlog.conf" ] && LOAD_CONFIG "$LOG_CONFIG_FILE/config/shlog.conf"
fi

if [ "$LOG_SAVE_CONFIG" = "true" ]; then 
	SAVE_CONFIG; 
fi

# Source the configuration and argument parsing script after setting 
# default values. This allows user-defined settings from config files or 
# command-line arguments to override the defaults initialized above.

# Useful global variables that users may wish to reference
SCRIPT_ARGS="$@"
SCRIPT_NAME="$0"
SCRIPT_NAME="${SCRIPT_NAME#\./}"
SCRIPT_NAME="${SCRIPT_NAME##/*/}"
SCRIPT_EXTENSION=$(ps -p "$$" -o comm=)
SCRIPT_EXTENSION="${SCRIPT_EXTENSION##*.}"

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

# Levels for comparing against LOG_LEVEL_STDOUT and LOG_LEVEL_LOG
LOG_LEVEL_TRACE=0
LOG_LEVEL_DEBUG=0
LOG_LEVEL_CUSTOM=0
LOG_LEVEL_INFO=1
LOG_LEVEL_SUCCESS=2
LOG_LEVEL_WARNING=3
LOG_LEVEL_ERROR=4
LOG_LEVEL_CUSTOM=5

# Formatting helper
# strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }
strip_ansi() { sed "s/[[:cntrl:]]\[[0-9;]*m//g" ;}

# Arithmetic helper functions
is_int()  { case "$1" in '' | *[!0-9]*) return 1;; esac ;}
in_range() { is_int "$1" && [ "$1" -le 256 ] && return 0 ;}

# String helper functions
repeat_char() {
	unset char count endline
	char=$1; count=$2; endline=$3
	is_int $count || return 1 
	while [ "$count" -gt 0 ]; do
		printf "%s" "$char"
		count=$((count - 1))
	done
	[ -n "$endline" ] && printf "$endline"
}

# Usage: offset=$(find_substring_offset "search" "input" "index")
find_substring_offset() {
	unset search input index
	search=$1; input=$2; index=${3:-1}
	
	while [ -n "$input" ]; do
		case "$input" in
			"$search"*) printf "%s\n" "$index"; return 0 ;;
			?*) input=${input#?}; index=$((index + 1)) ;;
		esac
	done

	#printf "ERROR: No match found for '%s' in '%s'\n" "$1" "$2" >&2
	return 1
}

# Usage: replaced_text=(replace_substring "find" "replace" "input")
replace_substring() { 
	unset find input replace output
	find=$1; replace=$2; input=$3
 
	# Temporarily disable globbing and set IFS to split on space
	set -f
	old_ifs=$IFS
	IFS=' '

	for word in $input; do
		if [ "$word" = "$find" ]; then
			output="${output:+$output }$replace"
		else
			output="${output:+$output }$word"
		fi
	done

  # Restore globbing and IFS
	IFS=$old_ifs
	set +f

	printf "%s\n" "$output"
	#printf "%s\n" "$output" >&2
}


LOG_OPTERR() {
	badopt=$1; func_call=$2; dmesg=$3
	#printf "%s\n%s\n%s\n\n" "$1" "$2" "$3"
	errmsg="ERROR: Unknown argument"
	dmesg_len=$(expr "x$dmesg" : 'x.*' - 1)
	badopt_len=$(expr "x$badopt" : 'x.*' - 1)
	position=$(find_substring_offset "$badopt" "$func_call" 1)
	ws=$(find_substring_offset " " "$badopt" 0) || ws=0
	z=$"*[[:space:]]*"
	case "$badopt" in
		$z)   offset=$((position + ws)); match_len=$((badopt_len = 1)) ;;
		-)	  offset=$((position + 0));  match_len=$((badopt_len = 1)) ;;
		--)	  offset=$((position + 0));  match_len=$((badopt_len = 2)) ;;
		---*) offset=$((position + 0));  match_len=$((badopt_len = 3)) ;;
		--*)  offset=$((position + 2));  match_len=$((badopt_len - 2)) ;;
		-*)	  offset=$((position + 1));  match_len=$((badopt_len - 1)) ;;
		*)	  offset=$((position + 0));  match_len=$((badopt_len - 0)) ;;
	esac
	output=$(replace_substring "$badopt" "′$badopt′" "$func_call")
	dmesg_offset=$((offset - dmesg_len + 2))
	

	#printf "Matched pattern '%s' at index: %d\n" "$badopt" "$offset"
	printf "%s\n> %s\n  " "$errmsg" "$output"
	repeat_char "~" "$offset"
	repeat_char "^" "$match_len" "\n"
	repeat_char " " "$dmesg_offset"
	printf "%s\n" "$dmesg"
	unset badopt func_call offset badopt_len position match ws
	return 1
}

print_log_vars() {
	echo
	echo "log_args: $log_args"
	echo "log_level: $log_level"
	echo "log_label: $log_label"
	echo "log_text: $log_text"
	echo "log_text_color: $log_text_color"
	echo "log_label_color: $log_label_color"
	echo "log_badopt: $log_badopt"
}

log_add_args() { log_args="${log_args:+$log_args }$1"; }
log_add_badopt() {
	log_add_args "$1"
	if [ -z "$log_badopt" ]; then
		log_badopt="$1"
		dmesg="$2"
	fi
}

log() {
	unset log_args log_level log_label log_text log_label_upper
	unset log_label_color log_text_color log_badopt
	unset text_flag label_flag dmesg LOG_TEXT_COLOR LOG_LABEL_COLOR
	

	# Parse args from log function call
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-t|-T|-l|-L)
				if is_int "$2" && ! in_range "$2"; then
					log_add_badopt "$2" "out of range"
				elif [ -z "$2" ]; then 
					log_add_badopt "$1 $2" "missing argument"
				elif [ -z "$text_flag" ]; then 
					log_add_args "$1"; text_flag=1
				elif [ -z "$label_flag" ]; then 
					log_add_args "$1"; label_flag=1
				else 
					log_add_badopt "$1" "similar flags"
				fi
				;;

			LOG_*_COLOR|[0-9]|[0-9][0-9]|[0-9][0-9][0-9])
				if [ -z "$log_label_color" ]; then 
					log_add_args "$1"; log_label_color=$1
				elif [ -z "$log_text_color" ]; then 
					log_add_args "$1"; log_text_color=$1
				else 
					log_add_badopt "$1" "too many colors"
				fi
				;;

			-*) log_add_badopt "$1" "invalid flag";;

			*)
				log_add_args "$1"
				if [ -z "$log_label" ]; then 
					log_label="$1"
				elif [ -z "$log_text" ]; then 
					log_text="$1"
				else 
					log_text="$log_text $1"
				fi
				;;
		esac
		shift
	done
	
	# Normalize colors 
	if [ "$text_flag" = "1" ] && [ "$label_flag" != "1" ]; then
		log_label_color="" # -t was used, -l was not
	elif [ "$label_flag" = "1" ] && [ "$text_flag" != "1" ]; then
		log_text_color="" # -l was used, -t was not
	elif [ -n "$log_label_color" ] && [ -z "$log_text_color" ]; then
		log_text_color="$log_label_color"
	elif [ -z "$log_label_color" ] && [ -n "$log_text_color" ]; then
		log_label_color="$log_text_color"
	fi	

	# Normalize input: log "hello" -> log INFO "hello"
	if [ -n "$log_label" ] && [ -z "$log_text" ]; then 
		log_text="$log_label"
		log_label="INFO"
	fi

	# Exit if we got parsing error 
	[ -n "$log_badopt" ] && \
		LOG_OPTERR "$log_badopt" "log $log_args" "$dmesg"

	# Default level to info
	[ -z "$log_level" ] && log_level="INFO"
	[ -z "$log_text_color" ] && log_text_color="LOG_INFO_COLOR"
	[ -z "$log_label_color" ] && log_label_color="LOG_INFO_COLOR"

	log_label_upper="$(printf "%s\n" "$log_label" | tr '[:lower:]' '[:upper:]')"
	
	# Extract the log_level from the label
	case "$log_label_upper" in
		DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE)
			 log_level="$log_label_upper"	;;
		*) 
			if [ "$USE_CUSTOM_LABELS" = "on" ]; then
				log_level="CUSTOM" 
			else
				log_level="INFO"
			fi
				;;
	esac
	case "$log_label_color" in
		*DEBUG*|*INFO*|*SUCCESS*|*WARNING*|*ERROR*|*TRACE*)	
			 eval "LOG_LABEL_COLOR="\$LOG_${log_level}_COLOR""	;;
		*) eval "LOG_LABEL_COLOR="\$(tput setaf $log_label_color)"" ;;
	esac
	case "$log_text_color" in
		*DEBUG*|*INFO*|*SUCCESS*|*WARNING*|*ERROR*|*TRACE*)
			 eval "LOG_TEXT_COLOR="\$LOG_${log_level}_COLOR""	;;
		*) eval "LOG_TEXT_COLOR="\$(tput setaf $log_text_color)"" ;;
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

	# This is where we format the different styles
	case "$LOG_FORMAT_PRESET" in	
		enhanced)
			if [ "$log_level" = "TRACE" ]; then
				log_prefix="[TRACE] >"
			else
				log_prefix=$(printf "[%s]%*s" "$log_label" $((9 - "${#log_label}" - 2)) "" )		
			fi
			;;
		standard) 
			log_prefix="[${log_label}]" ;;
		classic)  
			log_prefix="${log_label}:"  ;;
		*) 
			echo "Unknown style: $LOG_FORMAT_PRESET (use: symmetric|simple|classic)" ;;
	esac
	
	# Check LOG_LEVEL_STDOUT to see if this level of entry goes to STDOUT
	# XXX This is the horror that happens when your language doesn't have a hash data struct
	eval "log_level_int=\$LOG_LEVEL_\$$log_level";
	eval "log_level_stdout=\$LOG_LEVEL_\$$LOG_LEVEL_STDOUT";

	#print_log_vars
	if [ "$log_level_stdout" -le "$log_level_int" ]; then
		# STDOUT
		output="${LOG_LABEL_COLOR}[$(date +"%Y-%m-%d %H:%M:%S")] $log_prefix ${LOG_TEXT_COLOR}$log_text${LOG_DEFAULT_COLOR}"
		sleep .01
		printf "%s\n" "$output"
	fi

	eval log_level_log="\$LOG_LEVEL_${LOG_LEVEL_LOG}"
	
	# Check LOG_LEVEL_LOG to see if this level of entry goes to LOG_PATH
	if is_int "$log_level_log"; then
		if [ "$log_level_log" -le "$log_level_int" ]; then
			# LOG_PATH minus fancypants colors
			if [ ! -z $LOG_PATH ]; then
				printf "${LOG_DEFAULT_COLOR}[%s] %s %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "${log_text}" | strip_ansi >> "$LOG_PATH"
			fi
		fi
	fi
	return 0
}

case "$SCRIPT_EXTENSION" in
	sh)
		# Enable POSIX shell features
		log_info()    { log "INFO" "$1" "LOG_INFO_COLOR"				;}
		log_success() { log "SUCCESS" "$1" "LOG_SUCCESS_COLOR"	;}
		log_error()   { log "ERROR" "$1" "LOG_ERROR_COLOR"			;}
		log_warning() { log "WARNING" "$1" "LOG_WARNING_COLOR"	;}
		log_debug()   { log "DEBUG" "$1" "LOG_DEBUG_COLOR"			;}
		log_trace()   { log "TRACE" "$1" "LOG_TRACE_COLOR"			;}
		;;
	zsh)
		# Enable zsh-specific features
		log_info() {
			unset msg func_name
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "INFO" "$LOG_INFO_COLOR"
			log "INFO" "$msg" "$LOG_INFO_COLOR"
		}

		log_success() {
			unset msg func_name
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "SUCCESS" "$LOG_SUCCESS_COLOR"
			log SUCCESS "$msg" "$LOG_SUCCESS_COLOR"
		}

		log_error() {
			unset msg func_name
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "ERROR" "$LOG_ERROR_COLOR"
			log ERROR "$msg" "$LOG_ERROR_COLOR"
		}

		log_warning() {
			unset msg func_name
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "WARNING" "$LOG_WARNING_COLOR"
			log WARNING "$msg" "$LOG_WARNING_COLOR"
		}

		log_debug() {
			unset msg func_name
			local func_name="${funcstack[2]}"
			local msg=$1
			# log "$msg" "DEBUG" "$LOG_DEBUG_COLOR"
			log DEBUG "$msg" "$LOG_DEBUG_COLOR"
		}

		SCRIPTENTRY() {
			unset msg func_name
			local script_name=${funcstack[2]:-$SCRIPT_NAME}
			local msg=${1:+($1)}
			# log "> $script_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"
			log "TRACE" "$script_name:$LINENO "$msg"" "$LOG_TRACE_COLOR"
		} 

		SCRIPTEXIT() {
			unset msg func_name
			local script_name=${funcstack[2]:-$SCRIPT_NAME}
			local msg=${1:+($1)}
			# log "< $script_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"				
			log "TRACE" "$script_name:$LINENO "$msg"" "$LOG_TRACE_COLOR"				
		}

		trace_in() {
			unset msg func_name
			local func_name=${funcstack[2]:-$SCRIPT_NAME}
			local msg=${1:+($1)}
			# log "> $func_name:$LINENO "$msg"" "TRACE" "$LOG_TRACE_COLOR"				
			log "TRACE" "$func_name:$LINENO $msg" "$LOG_TRACE_COLOR"				
		}

		trace_out() {
			unset msg func_name
			local func_name=${funcstack[2]:-$SCRIPT_NAME}
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

