#!/usr/bin/env sh
# test_print_format.sh

source "$HOME/Projects/shlog/shlog.sh"


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
