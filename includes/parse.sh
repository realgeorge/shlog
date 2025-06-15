#!/bin/sh

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

# Fallback if no config file/dir is provided
: ${LOG_CONFIG_FILE:-$LOG_CONFIG_AUTO_LOCATION/shlog.conf}

if [ "$LOG_LOAD_CONFIG" = "true" ]; then
	[ -f "$LOG_CONFIG_FILE" ] && LOAD_CONFIG "$LOG_CONFIG_FILE" ||
	[ -f "$LOG_CONFIG_FILE/config/shlog.conf" ] && LOAD_CONFIG "$LOG_CONFIG_FILE/config/shlog.conf"
fi

if [ "$LOG_SAVE_CONFIG" = "true" ]; then 
	SAVE_CONFIG; 
fi

