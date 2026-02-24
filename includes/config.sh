#!/usr/bin/env sh

# -----------------------------------------------------------------
# How configuration should work:
# source shlog.sh --load-config [conf]
#
# config.sh should not be a standalone script.
#
# The reasoning for this is that shlog.sh is built around being
# included and sourced as a copy inside a working directory and not
# as a standalone binary located in /bin/shlog.
#
# My aim with this project is to create a logging library, where
# the only dependency should be the shlog.sh script itself.
#
# In this current version all formatting should be easily done inside
# a script by either:
#     a) configuring global variables in sourced script
#     b) creating a config file to read key-value pairs from
#
# Example on structure:
#     project
#     ├── includes
#         ├── shlog.sh
#     │   └── shlog.conf (optional)
#     └── script.sh
#
# In the future I might revise this and implement a version of
# shlog as a standalone binary, which would benefit users that want
# a fully local logging tool. Which would allow global configuration
# from $SHLOG_CONF. This version would need a build/install script.
# -----------------------------------------------------------------

# TODO: Add compatability for function loading and alias expansion to capture lineno.
LOAD_CONFIG() {
    conf="$1"
    echo "$PWD" && exit 0

    # Check if config
    [ -s "$conf" ] || exit 2

    # Setting 'IFS' tells 'read' where to split the string.
    while IFS='=' read -r key val; do
        # Skip over lines containing comments.
        [ "${key##\#*}" ] || continue

        # Skip empty lines
        [ -z "$key" ] && continue

        # Validate the key and value.
        # Warn and skip to next line if validation fails.
        case "$key" in
        LOG_MAX_SIZE) ;;
        LOG_MAX_FILES) ;;
        LOG_PATH) ;;
        LOG_FMT_PRESET) ;;
        LOG_FMT_OFFSET_DATE) ;;
        LOG_FMT_OFFSET_LABEL) ;;
        LOG_FMT_OFFSET_MESSAGE) ;;
        LOG_FMT_OFFSET_HOSTNAME) ;;
        LOG_FMT_OFFSET_SCRIPTNAME) ;;
        LOG_FMT_OFFSET_LINENO) ;;
        LOG_FMT_SYM_ENTRY) ;;
        LOG_FMT_SYM_TRACE_IN) ;;
        LOG_FMT_SYM_TRACE) ;;
        LOG_FMT_SYM_TRACE_OUT) ;;
        LOG_FMT_SYM_EXIT) ;;
        LOG_FMT_SYM_INFO) ;;
        LOG_FMT_SYM_SUCCESS) ;;
        LOG_FMT_SYM_WARNING) ;;
        LOG_FMT_SYM_ERROR) ;;
        LOG_FMT_SYM_DEBUG) ;;
        LOG_FMT_SYM_CUSTOM) ;;
        LOG_LEVEL_*) ;;
        LOG_FORMAT_*) ;;
        *)
            printf 'Warning: Invalid option `%s`\n' "$key" >&2
            continue
            ;;
        esac

        # Export the variable if validation succeeds.
        # `LOG-TRACE` would fail because it contains a hyphen
        export "$key=$val" 2>/dev/null ||
            printf 'Error: %s is not a valid variable name\n' "$key"
    done <"$1"
}

# NOTE: Boilerplate for standalone version with global configuration

# SHLOG_TEMPLATE="
# TEMPLATE GOES HERE
# "
#
# # SHLOG_CONF_DIR should be set as a global env path
# : "${SHLOG_CONF_DIR:=$HOME/.config/shlog/}"
#
# # SHLOG_CONF is the config file
# SHLOG_CONF="$SHLOG_CONF_DIR/shlog.conf"
#
# if [ ! -e "$SHLOG_CONF" ]; then
#     mkdir -p "$SHLOG_CONF_DIR"
#     printf "%s\n" "$SHLOG_TEMPLATE" > "$SHLOG_CONF"
# fi
