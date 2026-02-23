#!/usr/bin/env sh

# shlog - A POSIX-compliant logging tool
#
# Copyright (c) 2026 realgeorge
# Based on 'slog' by Fred Palmer (2009-2011) and Joe Cooper (2017)
# https://github.com/swelljoe/slog
#
# This source code is licensed under the MIT license

if [ -n "$SHLOG_LOADED" ]; then
    return 0
else
    SHLOG_LOADED=1
fi

# ---------------------------------------------------------------------------
# Configuration Defaults
# ---------------------------------------------------------------------------
# Source the configuration and argument parsing script after setting
# default values. This allows user-defined settings from config files or
# command-line arguments to override the defaults initialized below.

# Formatting
case "${LOG_DATE_FORMAT:-default}" in
default) log_date_format="%Y-%m-%d %H:%M:%S" ;;
systemd) log_date_format="%m %d %H:%M:%S" ;;
*) log_date_format="$LOG_DATE_FORMAT" ;;
esac

# Handle Style Preset fallback if LOG_FORMAT is unset
# TODO: Add LOG_FORMAT for diffrent levels
if [ -z "$LOG_FORMAT" ]; then
    case "${LOG_FMT_PRESET:-default}" in
    default)
        : ${LOG_FMT_SYM_ENABLE:=1}
        : ${LOG_FMT_SYM_ENTRY:=> }
        : ${LOG_FMT_SYM_TRACE_IN:=> }
        : ${LOG_FMT_SYM_TRACE:=~ }
        : ${LOG_FMT_SYM_TRACE_OUT:=< }
        : ${LOG_FMT_SYM_EXIT:=< }
        LOG_FORMAT="[%date] [%label@] %sym%message"
        ;;
    *)
        printf "ERROR: Invalid LOG_FMT_PRESET\n" >&2
        ;;
    esac
fi

SCRIPT_ARGS="$@"
SCRIPT_NAME="$0"
SCRIPT_NAME="${SCRIPT_NAME#\./}"
SCRIPT_NAME="${SCRIPT_NAME##/*/}"

: ${LOG_MAX_SIZE:=1048576} # Maxstorlek i bytes (1 MB)
: ${LOG_MAX_FILES:=5}      # Antal roterade filer att spara

# Prevent double sourcing
: ${LOG_PATH:=./shlog.log}
: ${LOG_LEVEL_DEFAULT:=DEBUG}
: ${LOG_LEVEL_STDOUT:=DEBUG}
: ${LOG_LEVEL_LOG:=DEBUG}
: ${LOG_FMT_PRESET:=default}
: ${LOG_FMT_OFFSET_DATE:=0}
: ${LOG_FMT_OFFSET_LABEL:=7}
: ${LOG_FMT_OFFSET_MESSAGE:=0}
: ${LOG_FMT_OFFSET_HOSTNAME:=${#HOSTNAME}}
: ${LOG_FMT_OFFSET_SCRIPTNAME:=${#SCRIPT_NAME}}
: ${LOG_FMT_OFFSET_LINENO:=0}
: ${LOG_FMT_SYM_ENTRY:=}
: ${LOG_FMT_SYM_TRACE_IN:=}
: ${LOG_FMT_SYM_TRACE:=}
: ${LOG_FMT_SYM_TRACE_OUT:=}
: ${LOG_FMT_SYM_EXIT:=}
: ${LOG_FMT_SYM_INFO:=}
: ${LOG_FMT_SYM_SUCCESS:=}
: ${LOG_FMT_SYM_WARNING:=}
: ${LOG_FMT_SYM_ERROR:=}
: ${LOG_FMT_SYM_DEBUG:=}
: ${LOG_FMT_SYM_CUSTOM:=}

# ---------------------------------------------------------------------------
# Levels for comparing against _lvl_stdout and _lvl_log
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
if [ {$INTERACTIVE_MODE} = "off" ]; then

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
    : ${LOG_CUSTOM_COLOR:-$(tput setaf 69)}
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

is_int() { case "${1#-}" in '' | *[!0-9]*) return 1 ;; esac }
is_uint() { case "$1" in '' | *[!0-9]*) return 1 ;; esac }

strip_ansi() {
    _esc=$(printf '\033')
    while IFS= read -r _line; do
        # Only process if both the ESC[ and the closing 'm' exist
        while case "$_line" in *"$_esc"\[*m*) true ;; *) false ;; esac do
            _before="${_line%"$_esc"\[*}"    # 1. Grab everything before the LAST escape sequence
            _remainder="${_line#"$_before"}" # 2. Isolate the escape sequence and the rest of the string
            _after="${_remainder#*m}"        # 3. Strip the escape sequence by dropping everything up to the first 'm'
            _line="${_before}${_after}"      # 4. Reconstruct the string and repeat
        done
        printf "%s\n" "$_line"
    done
}

set_case() {
    _case=$1
    _str=$2
    _out=""

    while [ -n "$_str" ]; do
        _char="${_str%"${_str#?}"}"
        _str="${_str#?}"

        if [ "$_case" = "lower" ]; then
            case "$_char" in
            A) _char=a ;; B) _char=b ;; C) _char=c ;; D) _char=d ;; E) _char=e ;;
            F) _char=f ;; G) _char=g ;; H) _char=h ;; I) _char=i ;; J) _char=j ;;
            K) _char=k ;; L) _char=l ;; M) _char=m ;; N) _char=n ;; O) _char=o ;;
            P) _char=p ;; Q) _char=q ;; R) _char=r ;; S) _char=s ;; T) _char=t ;;
            U) _char=u ;; V) _char=v ;; W) _char=w ;; X) _char=x ;; Y) _char=y ;;
            Z) _char=z ;; Å) _char=å ;; Ä) _char=ä ;; Ö) _char=ö ;;
            esac
        elif [ "$_case" = "upper" ]; then
            case "$_char" in
            a) _char=A ;; b) _char=B ;; c) _char=C ;; d) _char=D ;; e) _char=E ;;
            f) _char=F ;; g) _char=G ;; h) _char=H ;; i) _char=I ;; j) _char=J ;;
            k) _char=K ;; l) _char=L ;; m) _char=M ;; n) _char=N ;; o) _char=O ;;
            p) _char=P ;; q) _char=Q ;; r) _char=R ;; s) _char=S ;; t) _char=T ;;
            u) _char=U ;; v) _char=V ;; w) _char=W ;; x) _char=X ;; y) _char=Y ;;
            z) _char=Z ;; å) _char=Å ;; ä) _char=Ä ;; ö) _char=Ö ;;
            esac
        fi

        _out="${_out}${_char}"
    done

    printf "%s\n" "$_out"
}

