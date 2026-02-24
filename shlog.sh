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

# FIXME:
# ISSUE:
# BUG:
# XXX:
# HACK:
# WARNING:
# WARN:
# OPTIMIZE:
# OPTIM:
# PERFORMANCE:
# PERF:
# TESTING:
# TEST:
# PASSED:
# FAILED:
# NOTE:
# INFO:
# TODO:


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

# "
: ${LOG_LEVEL:=$DEFAULT_LEVEL}
: ${LOG_LEVEL_LOG:=$LOG_LEVEL}
: ${LOG_LEVEL_STDOUT:=$LOG_LEVEL}
: ${LOG_FORMAT:=$DEFAULT_TEMPLATE}
: ${LOG_FORMAT_LOG:=$LOG_FORMAT}
: ${LOG_FORMAT_STDOUT:=$LOG_FORMAT}

# FIX: Should be tested against a _user_modified flag before setting style
: ${LOG_STYLE:=${LOG_FORMAT:+rich}}
: ${LOG_STYLE_LOG:=$LOG_STYLE}
: ${LOG_STYLE_STDOUT:=$LOG_STYLE}


# Determines the padding size for fields using the empty '@' modifier.
# Set to the maximum expected length of the content for auto-alignment.
#
_tmp_date=$(date "+$LOG_DATE_FORMAT")
: ${LOG_FMT_OFFSET_DATE:=${#_tmp_date}}         # Static size
: ${LOG_FMT_OFFSET_HOSTNAME:=${#HOSTNAME}}      # Static size
: ${LOG_FMT_OFFSET_SCRIPTNAME:=${#SCRIPT_NAME}} # Static size
: ${LOG_FMT_OFFSET_LABEL:=7}                    # Fits "SUCCESS" (7 chars)
: ${LOG_FMT_OFFSET_LINENO:=4}                   # Fits up to "9999"" lines
: ${LOG_FMT_OFFSET_TRACE:=0}                    
: ${LOG_FMT_OFFSET_ENTRY:=0}                    
: ${LOG_FMT_OFFSET_EXIT:=0}                    
: ${LOG_FMT_OFFSET_DEBUG:=0}                    
: ${LOG_FMT_OFFSET_INFO:=0}                    
: ${LOG_FMT_OFFSET_SUCCESS:=0}                    
: ${LOG_FMT_OFFSET_WARNING:=0}                    
: ${LOG_FMT_OFFSET_ERROR:=0}                    
unset _tmp_date

# ...
[ ${LOG_FMT_SYM_ENABLE:=1} -eq 0 ] || {
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
}

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

is_int() { case "${1#-}" in '' | *[!0-9]*) return 1 ;; esac }
is_uint() { case "$1" in '' | *[!0-9]*) return 1 ;; esac }
is_uint8() { is_uint "$1" && test "$1" -lt 256; }

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

_get_val() {
    _color_code="${1#c}"
    case "$1" in
    c0*)          _val="$LOG_DEFAULT_COLOR" ;;
    date*)        _val="$(date +"$LOG_DATE_FORMAT")" ;;
    label_upper*) _val="$_lbl_upper" ;;
    label*)       _val="$_lbl" ;;
    message*)     _val="$_msg" ;;
    hostname*)    _val="$HOSTNAME" ;;
    filename*)    _val="$SCRIPT_NAME" ;;
    lineno*)      _val="$_caller_lineno" ;;
    level_int*)   _val="$_lvl_int" ;;
    sym*)         _val="$_sym" ;;
    log_path*)    _val="$LOG_PATH" ;;
    c[1-9]*)      _val="%$1"               # Invalid color
        is_uint8 "${1#c}" && _val="${1#c}" # Valid color
        ;;
    {*) 
        _raw="${1#?}"    # Strip first '{'
        _val="${_raw%?}" # Strip last '}'
        ;;
    # c[1-9]* | c[1-9][0-9]* | c[1-2][0-9][0-9]*)
    #     _color_code="${1#c}"
    #     if [ "$_color_code" -le 255 ]; then
    #         _val="$(tput setaf $_color_code)"
    #     else
    #         _val="%$1"
    #         return 1
    #     fi
    #     ;;
    \(*)
        # FIXME: LOCK THIS BEHIND A FLAG OR REMOVE COMPLETELY
        #        THIS ENABLES ARBITRARY REMOTE CODE EXECUTION
        _cmd="${1#?}"              # Safely strip the first character '('
        _val="$(eval "${_cmd%?}")" # Safely strip the last character ')' and execute
        return 1
        ;;
    *) _val="%$1"; return 1 ;; # Restore the % for invalid/unrecognized options
    esac

    # HACK: Could implement a smart alignment by combining LOG_FMT_OFFSET_OPT with
    #       LOG_FMT_LONGEST_OPT

    return 0
}

