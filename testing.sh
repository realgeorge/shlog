foo() {
	while [ "$#" -gt 0 ]; do
		case "$1" in 
			''|*[0-9]*|LOG_*_COLOR)
				[ -z "$log_text_color" ] && log_text_color=$1 && shift && continue
				[ -z "$log_label_color" ] && log_label_color=$1 && shift && continue
				;;

			*)
				[ -z "$log_label" ] && log_label=$1 && shift && continue
				[ -z "$log_text" ] && log_text=$1 && shift && continue
				;;
		esac
		shift
	done

	echo "log_level: $log_level"
	echo "log_label: $log_label"
	echo "log_text: $log_text"
	echo "log_text_color: $log_text_color"
	echo "log_label_color: $log_label_color"
	echo
}


#bar LABEL/LEVEL "MESSAGE" "TEXTCOLOR" "LABELCOLOR" 
#bar "MESSAGE" "TEXTCOLOR"

foo LOG_DEFAULT_COLOR 1 LOG_CUSTOM_COLOR "LABEL" "TEXT"