debug() {
    for _var in "$@"; do
        eval "val=\${$_var}" && printf "%s=%s\n" "$_var" "$val"
    done
}

level_to_int() {
    case "$1" in
    DEBUG | TRACE) echo 0 ;;
    INFO) echo 1 ;;
    SUCCESS) echo 2 ;;
    WARNING) echo 3 ;;
    ERROR) echo 4 ;;
    CUSTOM) echo 5 ;;
    *) echo 1 ;;
    esac
}

_get_val() {
    case "$1" in
    c0*) _val="$LOG_DEFAULT_COLOR" ;;
    date*) _val="$(date +"$log_date_format")" ;;
    label*) _val="$_lbl" ;;
    message*) _val="$_msg" ;;
    hostname*) _val="$HOSTNAME" ;;
    scriptname*) _val="$SCRIPT_NAME" ;;
    lineno*) _val="$_caller_lineno" ;;
    sym*) _val="$_sym" ;;
    c[1-9]* | c[1-9][0-9]* | c[1-2][0-9][0-9]*)
        _color_code="${1#c}"
        if [ "$_color_code" -le 255 ]; then
            _val="$(tput setaf $_color_code)"
        else
            _val="%$1"
            return 1
        fi
        ;;

    {*)
        _raw="${1#?}"    # Safely strip the first character '{'
        _val="${_raw%?}" # Safely strip the last character '}'
        ;;
    \(*)
        _cmd="${1#?}"              # Safely strip the first character '('
        _val="$(eval "${_cmd%?}")" # Safely strip the last character ')' and execute
        return 1
        ;;
    *)
        _val="%$1"
        return 1
        ;; # Restore the % for invalid/unrecognized options
    esac
    return 0
}