# foo() { printf "Input: %s\nPattern: %s\n" "$1" "$2"; case "$1" in $2) echo "Match" ;; *) echo "No match" ;; esac; }
_sanitize_var() { case "$1" in ''|*[!A-Z0-9_]*) return 1 ;; esac; return 0; }
_paterr() {
    _opt="$_opt$1"
    printf 'Warning: shlog.sh:_log_print: bad pattern `%%%s` %s %s\n' "${_opt}${1}" ${2+\(\$1} "${2+$2)}"
    # _fmt_mode="normal"
    exit 2
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

    while case "$_fmt" in *%*) true ;; *) false ;; esac; do
        _before="${_fmt%%\%*}"
        _after_percent="${_fmt#*\%}"
        _max_width=0

        # Safely extract _opt, accommodating braces and parentheses
        case "$_after_percent" in
        {*)  _opt="${_after_percent%%\}*}"; _opt="${_opt}}" ;;
        \(*) _opt="${_after_percent%%\)*}"; _opt="${_opt})" ;;
        *)   _opt="${_after_percent%%[!a-zA-Z0-9_]*}"       ;;
        esac

        # Identify the string immediately following the extracted option
        _after_opt="${_after_percent#"$_opt"}"

        # Detect mode: Does the string immediately following the option start with a modifer '@' or '?'
        case "$_after_opt" in
        [@?][@?]*)           _paterr "${_after_opt%${_after_opt#??}}"   ;;
        [?][!0-9]*)          _paterr "?" "must be followed by a number" ;;
        c[0-9]*[!%]*@)       _paterr "@" "cannot align colors"          ;;
        [?][0-9]*[@][1-9]*)  _paterr "?@" "Use @offset,max_width"       ;;
        [@][1-9-]*[?][0-9]*) _paterr "@?" "Use @pos,max_width"          ;;
        [@][0-9-]*[,][0-9]*) _fmt_mode=","                              ;; 
        [?]*)                _fmt_mode="?"                              ;;
        [@]*)                _fmt_mode="@"                              ;;
        *)                   _fmt_mode="none"                           ;;
        esac

        if [ "$_fmt_mode" = "none" ]; then
            _prefix="$_before"           # Literal text before the %
            _out="${_out}${_prefix}%s"   # Append literal text to _out followed by %s
            _get_val "$_opt"             # Resolve value
            _fmt="$_after_opt"           # Advance the string past the option
            set -- "$@" "$_val"          # Append to printf arguments
        else
            _full_mod="${_after_opt%%[$_sp$_tb%]*}"

            _offset=""
            _max_width=""
            _opt_suffix=""

            case "$_fmt_mode" in
            ",") # @PADDING,WIDTH (e.g. @5,2ms)
                _body="${_full_mod#@}"               # Strip @ -> 5,2ms
                _offset="${_body%%,*}"               # 5
                _body="${_body#*,}"                  # 2ms
                _max_width="${_body%%[!0-9]*}"       # 2
                _opt_suffix="${_body#"$_max_width"}" # ms
                ;;
            "?") # ?WIDTH (e.g. ?2ms)
                _body="${_full_mod#\?}"              # 2ms
                _max_width="${_body%%[!0-9]*}"       # 2
                _opt_suffix="${_body#"$_max_width"}" # ms
                ;;
            "@") # @PADDING (e.g. @5ms)
                _body="${_full_mod#@}"               # 5ms
                _offset="${_body%%[!0-9-]*}"         # 5
                _opt_suffix="${_body#"$_offset"}"    # ms
                ;;
            esac

            _opt_prefix="${_before##*[$_sp$_tb]}"   
            _prefix="${_before%"$_opt_prefix"}"     
            _get_val "$_opt"
            _ret=$?

            _opt_glued="${_opt_prefix}${_val}${_opt_suffix}" 

            # Calculate Offset
            _wrap_len=0
            case "$_opt" in {*} | \(*\)) _wrap_len=-2 ;; esac
            
            if [ -z "$_offset" ] && [ $_ret -eq 0 ]; then
                _wrap_len=$((${#_opt_prefix} + ${#_opt_suffix}))
                _safe_opt=$(set_case "upper" "$_opt") 
                eval "_offset=\$(( -\${LOG_FMT_OFFSET_${_safe_opt}:-0} ))"
                # [ "$_lvl" = "TRACE" ] && _wrap_len="$((_wrap_len + $LOG_FMT_OFFSET_TRACE))"
            fi

            _wrap_len="$((_wrap_len + ${_fmt_lvl_offset:-0}))" # Add LOG_FMT_OFFSET_<LEVEL/LABEL>

            case "$_offset" in
                -*) _offset="-$((${_offset#-} + _wrap_len))" ;;
                *[0-9]*) _offset="$((_offset + _wrap_len))" ;;
            esac

            _out="${_out}${_prefix}%${_offset}s"

            # ADVANCE: Safely strip the fully consumed modifier block
            _fmt="${_after_opt#"$_full_mod"}" 

            set -- "$@" "$_opt_glued"
        fi
    done

    # Append any remaining literal text after the final variable
    _out="${_out}${_fmt}${LOG_DEFAULT_COLOR:-$(tput sgr0)}"
    _opts="$@"
    debug _out _opts

    # Output the fully resolved format string
    printf "$_out\n" "$@"
}

