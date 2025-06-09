
# TODO: Add VERY SIMPLE parsing for source ./zlog.sh [options]
# Options:
#		Extensions:
#			zsh  -> explicitly set $SCRIPT_EXTENSION="zsh"
#			bash -> explicitly set $SCRIPT_EXTENSION="bash"
#			sh   -> explicitly set $SCRIPT_EXTENSION="sh"
#		Style:
#			symmetrical -> explicitly set $LOG_FORMAT_PRESET="symmetrical"
#			simple/basic/boring -> explicitly set $LOG_FORMAT_PRESET="simple"
#		Defaults: (Fallback if specific option is not provided)
#			SCRIPT_EXTENSION=$(ps -p "$$" -o comm=)
#			SCRIPT_EXTENSION="${SCRIPT_EXTENSION##*.}"
#			$LOG_FORMAT_PRESET="symmetrical"

while [ $# -gt 0 ]; do
	case "$1" in
	sh|zsh|bash) SCRIPT_EXTENSION=$1; shift      ;;
	symmetrical|simple) LOG_PRESET_FORMAT; shift ;;
	*) echo "Unknown option $1" >&2; shift			 ;;
esac
