#!/usr/bin/env sh
# shlog - A POSIX-compliant logging tool
#
# Copyright (c) 2026 realgeorge
# Based on 'slog' by Fred Palmer (2009-2011) and Joe Cooper (2017)
# https://github.com/swelljoe/slog
#
# This source code is licensed under the MIT license

shopt -s expand_aliases 2>/dev/null || true
alias log_print='_log_print "$LINENO "'
opterr() { printf "ERROR: %s %s\n" "$1" "$2" >&2 && exit 1;}
require_arg() {
    [ "$#" -ge 2 ] || opterr "$1" "requires an argument."
    case "$2" in -*) opterr "$1" "invalid argument format." ;; esac
}
uppercase() { printf "%s\n" "$1" | tr '[:lower:]' '[:upper:]'; }
lowercase() { printf "%s\n" "$1" | tr '[:upper:]' '[:lower:]'; }
debug() {
    for _var in "$@"; do
        eval "val=\${$_var}" && printf "%s=%s\n" "$_var" "$val"
    done
}

# ---------------------------------------------------------------------------
# Parsing 
# ---------------------------------------------------------------------------
LOG_PRINT_USAGE() {
	cat <<-EOF
	Usage: source ./shlog.sh [options]

	Options:
	-h, --help                Show this help message and exit
	-o, --output              Set the output log file path
                          Same as \$LOG_PATH

	Styles:                   Available: enhanced, standard, classic
	-s, --style               Set the log output format, default is enhanced

	Logging levels:           Available: info, success, warning, error, debug
	-L, --log-level-default   Override global log levels, default is info
                          Same as \$LOG_LEVEL_DEFAULT
		--log-level-log           Set the minimum log level to log to file 
                          Same as \$LOG_LEVEL_LOG
		--log-level-stdout        Set the minimum log level to print to stdout 
                          Same as \$LOG_LEVEL_STDOUT
	EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            LOG_PRINT_USAGE
            exit 0
            ;;

        -o|--output)
            require_arg "$@"
            LOG_PATH="$2"
            shift 2
            ;;

        -s|--style)
            require_arg "$@"
            LOG_FORMAT_PRESET="$2"
            shift 2
            ;;

        --log-level-default)
            LOG_LEVEL_DEFAULT="$(uppercase "$2")"
            shift 2
            ;;

        --log-level-log)
            require_arg "$@"
            LOG_LEVEL_LOG="$(uppercase "$2")"
            shift 2
            ;;

        --log-level-stdout)
            require_arg "$@"
            LOG_LEVEL_STDOUT="$2"
            shift 2
            ;;

        *) 
            printf "%s\n" "Unknown option: $1" >&2
            shift
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Configuration Defaults
# ---------------------------------------------------------------------------
# Source the configuration and argument parsing script after setting 
# default values. This allows user-defined settings from config files or 
# command-line arguments to override the defaults initialized below.
#

# Formatting
case "${LOG_DATE_FORMAT:-default}" in
    default) log_date_format="%Y-%m-%d %H:%M:%S" ;;
    systemd) log_date_format="%m %d %H:%M:%S" ;;
    *) log_date_format="$LOG_DATE_FORMAT" ;;
esac
# Handle Style Preset fallback if LOG_FORMAT is unset
if [ -z "$LOG_FORMAT" ]; then
    case "${LOG_FORMAT_PRESET:-default}" in
        default)  LOG_FORMAT="%c1[%date] %c2[%label@] %c3%message" ;;
        *) printf "ERROR: Invalid LOG_FORMAT_PRESET\n" >&2 ;;
    esac
fi

SCRIPT_ARGS="$@"
SCRIPT_NAME="$0"
SCRIPT_NAME="${SCRIPT_NAME#\./}"
SCRIPT_NAME="${SCRIPT_NAME##/*/}"