_log_print "$1"

_valid_color_str() { case "$1" in LOG_DEBUG_COLOR | LOG_INFO_COLOR | LOG_SUCCESS_COLOR | LOG_WARNING_COLOR | LOG_ERROR_COLOR | LOG_TRACE_COLOR | LOG_CUSTOM_COLOR) return 0 ;; *) return 1 ;; esac }
_sanitize_var() { case "$1" in ''|*[!A-Z0-9_]*) return 1 ;; esac; return 0; }

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

    # Sanitize label
    _sanitize_var "$_lbl_upper" || {
        printf "WARNING: Invalid characters in label '%s'. forcing CUSTOM.\n" "$_lbl_upper" >&2
        _lbl_upper="CUSTOM"
    }

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
    if is_uint "$_input_color" && [ "$_input_color" -le 255 ]; then
        # Safe because we check if
        eval "_color=\"\$(tput setaf \"$_input_color\")\""
    elif _valid_color_str "$_input_color"; then
        eval "_color=\"\$$_input_color\"" # Safe: Validated
    else
        eval "_color=\"\$LOG_${_lvl}_COLOR\"" # Safe: Validated _lvl
    fi

    # Resolve the symbol and its conditional spacing
    if [ "${LOG_FMT_SYM_ENABLE:-1}" = "1" ]; then
        eval "_sym=\"\${LOG_FMT_SYM_${_lbl_upper}:-}\"" # Safe: Validated
    fi

    # Resolve dynamic variables
    eval "_lvl_int=\"\$LOG_LEVEL_$_lvl\""                        # Safe: Validated
    eval "_lvl_stdout=\"\$LOG_LEVEL_$LOG_LEVEL_STDOUT\""         # Safe: Validated
    eval "_lvl_log=\"\$LOG_LEVEL_$LOG_LEVEL_LOG\""               # Safe: Validated
    eval "_fmt_lbl_stdout=\"\$LOG_FORMAT_${_lbl_upper}_STDOUT\"" # Safe: Validated
    eval "_fmt_lbl_log=\"\$LOG_FORMAT_${_lbl_upper}_LOG\""       # Safe: Validated
    eval "_fmt_lvl_stdout=\"\$LOG_FORMAT_${_lvl}_STDOUT\""       # Safe: Validated
    eval "_fmt_lvl_log=\"\$LOG_FORMAT_${_lvl}_LOG\""             # Safe: Validated
    eval "_fmt_lbl=\"\$LOG_FORMAT_$_lbl_upper\""                 # Safe: Validated
    eval "_fmt_lvl=\"\$LOG_FORMAT_$_lvl\""                       # Safe: Validated
    eval "_fmt_lvl_offset=\"\${LOG_FMT_OFFSET_$_lbl_upper:-0}\""  # Safe: Validated

    # Base Generic Chain: Label > Level > Global LOG_FORMAT
    _chain_generic="${_fmt_lbl:-${_fmt_lvl:-$LOG_FORMAT}}"
    
    # STDOUT Chain: Label_STDOUT > Level_STDOUT > Global LOG_FORMAT_STDOUT
    _chain_stdout="${_fmt_lbl_stdout:-${_fmt_lvl_stdout:-$LOG_FORMAT_STDOUT}}"
    
    # LOG Chain: Label_LOG > Level_LOG > Global LOG_FORMAT_LOG
    _chain_log="${_fmt_lbl_log:-${_fmt_lvl_log:-$LOG_FORMAT_LOG}}"

    _final_stdout="${_chain_stdout:-$_chain_generic}"
    _final_log="${_chain_log:-$_chain_generic}"

    unset _fmt_lbl _fmt_lvl _fmt_lbl_stdout _fmt_lvl_stdout \
        _fmt_lbl_log _fmt_lvl_log _chain_generic _chain_stdout _chain_log

    # Print to STDOUT
    if [ "$_lvl_stdout" -le "$_lvl_int" ]; then
        _log_print "$_final_stdout"
    fi

    # Check _lvl_log to see if this level of entry goes to LOG_PATH
    if is_int "$_lvl_log"; then
        if [ "$_lvl_log" -le "$_lvl_int" ]; then
            # Write to LOG_PATH without fancy colors
            if [ -n "$LOG_PATH" ]; then
                _log_print "$_final_log" | strip_ansi >>"$LOG_PATH"
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
