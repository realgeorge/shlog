#!/bin/zsh

LOG_USE_CUSTOM_LABELS=1
. ./includes/zlog.sh

# foo LABEL "TEXT" 10						# LABELCOLOR 10,    TEXTCOLOR 10
# foo LABEL "TEXT" 10 5					# LABELCOLOR 10,    TEXTCOLOR 5
# foo LABEL "TEXT" -L 10 -T 5		# LABELCOLOR 10,    TEXTCOLOR 5
# foo LABEL "TEXT" -L 10 -T 5		# LABELCOLOR 5,     TEXTCOLOR 10
# foo LABEL "TEXT" -T 10   			# LABELCOLOR 10,    TEXTCOLOR UNSET
# foo LABEL "TEXT" -L 10				# LABELCOLOR UNSET, TEXTCOLOR 10
# foo LABEL "TEXT" -T 10 5			# LABELCOLOR 10,    TEXTCOLOR UNSET
# foo LABEL "TEXT" -L 10 5      # LABELCOLOR UNSET, TEXTCOLOR 10
# foo LABEL "TEXT" -C 10				# LABELCOLOR 10,    TEXTCOLOR 10
# foo LABEL "TEXT" -C 10 5			# LABELCOLOR 10,    TEXTCOLOR 5
# foo LABEL "TEXT" -C 5 10			# LABELCOLOR 5,     TEXTCOLOR 10


# LOG_PARSE_ARGS LABEL -t "LOG_DEBUG_COLOR" "TEXT" - "asdasdasd" -asddasdwadasd
#
# temp="LOG_PARSE_ARGS LABEL -t LOG_DEBUG_COLOR “-k” LOG_SUCCESS_COLOR"
# echo "Total length is ${#temp}"
# temp="LOG_PARSE_ARGS LABEL -t LOG_DEBUG_COLOR "
# echo "LOG_PARSE_ARGS_badopt_l_offset should be ${#temp}"
# temp="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^"
# echo "${#temp}"
# temp="LOG_SUCCESS_COLOR"
# echo "${#temp}"


# local -a testcases=(
# 	'LABEL -t 1 "MESSAGE"'
# 	'LABEL -l 2 "MESSAGE"'
# 	'LABEL -t 3 -l 4 "MESSAGE"'
# 	'LABEL LOG_WARNING_COLOR LOG_ERROR_COLOR'
# 	'-z'
# 	'-z LABEL "MESSAGE"'
# 	'LABEL -t 5 -z "MESSAGE"'
# 	'LABELONLY'
# 	'LABEL "MESSAGE" EXTRA'
# 	''
# )
#
#
# for args in "${testcases[@]}"; do
# 	echo "=== Running: LOG_PARSE_ARGS $args ==="
# 	LOG_PARSE_ARGS $args
# done


# LOG_PARSE_ARGS LABEL -l 2 "MESSAGE"
# LOG_PARSE_ARGS LABEL -t 3 -l 4 "MESSAGE"
# LOG_PARSE_ARGS LABEL LOG_WARNING_COLOR LOG_ERROR_COLOR
# LOG_PARSE_ARGS -
# LOG_PARSE_ARGS -z LABEL "MESSAGE"
# LOG_PARSE_ARGS LABEL -t 5 -z "MESSAGE"
# LOG_PARSE_ARGS LABELONLY
# LOG_PARSE_ARGS LABEL "MESSAGE" EXTRA
#
# temp="LABEL -t 5 -z"
# echo "${#temp}"



log "MY_CUSTOM_LABEL" "Hello" -l 10
