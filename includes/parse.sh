#!/usr/bin/env sh

# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

# TODO: Add config related args
SHLOG_USAGE() {
    cat <<-EOF
    Usage: source ./shlog.sh [options]

    Options:
    -h, --help                Show this help message and exit
    -c, --load-config         Load config (relative to shlog.sh)
    -o, --output              Set the output log file path
                              Same as \$LOG_PATH

    Formatting:               Available: (normal, align, json, systemd)
    *** Explaination of the format string logic goes here ***
    -f, --format              Sets the global format
                              Same as \$LOG_FORMAT
        --format-log          Sets the global log format
                              Same as \$LOG_FORMAT_LOG
        --format-stdout       Sets the global stdout format
                              Same as \$LOG_FORMAT_STDOUT
        --format-date         Sets the global date string (default is "%Y-%m-%d %H:%M:%S")
                              Same as \$LOG_FORMAT_DATE

    
    Styles:                   Available: (normal, align, json, systemd)
    *** This should only change the LOG_FMT options ***
    -s, --style               Sets the global output style (format and config)
                              Same as \$LOG_PRESET
        --style-log           Sets the global log style (format and config)
                              Same as \$_LOG_PRESET_STDOUT
        --style-stdout        Sets the global stdout style (format and config)
                              Same as \$_LOG_PRESET_LOG

    Logging levels:           Available: info, success, warning, error, debug
    -L, --log-level-default   Override global log levels, default is info
                              Same as \$LOG_LEVEL_DEFAULT
        --log-level-log       Set the minimum log level to log to file 
                              Same as \$LOG_LEVEL_LOG
        --log-level-stdout    Set the minimum log level to print to stdout 
                              Same as \$LOG_LEVEL_STDOUT
    
    *** If no configuration is detected rich style is automatically applied. ***
    *** Write docs on LOG_FMT options ***
	EOF
}

opterr() { printf "ERROR: '%s' %s\n" "$1" "$2" >&2 && exit 1; }
require_arg() { [ $# -gt 1 ] && [ "${2#-}" = "$2" ] || opterr "$1" "invalid"; }

SHLOG_INIT() {

    # 1. Parse Arguments
    while [ $# -gt 0 ]; do
        case "$1" in
        -h | --help)
            SHLOG_USAGE
            exit 0
            ;;

        # --- Configuration ---
        -c | --load-config)
            require_arg "$@"
            LOAD_CONFIG "$2"
            shift 2
            ;;

        -o | --output)
            require_arg "$@"
            LOG_PATH="$2"
            shift 2
            ;;

        # --- Formatting (Strings) ---
        -f | --format)
            require_arg "$@"
            LOG_FORMAT="$2"
            shift 2
            ;;
        --format-log)
            require_arg "$@"
            LOG_FORMAT_LOG="$2"
            shift 2
            ;;
        --format-stdout)
            require_arg "$@"
            LOG_FORMAT_STDOUT="$2"
            shift 2
            ;;
        --format-date)
            require_arg "$@"
            LOG_DATE_FORMAT="$2"
            shift 2
            ;;

        # --- Styles (Presets) ---
        -s | --style)
            require_arg "$@"
            LOG_PRESET="$2"
            shift 2
            ;;
        --style-log)
            require_arg "$@"
            LOG_PRESET_LOG="$2"
            shift 2
            ;;
        --style-stdout)
            require_arg "$@"
            LOG_PRESET_STDOUT="$2"
            shift 2
            ;;

        # --- Levels ---
        -L | --log-level-default)
            require_arg "$@"
            LOG_LEVEL="$(set_case upper "$2")"
            shift 2
            ;;
        --log-level-log)
            require_arg "$@"
            LOG_LEVEL_LOG="$(set_case upper "$2")"
            shift 2
            ;;
        --log-level-stdout)
            require_arg "$@"
            LOG_LEVEL_STDOUT="$(set_case upper "$2")"
            shift 2
            ;;

        *)
            printf "Error: Unknown option \`%s\`\n" "$1" >&2
            SHLOG_USAGE
            exit 1
            ;;
        esac
    done
}
