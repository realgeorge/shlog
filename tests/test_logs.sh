source "$HOME/Projects/shlog/shlog.sh"

test_logs() {
    log_info "info message"
    log_success "success message"
    log_warning "warning message"
    log_error "error message"
    log_debug "debug message"
    log_trace "trace message"
    log_trace_in "trace_in message"
    log_trace_out "trace_out message"
    log_entry "entry message"
    log_exit "exit message"
}

test_logs