# Prevent double sourcing
[ -n "$SHLOG_LOADED" ] && return 0 || SHLOG_LOADED=1
: "${LOG_PATH:=./shlog.log}"
: "${LOG_LEVEL_DEFAULT:=DEBUG}"
: "${LOG_LEVEL_STDOUT:=DEBUG}"
: "${LOG_LEVEL_LOG:=DEBUG}"
: "${LOG_FORMAT_PRESET:=default}"
: "${LOG_FMT_OFFSET_C0:=0}"
: "${LOG_FMT_OFFSET_C1:=0}"
: "${LOG_FMT_OFFSET_C2:=0}"
: "${LOG_FMT_OFFSET_C3:=0}"
: "${LOG_FMT_OFFSET_DATE:=0}"
: "${LOG_FMT_OFFSET_LABEL:=7}"
: "${LOG_FMT_OFFSET_MESSAGE:=0}"
: "${LOG_FMT_OFFSET_HOSTNAME:=0}"
: "${LOG_FMT_OFFSET_SCRIPTNAME:=${#SCRIPT_NAME}}"
: "${LOG_FMT_OFFSET_LINENO:=0}"
: "${LOG_FMT_OFFSET_OTHER:=0}"
if [ -z "$LOG_SYM_DISABLE" ]; then
    : "${LOG_SYM_ENTRY:=>}"
    : "${LOG_SYM_TRACE_IN:=>}"
    : "${LOG_SYM_TRACE:=~}"
    : "${LOG_SYM_TRACE_OUT:=<}"
    : "${LOG_SYM_EXIT:=<}"
    : "${LOG_SYM_INFO:=}"
    : "${LOG_SYM_SUCCESS:=}"
    : "${LOG_SYM_WARNING:=}"
    : "${LOG_SYM_ERROR:=}"
    : "${LOG_SYM_DEBUG:=}"
fi

# ---------------------------------------------------------------------------
# Levels for comparing against LOG_LEVEL_STDOUT and LOG_LEVEL_LOG
# (Higher number = Higher priority)
# ---------------------------------------------------------------------------
LOG_LEVEL_DEBUG=0
LOG_LEVEL_TRACE=0
LOG_LEVEL_INFO=1
LOG_LEVEL_SUCCESS=2
LOG_LEVEL_WARNING=3
LOG_LEVEL_ERROR=4
LOG_LEVEL_CUSTOM=5

# ---------------------------------------------------------------------------
# Color Definitions
# -------------------------------------------------------------------
if [ "${INTERACTIVE_MODE}" = "off" ]
then
    # We don't care about log colors
    LOG_DEFAULT_COLOR=""
    LOG_INFO_COLOR=""
    LOG_SUCCESS_COLOR=""
    LOG_WARNING_COLOR=""
    LOG_ERROR_COLOR=""
    LOG_DEBUG_COLOR=""
    LOG_TRACE_COLOR=""
    LOG_CUSTOM_COLOR=""
else
    LOG_DEFAULT_COLOR="$(tput sgr0)"
    LOG_INFO_COLOR="$(tput sgr0)"
    LOG_SUCCESS_COLOR="$(tput setaf 2)"
    LOG_WARNING_COLOR="$(tput setaf 3)"
    LOG_ERROR_COLOR="$(tput setaf 1)"
    LOG_DEBUG_COLOR="$(tput setaf 4)"
    LOG_TRACE_COLOR="$(tput setaf 8)"
    LOG_CUSTOM_COLOR="${LOG_CUSTOM_COLOR:-$(tput setaf 69)}"
fi

# These are used to print the correct colors to STDOUT.
LOG_TEXT_COLOR=
LOG_LABEL_COLOR=

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
strip_ansi() { sed "s/[[:cntrl:]]\[[0-9;]*m//g" ;}
is_int()  { case "$1" in '' | *[!0-9]*) return 1;; esac ;} 

validate_color() {
    case "$1" in
        # Check if valid color
        LOG_DEBUG_COLOR | LOG_INFO_COLOR | LOG_SUCCESS_COLOR | LOG_WARNING_COLOR | LOG_ERROR_COLOR | LOG_TRACE_COLOR | LOG_CUSTOM_COLOR)
            return 0 
            ;;
        '' | *[!0-9]*) 
            return 1 
            ;;
        *) 
            [ "$1" -le 256 ] || return 1 
            ;;
    esac
    return 0
}

