#!/bin/zsh

foo() {
  # Parse arguments passed to `log`
  LOG_PARSE_ARGS $@

	# Levels for comparing against LOG_LEVEL_STDOUT and LOG_LEVEL_LOG
	LOG_LEVEL_TRACE=0
	LOG_LEVEL_DEBUG=0
  LOG_LEVEL_CUSTOM=0
	LOG_LEVEL_INFO=1
	LOG_LEVEL_SUCCESS=2
	LOG_LEVEL_WARNING=3
  LOG_LEVEL_ERROR=4

  # Extract the log_level from the lable
  case $log_lable in
    DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE)
       log_level="$1"                             ;;
    *) log_level="CUSTOM"                         ;;
  esac
	# Validate levels since they'll be eval-ed
	case $LOG_LEVEL_STDOUT in
		DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE|CUSTOM) ;;
		*) LOG_LEVEL_STDOUT=INFO				               ;;
	esac
	case $LOG_LEVEL_LOG in
		DEBUG|INFO|SUCCESS|WARNING|ERROR|TRACE|CUSTOM) ;;
		*) LOG_LEVEL_LOG=INFO                          ;;
	esac
  # Validate custom color
  case $log_text_color in
    *[0-9]*) LOG_TEXT_COLOR="$(tput setaf $log_text_color)"         ;;
    *DEBUG*|*INFO*|*SUCCESS*|*WARNING*|*ERROR*|*TRACE*|*CUSTOM*)    ;;
    '') log_text_color="$LOG_INFO_COLOR"                            ;;
    *) 
      printf "WARNING: \`%s\` is not a valid color\n" "$log_text_color"  ;; 
  esac
  case $log_label_color in
    *[0-9]*) LOG_LABEL_COLOR="$(tput setaf $log_label_color)"       ;;
    *DEBUG*|*INFO*|*SUCCESS*|*WARNING*|*ERROR*|*TRACE*|*CUSTOM*)    ;;
    '') log_label_color="$LOG_INFO_COLOR"                           ;;
    *)
      printf "WARNING: \`%s\` is not a valid color\n" "$log_label_color" ;; 
  esac

	# Default level to info
	[ -z ${log_level} ] && log_level="INFO"
	[ -z ${log_text_color} ] && log_text_color="LOG_INFO_COLOR"
  [ -z ${log_label_color} ] && log_label_color="$log_text_color"

  # # Append label with text if --custom-labels are disabled.
  # if [ ${LOG_USE_CUSTOM_LABELS:-0} -eq 0 ]; then 
  #   log_text="$log_label $log_text"
  #   log_label=""
  # fi

	# Check LOG_LEVEL_STDOUT to see if this level of entry goes to STDOUT
	# XXX This is the horror that happens when your language doesn't have a hash data struct
	eval log_level_int="\$LOG_LEVEL_${log_level}";
	eval log_level_stdout="\$LOG_LEVEL_${LOG_LEVEL_STDOUT}";
  
	printf "[%s] %s %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "${LOG_LABEL_COLOR}$log_label${LOG_DEFAULT_COLOR}" "${LOG_TEXT_COLOR}$log_text${LOG_DEFAULT_COLOR}";
  echo "log_level: $log_level"
	echo "log_label: $log_label"
	echo "log_text: $log_text"
	echo "log_text_color: $log_text_color"
	echo "log_label_color: $log_label_color"
	echo
  return 1

	# TODO: Fixa detta sen äre klart!
  # This is where we format the different styles
	case $LOG_FORMAT_PRESET in
		# symmetric) log_prefix=$(printf "[%s]%*s" "$log_level" $((9 - ${#log_level} - 2)) "") ;;
		enhanced) log_prefix=$( [ $log_lable = "TRACE" ] && echo "[TRACE] >" || printf "[%s]%*s" "$log_level" $((9 - ${#log_level} - 2)) "" ) ;; # Width = 9 - length of log_level - 2 (for [ and ] )
		standard) log_prefix="[${log_lable}]" ;;
		classic)  log_prefix="${log_lable}:"  ;;
		*) echo "Unknown style: $LOG_FORMAT_PRESET (use: symmetric|simple|classic)" ;;
	esac

	#echo "$log_level_stdout $log_level_int"; return 1
	if [ $log_level_stdout -le $log_level_int ]; then
		# STDOUT
		printf "${log_label_color}[%s] %s ${log_text_color}%s${LOG_DEFAULT_COLOR}\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "$log_text"
	fi
	eval log_level_log="\$LOG_LEVEL_${LOG_LEVEL_LOG}"

	# Check LOG_LEVEL_LOG to see if this level of entry goes to LOG_PATH
	if [ $log_level_log -le $log_level_int ]; then
		# LOG_PATH minus fancypants colors
		if [ ! -z $LOG_PATH ]; then
			printf "[%s] %s %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$log_prefix" "${log_text}" >> $LOG_PATH;
		fi
	fi
	return 0;
}


























