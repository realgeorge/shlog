#!/bin/zsh

LOG_USE_CUSTOM_LABELS=0
. ./includes/zlog.sh

log "LABEL" "TEXT" 1 2 3
# log foo -- bar baz
# log foo --- bar baz
# log foo --  bar baz
# log foo -  bar baz
# log foo - * bar baz
# log foo -- * bar baz
# log foo -x bar baz
# log foo --x bar baz
# log foo ---x bar baz
# log foo - -  bar baz
# log foo -- * * bar baz
# log foo --* - bar baz
# log foo x- bar baz
# log foo *- bar baz
# log foo ---* bar baz
# log foo --x  bar baz
# log foo -*x bar baz
# log foo * bar baz
# log foo bar baz

























# LOG_PARSE_ARGS MY_5th_LABEL 10 LOG_WARNING_COLOR 9 "1TEXT" "EXTRA" "EXTRA2" "EXTRA3"
#
#
#
#
#
# 	# Parse args for log function call
# 	while [ "$#" -gt 0 ]; do
# 		case "$1" in
# 			-h|--help)
# 				# TODO
# 				;;
#
# 			-t|-T)
# 				# Handle text color flag
# 				text_flag=1
# 				log_add_kwargs "$1" "$2"
#
# 				[ -n "$2" ] && log_text_color=$2
# 				[ -z "$2" ] && log_badopt="$1" && return 1
# 				shift 2
# 				continue
# 				;;
#
# 			-l|-L)
# 				# Handle label color flag
# 				label_flag=1
# 				log_add_kwargs "$1" "$2"
#
# 				[ -n "$2" ] && log_label_color=$2
# 				[ -z "$2" ] && badopt "$1" 
# 				shift 2
# 				continue
# 				;;
#
# 			*[0-9]*|LOG_*_COLOR)
# 				# Handle direct color codes or env color vars
# 				log_add_args "$1"
#
# 				[ -z "$log_label_color" ] && log_label_color=$1 && shift && continue
# 				[ -z "$log_text_color" ] && log_text_color=$1 && shift && continue
# 				;;
#
# 			-*)
# 				log_add_kwargs "$1" "$2"
#
# 				log_badopt=${log_badopt:-$1}
# 				log_badopt_offset="${log_badopt_offset:-$((${#log_args} - ${#2} + ${#1}))}"
# 				shift
# 				continue
# 				;;
#
# 			*)
# 				log_add_args "$1"
#
# 				log_label="${log_label:-$1}"
# 				log_text="${log_text:-$2}"
# 				shift 2
#
# 				while [ -n "$1" ]; do
# 					log_extra="${log_extra:+$log_extra }$1"
# 					shift
# 				done
#
# 				continue
# 				;;
# 		esac
# 		shift
# 	done

