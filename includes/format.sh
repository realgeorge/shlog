#!/usr/bin/env sh

# Formatting
case "${LOG_DATE_FORMAT:-default}" in
default) LOG_DATE_FORMAT="%Y-%m-%d %H:%M:%S" ;;
systemd) LOG_DATE_FORMAT="%m %d %H:%M:%S" ;;
*) ;;
esac

# Handle Style Preset fallback if LOG_FORMAT is unset
# TODO: Add LOG_FORMAT_LOG and LOG_FORMAT_STDOUT
# TODO: Change to LOG_FORMAT_STDOUT and LOG_FORMAT_LOG

if [ -z "$LOG_FORMAT" ]; then
    case "${LOG_FMT_PRESET:-default}" in
    default)
        LOG_FORMAT="[%date] [%label@] %sym%message"
        ;;
    rich)
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

SHLOG_PREVIEW_FORMAT() {
    #TODO: Should take a format string or valid preset as an
    #      argument and use _log_print to print out a preview
    #      of logs with different levels and labels.

    #XXX: Should the preview unset all user defined LOG_FMT vars?
    SHLOG_PRESET_FORMATS "$1"
}

# NOTE:
# Instead of using LOG_FMT_PRESET we should just default
# LOG_FORMAT_STDOUT/LOG_LEVEL_LOG to a preset fallback.
# SHLOG_PRESET_FORMATS should just apply settings and
# return the format string.
# ...
# Very useful because LOG_FMT_SYM_* is now resolved through
# %sym so we can include/exclude these in stdout vs log

SHLOG_PRESET_MODES() {
    case "$1" in
    default)
        LOG_FORMAT="[%date] [%label@] %sym%message"
        ;;
    rich)
        : ${LOG_FMT_SYM_ENABLE:=1} # Disabling lets us skip an eval
        : ${LOG_FMT_SYM_ENTRY:=> }
        : ${LOG_FMT_SYM_TRACE_IN:=> }
        : ${LOG_FMT_SYM_TRACE:=~ }
        : ${LOG_FMT_SYM_TRACE_OUT:=< }
        : ${LOG_FMT_SYM_EXIT:=< }
        ;;
    json) ;;
    esac
}

SHLOG_PRESET_FORMATS() {
    case "$1" in
    default)
        printf "%s\n" "[%date] [%label@] %sym%message"
        ;;
    json)
        printf "%s\n" '{"time":"%date","lvl":"%label","msg":"%message"}'
        ;;
    systemd) ;;
    *) return 1 ;;
    esac
    return 0
}

# Format Resolution Hierarchy
#
# 1. Label-Specific: LOG_FORMAT_<LABEL>_<DEST> (e.g., LOG_FORMAT_FATAL_STDOUT)
#    Highest priority. Targets specific custom types (FATAL, DB, NET).
#
# 2. Level-Specific: LOG_FORMAT_<LEVEL>_<DEST> (e.g., LOG_FORMAT_ERROR_STDOUT)
#    Category fallback. Applies to all labels sharing a level (DEBUG, INFO, CUSTOM).
#
# 3. Global Default: LOG_FORMAT_<DEST>          (e.g., LOG_FORMAT_STDOUT)
#    Base fallback if no specific label or level format is defined.
#
# Note: <DEST> is 'STDOUT' or 'LOG'.

# 1. Propagate Global "LOG_FORMAT" if it exists
#    If STDOUT/LOG are unset, they inherit LOG_FORMAT.
if [ -n "$LOG_FORMAT" ]; then
    : "${LOG_FORMAT_STDOUT:=$LOG_FORMAT}"
    : "${LOG_FORMAT_LOG:=$LOG_FORMAT}"
fi

# 2. Apply Specific Defaults (if still unset)
#    At this point, if they are still empty, it means the user
#    set NOTHING (neither specific nor global).
#    So we apply distinct defaults (e.g., color for stdout, plain for log).
: "${LOG_FORMAT_STDOUT:=$(SHLOG_PRESET_FORMATS default)}"
: "${LOG_FORMAT_LOG:=$(SHLOG_PRESET_FORMATS default)}"

# INFO: Resolve json logs entierly with rotating logs.
#       Figure out how the fuck we format a valid json log
#       - Needs to be valid even if program crashes
