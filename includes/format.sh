#!/bin/sh
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

# ...
case "${LOG_DATE_FORMAT:-default}" in
default) LOG_DATE_FORMAT="%Y-%m-%d %H:%M:%S" ;;
systemd) LOG_DATE_FORMAT="%m %d %H:%M:%S" ;;
*) ;;
esac

# Returns the FORMAT STRING only.
SHLOG_GET_TEMPLATE() {
    case "$1" in
    normal) printf '%s\n' '[%date] [%label@] %sym%message' ;;
    systemd) printf '%s\n' '<%level_int>%sym%message' ;;
    json) printf '%s\n' '{"ts":"%date","lvl":"%label","msg":"%message"}' ;;
    *) return 1 ;;
    esac
}

# ..
# Applies ENVIRONMENT variables (Symbols, Colors, Flags).
SHLOG_APPLY_THEME() {
    case "$1" in
    rich)
        : "${LOG_FMT_SYM_ENABLE:=1}"
        : "${LOG_FMT_SYM_ENTRY:=> }"
        : "${LOG_FMT_SYM_TRACE_IN:=> }"
        : "${LOG_FMT_SYM_TRACE:=~ }"
        : "${LOG_FMT_SYM_TRACE_OUT:=< }"
        : "${LOG_FMT_SYM_EXIT:=< }"
        : "${LOG_FMT_OFFSET_TRACE}"
        ;;
    json) : ${LOG_FMT_SYM_ENABLE:=0} ;;
    esac
}

SHLOG_PREVIEW_FORMAT() {
    fmt="$(SHLOG_GET_TEMPLATE "$x")"
    SHLOG_APPLY_THEME "$x"
}