# Available options date, label, message, hostname, script, line
process_color() {
    _target_var="$1"
    _input_color="$2"
    # Normalize colors
    [ -n "$log_color" ] && _input_color="$log_color"
    # Apply default if unset or empty
    : "${_input_color:=LOG_INFO_COLOR}"
    # Validate
    validate_color "$_input_color" || _input_color="LOG_INFO_COLOR"
    # Assign output
    case "$_input_color" in
        *DEBUG* | *INFO* | *SUCCESS* | *WARNING* | *ERROR* | *TRACE*)
            eval "$_target_var=\"\$LOG_${log_level}_COLOR\"" ;;
        *)
            eval "$_target_var=\"\$(tput setaf \"$_input_color\")\"" ;;
    esac
    unset _target_var _input_color
}

level_to_int() {
    case "$1" in
    DEBUG | TRACE) echo 0 ;;
    INFO )        echo 1 ;;
    SUCCESS )     echo 2 ;;
    WARNING )     echo 3 ;;
    ERROR )       echo 4 ;;
    CUSTOM )      echo 5 ;;
    *)            echo 1 ;;
    esac
}

_get_val() {
    case "$1" in
        c0*) _val="$LOG_DEFAULT_COLOR" ;;
        c1*) _val="$LOG_DATE_COLOR" ;;
        c2*) _val="$LOG_LABEL_COLOR" ;;
        c3*) _val="$LOG_TEXT_COLOR" ;;
        date*) _val="$(date +"$log_date_format")" ;;
        label*) _val="$log_label" ;;
        message*) _val="$log_text" ;;
        hostname*) _val="$HOSTNAME" ;;
        scriptname*) _val="$SCRIPT_NAME" ;;
        lineno*) _val="$_caller_lineno" ;;
        {*) 
            _raw="${1#?}"      # Safely strip the first character '{'
            _val="${_raw%?}"   # Safely strip the last character '}'
            ;;
        \(*) 
            _cmd="${1#?}"      # Safely strip the first character '('
            _val="$(eval "${_cmd%?}")"  # Safely strip the last character ')' and execute
            return 1
            ;;
        *) _val="%$1" 
            return 1
            ;;       # Restore the % for invalid/unrecognized options
    esac
    return 0
}

_log_print() {
    _caller_lineno="$1"
    _fmt="$2"
    _out=""
    shift 2
    
    # Define literal space and tab to bypass shell-specific character class bugs
    _sp=" "
    _tb="	"

    # Clear positional parameters to build the printf argument list
    set --

    while case "$_fmt" in *%*) true ;; *) false ;; esac; do
        _before="${_fmt%%\%*}"
        _after_percent="${_fmt#*\%}"

        # 1. Safely extract _opt, accommodating braces and parentheses
        case "$_after_percent" in
            {*) _opt="${_after_percent%%\}*}" ; _opt="${_opt}}" ;;
            \(*) _opt="${_after_percent%%\)*}" ; _opt="${_opt})" ;;
            *)   _opt="${_after_percent%%[!a-zA-Z0-9_]*}" ;;
        esac

        # 2. Identify the string immediately following the extracted option
        _remainder_after_opt="${_after_percent#"$_opt"}"

        # 3. Detect mode: Does the string immediately following the option start with '@'?
        case "$_remainder_after_opt" in
            @*) _fmt_mode="align" ;;
            *)  _fmt_mode="normal" ;;
        esac

        if [ "$_fmt_mode" = "normal" ]; then
            _prefix="$_before"                               # 4. Literal text before the %
            _out="${_out}${_prefix}%s"                       # 5. Append literal text to _out followed by %s
            _get_val "$_opt"                                 # 6. Resolve value
            _fmt="$_remainder_after_opt"                     # 7. Advance the string past the option
            set -- "$@" "$_val"                              # 8. Append to printf arguments
        else
            _opt_prefix="${_before##*[$_sp$_tb]}"            # 4. Non-whitespace chars on the left (strict extraction)
            _prefix="${_before%"$_opt_prefix"}"              # 5. Isolate preceding literal text
            _get_val "$_opt"                                 # 6. Resolve value
            _after_at="${_remainder_after_opt#@}"            # 7. Strip the strictly identified '@' symbol
            _right_part="${_after_at%%[$_sp$_tb%]*}"         # 8. Extract suffix, stopping at whitespace or next %
            _offset="${_right_part%%[!0-9-]*}"               # 9. Numeric padding offset
            _opt_suffix="${_right_part#"$_offset"}"          # 10. Remaining suffix wrapper
            _opt_glued="${_opt_prefix}${_val}${_opt_suffix}" # 11. Reconstruct aligned string
            
            # 12. Calculate dynamic padding offset
            _wrap_len=0

            _is_valid=$?
            # Apply dynamic offset only if not provided AND option is valid
            if [ -z "$_offset" ] && [ "$_is_valid" -eq 0 ]; then
                _wrap_len=$((${#_opt_prefix} + ${#_opt_suffix}))
                _safe_opt=$(uppercase "$_opt")
                eval "_offset=\$(( -\${LOG_FMT_OFFSET_${_safe_opt}:-0} ))"
                [ "$log_level" = "TRACE" ] && _wrap_len="$((_wrap_len-2))"
            fi
            
            case "$_opt" in 
                {*}|\(*\)) _wrap_len=-2 ;;
            esac

            case "$_offset" in
                -*) _offset="-$(( ${_offset#-} + _wrap_len ))" ;;
                *[0-9]*) _offset="$(( _offset + _wrap_len ))" ;;
            esac

            _out="${_out}${_prefix}%${_offset}s"             # 13. Inject padding
            _fmt="${_after_at#"$_right_part"}"               # 14. Advance the string
            set -- "$@" "$_opt_glued"                        # 15. Append to printf arguments
        fi
    done

    # Append any remaining literal text after the final variable
    _out="${_out}${_fmt}${LOG_DEFAULT_COLOR}"
    _opts="$@"

    # Output the fully resolved format string
    printf "$_out\n" "$@"
    # debug _out
}

