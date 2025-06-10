LOG_PRINT_USAGE() {
	cat <<EOF
Usage: ./your_script.sh [options]

Options:
  sh|zsh|bash             Set the script extension (affects \$SCRIPT_EXTENSION)
  -h, --help              Show this help message and exit

  -c, --config MODE       Set the log level mode (e.g., DEBUG, INFO, etc.)
  -f, --format STYLE      Set the log output format
                          Available: standard, enhanced, classic

  -o, --output PATH       Set the output log file path

  -log--level LEVEL       Set the minimum log level to log to file
                          Available: DEBUG, INFO, SUCCESS, WARNING, ERROR

  -stdout-level LEVEL     Set the minimum log level to print to stdout
                          Available: DEBUG, INFO, SUCCESS, WARNING, ERROR

Examples:
  ./your_script.sh bash -f symmetric -c DEBUG -o /tmp/log.txt
  ./your_script.sh --help

EOF
}

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
			if [ -z "$2" ]; then
				echo "Error: --config requires an argument" >&2
			fi

			LOG_LEVEL_MODE=$2
			shift 2
			;;

		-f|--format)
			if [ -z "$2" ]; then
				echo "Error: --config requires an argument" >&2
			fi

			LOG_PRESET_FORMAT=$2
			shift 2
			;;

		-o|--output)
			if [ -z "$2" ]; then
				echo "Error: --output requires an argument" >&2
			fi

			LOG_PATH=$2
			shift 2
			;;

		-log--level)
			if [ -z "$2" ]; then
				echo "Error: --log-level requires an argument" >&2
			fi

			LOG_LEVEL_LOG=$2
			shift 2
			;;

		-stdout-level)
			if [ -z "$2" ]; then
				echo "Error: --stdout-level requires an argument" >&2
			fi

			LOG_LEVEL_STDOUT=$2
			shift 2
			;;

		*) 
			echo "Unknown option: $1" >&2
			shift
			;;
	esac
done