# Available options date, label, message, hostname, script, line
_log_print() {
    _fmt=$1
    _out="$_color"

    # Define literal space and tab to bypass shell-specific character class bugs
    _sp=" "
    _tb="	"

    # Clear positional parameters to build the printf argument list
    set --

    while case "$_fmt" in *%*) true ;; *) false ;; esac do
        _before="${_fmt%%\%*}"
        _after_percent="${_fmt#*\%}"

        # 1. Safely extract _opt, accommodating braces and parentheses
        case "$_after_percent" in
        {*)
            _opt="${_after_percent%%\}*}"
            _opt="${_opt}}"
            ;;
        \(*)
            _opt="${_after_percent%%\)*}"
            _opt="${_opt})"
            ;;
        *) _opt="${_after_percent%%[!a-zA-Z0-9_]*}" ;;
        esac

        # 2. Identify the string immediately following the extracted option
        _remainder_after_opt="${_after_percent#"$_opt"}"

        # 3. Detect mode: Does the string immediately following the option start with '@'?
        case "$_remainder_after_opt" in
        @*) _fmt_mode="align" ;;
        *) _fmt_mode="normal" ;;
        esac

        if [ "$_fmt_mode" = "normal" ]; then
            _prefix="$_before"           # 4. Literal text before the %
            _out="${_out}${_prefix}%s"   # 5. Append literal text to _out followed by %s
            _get_val "$_opt"             # 6. Resolve value
            _fmt="$_remainder_after_opt" # 7. Advance the string past the option
            set -- "$@" "$_val"          # 8. Append to printf arguments
        else
            # Reject alignment on color variables
            case "$_opt" in
            c0 | cd | cl | cm | c[1-9]*)
                printf "ERROR: Alignment cannot be applied to color tags (%%%s@)\n" "$_opt" >&2
                return 1
                ;;
            esac
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
                _safe_opt=$(set_case "upper" "$_opt")
                eval "_offset=\$(( -\${LOG_FMT_OFFSET_${_safe_opt}:-0} ))"
                [ "$_lvl" = "TRACE" ] && _wrap_len="$((_wrap_len - 2))"
            fi

            if [ -n "$LOG_FMT_SYM_ENABLE" ]; then
                eval "_lbl_suffix=\"\${LOG_FMT_SYM_TRACE_OUT:+\${LOG_FMT_SYM_TRACE_OUT} }\""
            fi

            case "$_opt" in {*} | \(*\)) _wrap_len=-2 ;; esac

            case "$_offset" in
            -*) _offset="-$((${_offset#-} + _wrap_len))" ;;
            *[0-9]*) _offset="$((_offset + _wrap_len))" ;;
            esac

            _out="${_out}${_prefix}%${_offset}s" # 13. Inject padding
            _fmt="${_after_at#"$_right_part"}"   # 14. Advance the string
            set -- "$@" "$_opt_glued"            # 15. Append to printf arguments
        fi
    done

    # Append any remaining literal text after the final variable
    _out="${_out}${_fmt}${LOG_DEFAULT_COLOR:-$(tput sgr0)}"
    _opts="$@"
    # debug _out _opts

    # Output the fully resolved format string
    printf "$_out\n" "$@"
}

_valid_color_str() { case "$1" in LOG_DEBUG_COLOR | LOG_INFO_COLOR | LOG_SUCCESS_COLOR | LOG_WARNING_COLOR | LOG_ERROR_COLOR | LOG_TRACE_COLOR | LOG_CUSTOM_COLOR) return 0 ;; *) return 1 ;; esac }

