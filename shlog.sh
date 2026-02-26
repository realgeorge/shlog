#!/usr/bin/env sh
#
# shlog - A POSIX-compliant logging tool
#
# Copyright (c) 2026 realgeorge
# Based on 'slog' by Fred Palmer (2009-2011) and Joe Cooper (2017)
# https://github.com/swelljoe/slog
#
# This source code is licensed under the MIT license

# ---------------------------------------------------------------------------
# Configuration Defaults
# ---------------------------------------------------------------------------
# Source the configuration and argument parsing script after setting
# default values. This allows user-defined settings from config files or
# command-line arguments to override the defaults initialized below.

# ...
[ -n "$SHLOG_LOADED" ] && return 0
SHLOG_LOADED=1

# ...
. "$HOME/Projects/shlog/includes/config.sh"
. "$HOME/Projects/shlog/includes/parse.sh"
. "$HOME/Projects/shlog/includes/format.sh"

# ...
SCRIPT_ARGS="$@"
SCRIPT_NAME=$0
SCRIPT_NAME=${SCRIPT_NAME#\./}
SCRIPT_NAME=${SCRIPT_NAME##/*/}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

DEFAULT_TEMPLATE="$(SHLOG_GET_TEMPLATE normal)"
DEFAULT_LEVEL=DEBUG

# TODO: Log rotation
: ${LOG_MAX_SIZE:=1048576}
: ${LOG_MAX_FILES:=5}
: ${LOG_PATH:=./shlog.log}

# ...
: ${LOG_LEVEL:=$DEFAULT_LEVEL}
: ${LOG_LEVEL_STDOUT:=$LOG_LEVEL}
: ${LOG_LEVEL_LOG:=$LOG_LEVEL_STDOUT}
: ${LOG_FORMAT:=$DEFAULT_TEMPLATE}
: ${LOG_FORMAT_STDOUT:=$LOG_FORMAT}
: ${LOG_FORMAT_LOG:=$LOG_FORMAT_STDOUT}
: ${LOG_STYLE:=${LOG_FORMAT:+rich}}
: ${LOG_STYLE_STDOUT:=$LOG_STYLE}
: ${LOG_STYLE_LOG:=$LOG_STYLE_STDOUT}

# Determines the padding size for fields using the empty '@' modifier.
# Set to the maximum expected length of the content for auto-alignment.
#

_tmp_date=$(date "+$LOG_DATE_FORMAT")
: ${LOG_FMT_MAX_WIDTH_DATE:=${#_tmp_date}}         # Static size
: ${LOG_FMT_MAX_WIDTH_HOSTNAME:=${#HOSTNAME}}      # Static size
: ${LOG_FMT_MAX_WIDTH_SCRIPTNAME:=${#SCRIPT_NAME}} # Static size
: ${LOG_FMT_MAX_WIDTH_LABEL:=7}                    # Fits "SUCCESS" (7 chars)
: ${LOG_FMT_MAX_WIDTH_LINENO:=4}                   # Fits up to "9999"" lines
unset _tmp_date

SHLOG_APPLY_THEME "$LOG_STYLE"

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

# -------------------------------------------------------------------
# Color Definitions
# -------------------------------------------------------------------
# Determines if we print color or not
# TODO: Make user configurable
if ! tty -s; then
    readonly INTERACTIVE_MODE="off"
else
    readonly INTERACTIVE_MODE="on"
fi

if [ "$INTERACTIVE_MODE" = "off" ]; then

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
    : ${LOG_DEFAULT_COLOR:="$(tput sgr0)"}
    : ${LOG_INFO_COLOR:="$(tput sgr0)"}
    : ${LOG_SUCCESS_COLOR:="$(tput setaf 2)"}
    : ${LOG_WARNING_COLOR:="$(tput setaf 3)"}
    : ${LOG_ERROR_COLOR:="$(tput setaf 1)"}
    : ${LOG_DEBUG_COLOR:="$(tput setaf 4)"}
    : ${LOG_TRACE_COLOR:="$(tput setaf 8)"}
    : ${LOG_CUSTOM_COLOR:="$(tput setaf 69)"}
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

is_int() { case "${1#-}" in '' | *[!0-9]*) return 1 ;; esac; }
is_int8() { is_int "$1" && test "$1" -lt 256; }
is_uint() { case "$1" in '' | *[!0-9]*) return 1 ;; esac; }
is_uint8() { is_uint "$1" && test "$1" -lt 256; }
is_color_str() { case "$1" in LOG_DEBUG_COLOR | LOG_INFO_COLOR | LOG_SUCCESS_COLOR | LOG_WARNING_COLOR | LOG_ERROR_COLOR | LOG_TRACE_COLOR | LOG_CUSTOM_COLOR) return 0 ;; *) return 1 ;; esac }
is_color() { is_uint8 "$1" || is_color_str "$1"; }
is_upper_alnum() { case "$1" in '' | *[!A-Z0-9_]*) return 1 ;; esac; return 0; }

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

# INFO: Can be replaced with | tr [:lower:] [:upper:] later
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

# foo() { printf "Input: %s\nPattern: %s\n" "$1" "$2"; case "$1" in $2) echo "Match" ;; *) echo "No match" ;; esac; }
# TODO: Ändra namn till str_sanitize
is_upper_alnum() {
    # Usage: is_upper_alnum "string"
    # Returns: 0 if string is a legal variable name, 1 otherwise
    case "$1" in *[!A-Z0-9_]*) return 1 ;; esac
    return 0
}

# XXX: DO NOT REMOVE EXIT
_paterr() {
    # Usage: _paterr "pattern" [reason] [message]
    # Prints: Warning: bad pattern: `pattern` ([pattern message])
    _get_opt "$1"
    k=${_key#--}
    printf 'ERROR: `%%%s`%s%s\n' "${k}" "${2+ ($k}" "${2+ $2)}"
    # _fmt_mode="normal"
    exit 2
}

_shlog_lstrip() {
    # Usage: _shlog_lstrip "string" "pattern"
    case $1 in
    *$2*) printf '%s%s\n' "${1%%$2*}" "${1#*$2}" ;;
    *)
        printf '%s\n' "$1"
        return 1
        ;;
    esac
    return 0
}

_shlog_resolve() {
    _raw="${2#?}"
    _cc="${_raw%%[!0-9]*}"

    case "$1:$2" in
    # KEY EXTRACTION
    key:c[1-9]*)      _key="c${_raw%%[!0-9]*}" ;;
    key:c0*)          _key="c0" ;;
    key:date*)        _key="date" ;;
    key:label_upper*) _key="label_upper" ;;
    key:label*)       _key="label" ;;
    key:message*)     _key="message" ;;
    key:hostname*)    _key="hostname" ;;
    key:scriptname*)  _key="scriptname" ;;
    key:lineno*)      _key="lineno" ;;
    key:level_int*)   _key="level_int" ;;
    key:sym*)         _key="sym" ;;
    key:log_path*)    _key="log_path" ;;
    key:*)            _key="$1"; return 1 ;;

    # CODE EXTRACTION
    code:date)         _code='$(date +"${LOG_DATE_FORMAT}")' ;;
    code:label_upper)  _code='${_evt_id}' ;;
    code:label)        _code='${_evt_lbl}' ;;
    code:message)      _code='${_evt_msg}' ;;
    code:hostname)     _code='${HOSTNAME}' ;;
    code:scriptname)   _code='${SCRIPT_NAME:-$0}' ;;
    code:lineno)       _code='${_caller_lineno:-}' ;;
    code:level_int)    _code='${_lvl_int}' ;;
    code:sym)          _code='${_evt_sym}' ;;
    code:log_path)     _code='${LOG_PATH}' ;;
    code:c[1-9]*)      _code="\$(tput setaf ${_cc})" ;;
    code:*)            _code=''; return 1 ;;
    esac
    return 0
}

