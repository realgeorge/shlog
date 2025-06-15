# test_cases=(
# 	' H' # 1
# 	'   ' # 2...
#   '-' # 1
#   '--' # 2
# 	'---*' # 3...
# 	# Normal flags
# 	'-' # 1
# 	'-o' # 1
# 	'-op' # 2
# 	'-opt' # 3...
# 	# Long flags
# 	'--' # 2 )
#   '--l' # 1
# 	'--lo' # 2
# 	'--lon' # 3
# 	'--long' # 4...
# 	# Long flags with dashes inside
# 	'--long-' # 5
# 	'--long-f' # 6
# 	'--long-fl' # 7
# 	'--long-fla' # 8
# 	'--long-flag' # 9...
# 	# ... All the way to
# 	'--long-flag-with-many-dashes-inside' # 33
# 	's' # 1
#   'su' # 2
#   'sub' # 3
#   'subs' # 4
#   'subst' # 5
#   'substr' # 6
#   'substri' # 7
#   'substrin' # 8
#   'substring' # 9
# )
# for case in "${test_cases[@]}"; do
# 	match_length "${case:+""$case""}"
# done

# LOG_PARSE_OPTERR2 "-"        'foo LABEL TEXT "-"'
# LOG_PARSE_OPTERR2 "--"       'foo LABEL TEXT "--"'
# LOG_PARSE_OPTERR2 "---"      'foo LABEL TEXT "---"'
# LOG_PARSE_OPTERR2 "-- "      'foo LABEL TEXT "-- "'
# LOG_PARSE_OPTERR2 "- "       'foo LABEL TEXT "- "'
# LOG_PARSE_OPTERR2 "- *"      'foo LABEL TEXT "- *"'
# LOG_PARSE_OPTERR2 "-- *"     'foo LABEL TEXT "-- *"'
# LOG_PARSE_OPTERR2 "-x"       'foo LABEL TEXT "-x"'
# LOG_PARSE_OPTERR2 "--x"      'foo LABEL TEXT "--x"'
# LOG_PARSE_OPTERR2 "---x"     'foo LABEL TEXT "---x"'
# LOG_PARSE_OPTERR2 "- - "     'foo LABEL TEXT "- - "'
# LOG_PARSE_OPTERR2 "- * *"    'foo LABEL TEXT "-- * *"'
# LOG_PARSE_OPTERR2 "--* *"    'foo LABEL TEXT "--* *"'
# LOG_PARSE_OPTERR2 "x-"       'foo LABEL TEXT "x-"'
# LOG_PARSE_OPTERR2 "*-"       'foo LABEL TEXT "*-"'
# LOG_PARSE_OPTERR2 "---*"     'foo LABEL TEXT "---*"'
# LOG_PARSE_OPTERR2 "--x "     'foo LABEL TEXT "--x "'
# LOG_PARSE_OPTERR2 "-*x"      'foo LABEL TEXT "-*x"'
# LOG_PARSE_OPTERR2 "*"        'foo LABEL TEXT "*"'
# LOG_PARSE_OPTERR2 ""         'foo LABEL TEXT ""'