# ---------------------------------------------------------------------------
# Begin logging section
# ---------------------------------------------------------------------------
# Detect which shell is running
case "${ZSH_VERSION:+zsh}:${BASH_VERSION:+bash}" in
    zsh:*)  SCRIPT_EXTENSION="zsh"  ;;
    *:bash) SCRIPT_EXTENSION="bash" ;;
    *)      SCRIPT_EXTENSION="sh"   ;;
esac
# Determines if we print color or not
if ! tty -s; then
    readonly INTERACTIVE_MODE="off"
else
    readonly INTERACTIVE_MODE="on"
fi

log() {
    OPTIND=1

    # Clear variables 
    unset log_label log_text log_label_color log_text_color log_level log_color log_date_color
    unset _last_arg opt LOG_TEXT_COLOR LOG_LABEL_COLOR LOG_DATE_COLOR _cFlag
    
    while getopts "D:L:T:c:" opt; do
        case "$opt" in
            D) log_date_color="$OPTARG";  _cFlag=1 ;;
            L) log_label_color="$OPTARG"; _cFlag=1 ;;
            T) log_text_color="$OPTARG";  _cFlag=1 ;;
            c) log_color="$OPTARG";       _cFlag=1 ;;
            *) 
                printf "ERROR: Invalid option: log \`%s\` \n" "$opt" >&2
                return 1
                ;;
        esac
    done
    
    shift $((OPTIND - 1))

    # If more than 2 args are provided to the log function, we always assume that 
    # the last argument is a color. This is bypassed by setting any color flag
    case "$#" in
        0)  printf "WARNING: No message\n" >&2 ;;
        1)  log_label="INFO"; log_text="$1" ;;
        2)  log_label="$1";   log_text="$2" ;;
        *)
            log_label="$1"; shift 
            log_text="$*"
            if [ -z "$_cFlag" ]; then
                eval "_last_arg=\${$#}"
                log_color="$_last_arg"
                log_text="${log_text% $_last_arg}"
            fi
            ;;
    esac

    log_label_upper="$(uppercase "$log_label")"

    # Extract the log level from the label
    case "$log_label_upper" in
        DEBUG | INFO | SUCCESS | WARNING | ERROR)
            log_level="$log_label_upper"	;;
        ENTRY | EXIT | TRACE* )
            log_level="TRACE"   ;;
        *)  
            log_level="CUSTOM"  ;;
    esac

    # Process (normalize/apply) colors
    process_color LOG_DATE_COLOR  "$log_date_color"
    process_color LOG_LABEL_COLOR "$log_label_color"
    process_color LOG_TEXT_COLOR  "$log_text_color"

    # Validate levels since they'll be eval-ed
    case "$LOG_LEVEL_STDOUT" in
        DEBUG | INFO | SUCCESS | WARNING | ERROR | TRACE | CUSTOM ) ;;
        *) LOG_LEVEL_STDOUT=INFO ;;
    esac
    case "$LOG_LEVEL_LOG" in
        DEBUG | INFO | SUCCESS | WARNING | ERROR | TRACE | CUSTOM ) ;;
        *) LOG_LEVEL_LOG=INFO ;;
    esac

    # Check priorities
    log_level_int=$(level_to_int "$log_level")
    log_level_stdout=$(level_to_int "$LOG_LEVEL_STDOUT")
    log_level_log=$(level_to_int "$LOG_LEVEL_LOG")

    # Print to STDOUT
    if [ "$log_level_stdout" -le "$log_level_int" ]; then
        log_print "$LOG_FORMAT"
    fi

    # Check LOG_LEVEL_LOG to see if this level of entry goes to LOG_PATH
    if is_int "$log_level_log"; then
        if [ "$log_level_log" -le "$log_level_int" ]; then
            # Write to LOG_PATH without fancy colors
            if [ -n "$LOG_PATH" ]; then
                log_print "$LOG_FORMAT" | strip_ansi >> "$LOG_PATH"
            fi
        fi
    fi
    return 0
}