SHLOG_HAS_CACHE() { case ",${SHLOG_CACHED_VARS}," in *,"$1",*) return 0 ;; esac; return 1; }

_shlog_escape() {
    # Usage: _shlog_escape "string"
    # Prints the string with single quotes escaped for use in single-quoted eval.
    # Input:  It's "Time"
    # Output: It'\''s "Time"
    printf '%s\n' "$1" | sed "s/'/'\\\\''/g"#
}

_shlog_compile() {
    # Usage: _log_compile "TARGET" "EVENT_ID" "RAW_FORMAT_STRING"
    _target="$1"
    _event="$2"
    _evt_fmt="$3"
    debug _evt_fmt
    
    _printf_fmt=""
    _keys=""

    # 1. Parse left to right, stopping at each %
    while [ "$_evt_fmt" != "${_evt_fmt%%\%*}" ]; do
        # Split format string
        _before="${_evt_fmt%%\%*}"
        _after_percent="${_evt_fmt#*\%}"

        # Strip backslahes
        while _before=$(_shlog_lstrip "$_before" "\\"); do :; done

        # Extract option token safely
        _opt="${_after_percent%%[!a-zA-Z0-9_\\]*}" 
        _after_opt="${_after_percent#"$_opt"}"

        # 3. Validate option
        if ! _shlog_resolve "key" "$_opt" || ! _shlog_resolve "code" "$_opt"; then
            # Invalid option: Treat it as raw text and continue
            _printf_fmt="${_printf_fmt}${_before}%${_opt}"
            _evt_fmt="$_after_opt"
            continue
        fi

        # 4. Check for modifiers (@ or ?)
        case "$_after_opt" in
            @*|?*)
                # Extract contiguous block up to the next whitespace for parsing
                _mod_block="${_after_opt%%[[:space:]]*}"
                _fmt_mode="none"
                
                # 5. Validate modifier and associate mode
                case "$_mod_block" in
                    @*[0-9]*,[0-9]*) _fmt_mode="," ;;
                    \?[0-9]*)        _fmt_mode="?" ;;
                    @*)              _fmt_mode="@" ;;
                esac

                if [ "$_fmt_mode" = "none" ]; then
                    # Invalid modifier: treat as normal character
                    _printf_fmt="${_printf_fmt}${_before}%s"
                    _keys="${_keys}${_keys:+ }\"${_code}\""
                    _evt_fmt="$_after_opt"
                    continue
                fi

                # 6. Extract prefix of the option stopping at closest whitespace
                _opt_prefix="${_before##*[$_sp$_tb]}"
                _prefix="${_before%"$_opt_prefix"}"

                # 7. Enter logic blocks based on mode
                _padding=""
                _max_width=""
                _opt_suffix=""
                _raw_suffix=""
                
                if [ "$_fmt_mode" = "," ]; then
                    _body="${_mod_block#@}"
                    _padding="${_body%%,*}"
                    _body="${_body#*,}"
                    _max_width="${_body%%[!0-9]*}"
                    _raw_suffix="${_body#"$_max_width"}"
                elif [ "$_fmt_mode" = "?" ]; then
                    _body="${_mod_block#\?}"
                    _max_width="${_body%%[!0-9]*}"
                    _raw_suffix="${_body#"$_max_width"}"
                elif [ "$_fmt_mode" = "@" ]; then
                    _body="${_mod_block#@}"
                    _padding="${_body%%[!0-9-]*}"
                    _raw_suffix="${_body#"$_padding"}"
                    [ -z "$_padding" ] && _fmt_mode="config"
                fi

                # Assign option suffix (split at next whitespace)
                _opt_suffix="${_raw_suffix%%[$_sp$_tb]*}"
                
                # Advance format string past the evaluated modifier block
                _evt_fmt="${_after_percent#*"$_opt$_mod_block"}"
                
                # Upper case option for variable resolution
                _opt_upper="$(set_case "upper" "${_opt#--}")"
                
                # 8b. Fetch globals if mode=config
                if [ "$_fmt_mode" = "config" ]; then
                    eval "_padding=\"\${LOG_FMT_${_opt_upper}_OFFSET:-}\""
                    eval "_max_width=\"\${LOG_FMT_${_opt_upper}_MAX_WIDTH:-}\""
                fi

                # 8a. Calculate offset: N = length(prefix) + abs(_padding) + _max_width + length(suffix)
                _wrap_len=$((${#_opt_prefix} + ${#_opt_suffix}))
                
                debug _padding _max_width
                # POSIX absolute value
                if is_uint8 "$_max_width" || is_int8 "$_padding"; then
                _abs_padding="${_padding#-}"
                _abs_padding="${_abs_padding:-0}"
                _max_width="${_max_width:-0}"
                _n=$((_wrap_len + _abs_padding + _max_width))
                fi
                
                case "$_padding" in
                    -*) _final_padding="-$_n" ;;
                    *)  _final_padding="$_n" ;;
                esac

                # 9. Clean up format string, append to out and args
                _printf_fmt="${_printf_fmt}${_prefix}%${_final_padding}s"
                _glued_key="${_opt_prefix}\"${_code}\"${_opt_suffix}"
                _keys="${_keys}${_keys:+ }${_glued_key}"

                # 10. Cache padding and max_width
                eval "LOG_FMT_${_opt_upper}_OFFSET=\"\$_final_padding\""
                eval "LOG_FMT_${_opt_upper}_MAX_WIDTH=\"\$_max_width\""
                ;;
            *)
                # No modifier present
                _printf_fmt="${_printf_fmt}${_before}%s"
                _keys="${_keys}${_keys:+ }\"${_code}\""
                _evt_fmt="$_after_opt"
                ;;
        esac
    done

    # Append remaining literal text and generate the dynamic function name
    _printf_fmt="${_printf_fmt}${_evt_fmt}"
    _cached_func_name="_SHLOG_RENDER_${_event}_${_target}"

    [ -n "$_cached_func_name" ] || exit 420

    # Compile format to memory and add to cache list
    eval "${_cached_func_name}() { printf '${_printf_fmt}\n' ${_keys}; }"
    SHLOG_CACHE="${SHLOG_CACHE:+$SHLOG_CACHE,}$_cached_func_name"

    debug _printf_fmt _keys SHLOG_CACHE _cached_func_name
    return 0
}