log() {
    unset _lbl _msg _lvl _color _input_color

    # If more than 2 args are provided to the log function, we always assume that
    # the last argument is a color. This is bypassed by setting any color flag
    case "$#" in
    0) printf "WARNING: No message\n" >&2 ;;
    1)
        _lbl="INFO"
        _msg="$1"
        ;;
    2)
        _lbl="$1"
        _msg="$2"
        ;;
    *)
        _lbl="$1"
        shift
        _msg="$*"

        _raw_color=""
        for _raw_color in "$@"; do :; done

        _input_color="$_raw_color"
        [ -n "$_raw_color" ] && _msg="${_msg% $_raw_color}"
        ;;
    esac

    _lbl_upper="$(set_case "upper" "$_lbl")"

    # Extract and validate the log level from the label
    case "$_lbl_upper" in
    DEBUG | INFO | SUCCESS | WARNING | ERROR)
        _lvl="$_lbl_upper"
        ;;
    ENTRY | EXIT)
        _lvl="TRACE"
        _lbl="$_lbl_upper"
        ;;
    TRACE | TRACE_IN | TRACE_OUT)
        _lvl="TRACE"
        _lbl="TRACE"
        ;;
    *)
        _lvl="CUSTOM"
        ;;
    esac

    # Validate levels since they'll be eval-ed
    case "$LOG_LEVEL_STDOUT" in
    DEBUG | INFO | SUCCESS | WARNING | ERROR | TRACE | CUSTOM) ;;
    *) LOG_LEVEL_STDOUT=INFO ;;
    esac
    case "$LOG_LEVEL_LOG" in
    DEBUG | INFO | SUCCESS | WARNING | ERROR | TRACE | CUSTOM) ;;
    *) _lvl_log=INFO ;;
    esac

    # 1. Apply 8-bit ANSI color code if the argument is an integer (0-255).
    # 2. Apply predefined color variable if the argument is a valid color string.
    # 3. Fallback to the default color for the current log level.
    if is_uint "$_input_color" && [ "$_color" -le 255 ]; then
        eval "_color=\"\$(tput setaf \"$_input_color\")\""
    elif _valid_color_str "$_input_color"; then
        eval "_color=\"\$$_input_color\""
    else
        eval "_color=\"\$LOG_${_lvl}_COLOR\""
    fi

    # Resolve the symbol and its conditional spacing
    if [ "${LOG_FMT_SYM_ENABLE:-1}" = "1" ]; then
        eval "_sym=\"\${LOG_FMT_SYM_${_lbl_upper}:-}\""
    fi

    # Resolve dynamic variables
    eval "_lvl_int=\"\$LOG_LEVEL_$LOG_LEVEL_LOG\""
    eval "_lvl_stdout=\"\$LOG_LEVEL_$LOG_LEVEL_STDOUT\""
    eval "_lvl_log=\"\$LOG_LEVEL_$_lvl_log\""
    eval "_fmt_lbl=\"\$LOG_FORMAT_$_lbl_upper\""
    eval "_fmt_lvl=\"\$LOG_FORMAT_$_lvl\""

    # Priority chain: 1) Label, 2) Level, 3) Default
    current_log_format="${_fmt_lbl:-${_fmt_lvl:-$LOG_FORMAT}}"

    unset _fmt_lbl _fmt_lvl

    # Print to STDOUT
    if [ "$_lvl_stdout" -le "$_lvl_int" ]; then
        _log_print "$current_log_format"
    fi

    # Check _lvl_log to see if this level of entry goes to LOG_PATH
    if is_int "$_lvl_log"; then
        if [ "$_lvl_log" -le "$_lvl_int" ]; then
            # Write to LOG_PATH without fancy colors
            if [ -n "$LOG_PATH" ]; then
                _log_print "$current_log_format" | strip_ansi >>"$LOG_PATH"
            fi
        fi
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Begin logging section
# ---------------------------------------------------------------------------
# Detect which shell is running
case "${ZSH_VERSION:+zsh}:${BASH_VERSION:+bash}" in
zsh:*) SCRIPT_EXTENSION="zsh" ;;
*:bash) SCRIPT_EXTENSION="bash" ;;
*) SCRIPT_EXTENSION="sh" ;;
esac

# Determines if we print color or not
if ! tty -s; then
    readonly INTERACTIVE_MODE="off"
else
    readonly INTERACTIVE_MODE="on"
fi

# Enable POSIX shell features
log_info() { log "INFO" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_error() { log "ERROR" "$@"; }
log_warning() { log "WARNING" "$@"; }
log_debug() { log "DEBUG" "$@"; }
log_trace() { log "TRACE" "$SCRIPT_NAME:$_caller_lineno $*"; }
log_trace_in() { log "TRACE_IN" "$SCRIPT_NAME:$_caller_lineno $*"; }
log_trace_out() { log "TRACE_OUT" "$SCRIPT_NAME:$_caller_lineno $*"; }
log_entry() { log "ENTRY" "$0:$_caller_lineno $*"; }
log_exit() { log "EXIT" "$0:$_caller_lineno $*"; }

shopt -s expand_aliases 2>/dev/null || true

if [ "${LOG_FMT_DYNAMIC_OPTS:-enable}" = "enable" ]; then
    alias log_trace='_caller_lineno=$LINENO log_trace'
    alias log_trace_in='_caller_lineno=$LINENO log_trace_in'
    alias log_trace_out='_caller_lineno=$LINENO log_trace_out'
    alias log_debug='_caller_lineno=$LINENO log_debug'
    alias log_info='_caller_lineno=$LINENO log_info'
    alias log_success='_caller_lineno=$LINENO log_success'
    alias log_warning='_caller_lineno=$LINENO log_warning'
    alias log_error='_caller_lineno=$LINENO log_error'
    alias log_entry='_caller_lineno=$LINENO log_entry'
    alias log_exit='_caller_lineno=$LINENO log_exit'
    alias log='_caller_lineno=$LINENO log'
fi

#TODO: Add file rotation for full logs
#TODO: Add an implementation of tput to add ANSI