# Enable POSIX shell features
log_info()    { log "INFO"    "$@" "LOG_INFO_COLOR"    ;}
log_success() { log "SUCCESS" "$@" "LOG_SUCCESS_COLOR" ;}
log_error()   { log "ERROR"   "$@" "LOG_ERROR_COLOR"   ;}
log_warning() { log "WARNING" "$@" "LOG_WARNING_COLOR" ;}
log_debug()   { log "DEBUG"   "$@" "LOG_DEBUG_COLOR"   ;}
log_trace()   { log "TRACE"   "$@" "LOG_TRACE_COLOR"   ;}

case "$SCRIPT_EXTENSION" in
sh)
        log_trace() {
            func_name="$1"; shift
            msg="$*"
            log "TRACE" "${LOG_SYM_TRACE:+${LOG_SYM_TRACE} }$func_name: $msg" "LOG_TRACE_COLOR"
        }
        log_trace_in() { 
            func_name="$1"; shift
            msg="$*"
            log "TRACE_IN" "${LOG_SYM_TRACE_IN:+${LOG_SYM_TRACE_IN} }$func_name: $msg" "LOG_TRACE_COLOR"
        }
        log_trace_out() { 
            func_name="$1"; shift
            msg="$*"
            log "TRACE_OUT" "${LOG_SYM_TRACE_OUT:+${LOG_SYM_TRACE_OUT} }$func_name: $msg" "LOG_TRACE_COLOR"
        }
        ;;
 zsh)
        # Enable bash-compatible logging functions
        eval '
        SCRIPTENTRY() {
            emulate -L zsh
            local caller_file="${${funcfiletrace[1]%:*}:t}"
            local caller_line="${functrace[1]##*:}"
            log "ENTRY" "${LOG_SYM_ENTRY:+${LOG_SYM_ENTRY} }$caller_file:$caller_line $*" "LOG_TRACE_COLOR"
        } 

        SCRIPTEXIT() {
            emulate -L zsh
            local caller_file="${${funcfiletrace[1]%:*}:t}"
            local caller_line="${functrace[1]##*:}"
            log "EXIT" "${LOG_SYM_EXIT:+${LOG_SYM_EXIT} }$caller_file:$caller_line $*" "LOG_TRACE_COLOR"
        }

        log_trace() {
            emulate -L zsh
            local caller_file="${${funcfiletrace[1]%:*}:t}"
            local c_func="${funcstack[2]:-${functrace[1]%:*}}"
            local caller_func="${c_func:-${SCRIPT_NAME:-main}}"
            caller_func="${caller_func#./}"
            local c_line="${functrace[1]##*:}"
            local caller_line="${c_line:-$LINENO}"
            log "TRACE" "${LOG_SYM_TRACE:+${LOG_SYM_TRACE} }$caller_file:$caller_func:$caller_line $*" "LOG_TRACE_COLOR"
        }

        log_trace_in() {
            emulate -L zsh
            local caller_file="${${funcfiletrace[1]%:*}:t}"
            local c_func="${funcstack[2]:-${functrace[1]%:*}}"
            local caller_func="${c_func:-${SCRIPT_NAME:-main}}"
            caller_func="${caller_func#./}"
            local c_line="${functrace[1]##*:}"
            local caller_line="${c_line:-$LINENO}"
            log "TRACE" "${LOG_SYM_TRACE_IN:+${LOG_SYM_TRACE_IN} }$caller_file:$caller_func:$caller_line $*" "LOG_TRACE_COLOR"                
        }

        log_trace_out() {
            emulate -L zsh
            local caller_file="${${funcfiletrace[1]%:*}:t}"
            local c_func="${funcstack[2]:-${functrace[1]%:*}}"
            local caller_func="${c_func:-${SCRIPT_NAME:-main}}"
            caller_func="${caller_func#./}"
            local c_line="${functrace[1]##*:}"
            local caller_line="${c_line:-$LINENO}"
            log "TRACE" "${LOG_SYM_TRACE_OUT:+${LOG_SYM_TRACE_OUT} }$caller_file:$caller_func:$caller_line $*" "LOG_TRACE_COLOR"                
        }
        '
        ;;

    bash)
        eval '
        # Enable bash-compatible logging functions
        SCRIPTENTRY() {
            local caller_file="${BASH_SOURCE[1]##*/}"
            local caller_line="${BASH_LINENO[0]:-$LINENO}"
            log "ENTRY" "${LOG_SYM_ENTRY:+${LOG_SYM_ENTRY} }$caller_file:$caller_line $*" "LOG_TRACE_COLOR"
        }

        SCRIPTEXIT() {
            local caller_file="${BASH_SOURCE[1]##*/}"
            local caller_line="${BASH_LINENO[0]:-$LINENO}"
            log "EXIT" "${LOG_SYM_EXIT:+${LOG_SYM_EXIT} }$caller_file:$caller_line $*" "LOG_TRACE_COLOR"
        }

        log_trace() {
            local caller_file="${BASH_SOURCE[1]##*/}"
            local c_func="${FUNCNAME[1]}"
            local caller_func="${c_func:-${SCRIPT_NAME:-main}}"
            caller_func="${caller_func#./}"
            local caller_line="${BASH_LINENO[0]:-$LINENO}"
            log "TRACE" "${LOG_SYM_TRACE:+${LOG_SYM_TRACE} }$caller_file:$caller_func:$caller_line $*" "LOG_TRACE_COLOR"
        }

        log_trace_in() {
            local caller_file="${BASH_SOURCE[1]##*/}"
            local c_func="${FUNCNAME[1]}"
            local caller_func="${c_func:-${SCRIPT_NAME:-main}}"
            caller_func="${caller_func#./}"
            local caller_line="${BASH_LINENO[0]:-$LINENO}"
            log "TRACE" "${LOG_SYM_TRACE_IN:+${LOG_SYM_TRACE_IN} }$caller_file:$caller_func:$caller_line $*" "LOG_TRACE_COLOR"
        }

        log_trace_out() {
            local caller_file="${BASH_SOURCE[1]##*/}"
            local c_func="${FUNCNAME[1]}"
            local caller_func="${c_func:-${SCRIPT_NAME:-main}}"
            caller_func="${caller_func#./}"
            local caller_line="${BASH_LINENO[0]:-$LINENO}"
            log "TRACE" "${LOG_SYM_TRACE_OUT:+${LOG_SYM_TRACE_OUT} }$caller_file:$caller_func:$caller_line $*" "LOG_TRACE_COLOR"
        }
        '
        ;;
    *)
        printf "ERROR: Filetype %s incompatible\n" "$SCRIPT_EXTENSION" >&2
        return 1
        ;;
esac
