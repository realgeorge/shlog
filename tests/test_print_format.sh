#!/usr/bin/env bash
# test_print_format.bash

test_logs() {
    log_info "info message"
    log_success "success message"
    log_warning "warning message"
    log_error "error message"
    log_debug "debug message"
    log_trace "trace message"
    log_trace_in "trace_in message"
    log_trace_out "trace_out message"
    SCRIPTENTRY "entry message"
    SCRIPTEXIT "exit message"
}

# 1. Environment Setup
export INTERACTIVE_MODE="off"
source ./shlog.sh
# 2. Deterministic Mock Variables
export log_date_format="2026-02-22 01:24:57"
export LOG_DEFAULT_COLOR=""
export log_date_color=""
export log_label_color=""
export log_text_color=""
export SCRIPT_NAME="app.py"
export log_level="INFO"
export log_label="INFO"
export log_text="User logged in successfully."

MOCK_LINE="42"

# 3. Test Runner State
PASSED=0
FAILED=0
TOTAL=0

GREEN=$'\e[32m'
RED=$'\e[31m'
RESET=$'\e[0m'

# 4. Preset Definitions
# Stride: "Test Name" "Format String" "Expected Output String"
declare -a TESTS=(
    "JSON_Standard"
    '{"time":"%date","lvl":"%label","host":"%hostname","file":"%scriptname","line":%lineno,"msg":"%message"}'
    '{"time":"2026-02-22 01:24:57","lvl":"INFO","host":"fedora","file":"app.py","line":42,"msg":"User logged in successfully."}'

    "JSON_Elasticsearch"
    '{"@timestamp":"%date","log.level":"%label","host.name":"%hostname","message":"%message"}'
    '{"@timestamp":"2026-02-22 01:24:57","log.level":"INFO","host.name":"fedora","message":"User logged in successfully."}'

    "Systemd_Syslog"
    '%date %hostname %scriptname[%lineno]: [%label] %message'
    '2026-02-22 01:24:57 fedora app.py[42]: [INFO] User logged in successfully.'

    "Logfmt"
    'ts="%date" level=%label host=%hostname caller=%scriptname:%lineno msg="%message"'
    'ts="2026-02-22 01:24:57" level=INFO host=fedora caller=app.py:42 msg="User logged in successfully."'

    "Python_Logging_Default"
    '%label:%scriptname:%message'
    'INFO:app.py:User logged in successfully.'

    "Log4j_PatternLayout"
    '%date [%hostname] %label@-5 - %message'
    '2026-02-22 01:24:57 [fedora] INFO  - User logged in successfully.'

    "Go_Zap_Console"
    '%date	%label	%scriptname:%lineno	%message'
    '2026-02-22 01:24:57	INFO	app.py:42	User logged in successfully.'

    "Apache_Error_Log"
    '[%date] [%label] [pid %lineno] [client 127.0.0.1] %message'
    '[2026-02-22 01:24:57] [INFO] [pid 42] [client 127.0.0.1] User logged in successfully.'

    "NGINX_Error_Log"
    '%date [%label] %lineno#0: *1 %message, client: 127.0.0.1, server: localhost'
    '2026-02-22 01:24:57 [INFO] 42#0: *1 User logged in successfully., client: 127.0.0.1, server: localhost'

    "RFC5424_Syslog"
    '<165>1 %date %hostname %scriptname %lineno - - %message'
    '<165>1 2026-02-22 01:24:57 fedora app.py 42 - - User logged in successfully.'

    "GitHub_Actions_Command"
    '::%label file=%scriptname,line=%lineno::%message'
    '::INFO file=app.py,line=42::User logged in successfully.'
)

# 5. Pytest-style Execution
printf "============================= test session starts ==============================\n"
printf "collected %d items\n\n" "$((${#TESTS[@]} / 3))"

for ((i = 0; i < ${#TESTS[@]}; i += 3)); do
    name="${TESTS[i]}"
    fmt="${TESTS[i + 1]}"
    expected="${TESTS[i + 2]}"

    TOTAL=$((TOTAL + 1))

    # Execute the internal function directly to securely inject the mock line number
    actual=$(_log_print "$MOCK_LINE" "$fmt")

    if [[ "$actual" == "$expected" ]]; then
        printf "%sPASSED%s test_%s\n" "$GREEN" "$RESET" "$name"
        PASSED=$((PASSED + 1))
    else
        printf "%sFAILED%s test_%s\n" "$RED" "$RESET" "$name"
        printf "    Format:   %s\n" "$fmt"
        printf "    Expected: %s\n" "$expected"
        printf "    Actual:   %s\n" "$actual"
        FAILED=$((FAILED + 1))
    fi
done

# 6. Summary Report
printf "\n=========================== short test summary info ============================\n"
if [[ $FAILED -eq 0 ]]; then
    printf "%s%d passed in 0.01s%s\n" "$GREEN" "$PASSED" "$RESET"
    . shlog.sh
    for ((i = 0; i < ${#TESTS[@]}; i += 3)); do
        name="${TESTS[i]}"
        fmt="${TESTS[i + 1]}"
        LOG_FORMAT="$fmt"
        echo "Format: $name"
        test_logs
    done

    exit 0
else
    printf "%s%d failed, %d passed in 0.01s%s\n" "$RED" "$FAILED" "$PASSED" "$RESET"
    exit 1
fi