_shlog_render() {
    # Usage: _shlog_render "TARGET" "EVENT" "RAW_FORMAT_STRING"
    _target="$1"
    _event="$2"
    _raw_fmt="$3"

    [ -n "$_target" ] || exit 1337
    [ -n "$_event" ] || exit 1337

    if ! SHLOG_HAS_CACHE "_SHLOG_CACHE_${_event}_${_target}"; then
        _shlog_compile "$_target" "$_event" "$_raw_fmt"
    fi

    "_SHLOG_RENDER_${_event}_${_target}"
}

log() {
    unset _evt_lbl _evt_msg _evt_lvl _evt_color _raw_color _evt_offset _evt_id _evt_sym _evt_lvl_int _lvl_stdout _lvl_log _final_stdout _final_log

    # If more than 2 args are provided to the log function, we always assume that
    # the last argument is a color. This is bypassed by setting any color flag
    case "$#" in
    0) printf "WARNING: No message\n" >&2; return 1;;
    1) _evt_msg="$1";;
    2) _evt_lbl="$1"; shift; _evt_msg="$1" ;;
    *) _evt_lbl="$1"; shift; _evt_msg="$*"

        # Assume last argument is color
        _raw_color=""
        for _raw_color in "$@"; do :; done

        # If it is a color, we strip it from _evt_msg
        is_color "$_raw_color" && _evt_msg="${_evt_msg% $_raw_color}"
        ;;
    esac

    # Clean input label to assign level and get eval'ed
    # This patches eval vulnerabilities assuming is_upper_alnum works properly
    if [ -z "$_evt_lbl" ]; then
        _evt_lbl="INFO"
        _evt_id="INFO"
    else
        _evt_id="$(set_case "upper" "$_evt_lbl" | sed 's/[^A-Z0-9_]/_/g')"
        is_upper_alnum "$_evt_id" || {
            printf "ERROR: Illegal identifier in label `%s`.\n" "$_evt_id" >&2
            printf "       Identifier can not be eval'ed safely\n" >&2
            exit 2
        }
    fi

    # TODO: Create grouping function that associates an event with a level

    # Extract and validate the log level from the label
    case "$_evt_id" in
    DEBUG | INFO | SUCCESS | WARNING | ERROR) _evt_lvl="$_evt_id" ;;
    
    # XXX: This is how group diffrent labels to the same level
    ENTRY | EXIT | TRACE*) _evt_lvl="TRACE" ;;

    # NOTE: CUSTOM level is not related to formatting.
    #       This is only used to compare level_int with level_target
    *) _evt_lvl="CUSTOM" ;;
    esac

    # Validate levels since they'll be eval-ed
    case "$LOG_LEVEL_STDOUT" in
    DEBUG | INFO | SUCCESS | WARNING | ERROR | TRACE | CUSTOM) ;;
    *) LOG_LEVEL_STDOUT=INFO ;;
    esac

    case "$LOG_LEVEL_LOG" in
    DEBUG | INFO | SUCCESS | WARNING | ERROR | TRACE | CUSTOM) ;;
    *) LOG_LEVEL_LOG=INFO ;;
    esac

    if is_int "$_raw_color"; then
        eval "_evt_color=\"\$(tput setaf \"$_raw_color\")\""
    elif is_color_str "$_raw_color"; then
        eval "_evt_color=\"\$$_raw_color\""
    else
        eval "_evt_color=\"\$LOG_${_evt_lvl}_COLOR\""
    fi

    # Resolve event specific symbol
    if [ "${LOG_FMT_SYM_ENABLE:-1}" = "1" ]; then
        eval "_evt_sym=\"\${LOG_FMT_SYM_${_evt_id}:-}\"" # Safe: Validated
    fi

    # Resolve event specific offsets
    eval "_evt_offset=\"\${LOG_FMT_OFFSET_${_evt_id}:-0}\""

    # Resolve event and target integer values
    eval "_evt_lvl_int=\"\$LOG_LEVEL_$_evt_lvl\""
    eval "_lvl_stdout=\"\$LOG_LEVEL_$LOG_LEVEL_STDOUT\""
    eval "_lvl_log=\"\$LOG_LEVEL_$LOG_LEVEL_LOG\""
    
    # NOTE: We should perhaps cache event specific formats for easier import/export?
    #       ALL IMPORT/EXPORT SHOULD GO THROUGH THE FORMAT STRING

    _errmsg3='ERROR: %s=%s (val: `%s`) is not a valid level\n'
    is_int "$_evt_lvl_int" || { printf "$_errmsg3" "LOG_LEVEL" "$_evt_lvl" "$_evt_lvl_int" >&2; exit 3; }
    is_int "$_lvl_stdout" || { printf "$_errmsg3" "LOG_LEVEL_STDOUT" "$LOG_LEVEL_STDOUT" "$_lvl_stdout" >&2; exit 3; }
    is_int "$_lvl_log" || { printf "$_errmsg3" "LOG_LEVEL_LOG" "$LOG_LEVEL_LOG" "$_lvl_log" >&2; exit 3; }

    # Print to STDOUT
    if [ "$_lvl_stdout" -le "$_evt_lvl_int" ]; then
        # Resolve STDOUT: LABEL_STDOUT -> LEVEL_STDOUT -> DEFAULT_STDOUT
        eval "_final_stdout=\"\${LOG_FORMAT_${_evt_id}_STDOUT:-\${LOG_FORMAT_${_evt_lvl}_STDOUT:-\$LOG_FORMAT_STDOUT}}\""
        [ -n "$_final_stdout" ] || { printf 'ERROR: No format is specified' && exit 4 ;}

        # Render and print STDOUT
        _shlog_render "STDOUT" "$_evt_id" "$_final_stdout"
    fi

    # Check _lvl_log to see if this level of entry goes to LOG_PATH
    [ -n "$LOG_PATH" ] || return 0
    if [ "$_lvl_log" -le "$_evt_lvl_int" ]; then
        # Resolve LOG: LABEL_LOG -> LEVEL_LOG -> DEFAULT_LOG
        eval "_final_log=\"\${LOG_FORMAT_${_evt_id}_LOG:-\${LOG_FORMAT_${_evt_lvl}_LOG:-\$LOG_FORMAT_LOG}}\""
        [ -n "$_final_stdout" ] || { printf 'ERROR: No format is specified' && exit 4 ;}
        
        # Render and print LOG
        _shlog_render "LOG" "$_evt_id" "$_final_log" | strip_ansi >>"$LOG_PATH"
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
