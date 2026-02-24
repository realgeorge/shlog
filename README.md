# shlog

**shlog** is a lightweight, shell-agnostic logging utility designed for Zsh, Bash and Sh. It provides a simple source integration to add structured logging to your scripts. It handles dual-stream output automatically: printing colored, formatted logs to STDOUT while simultaneously writing clean, ANSI-stripped logs to a file based on configurable severity levels.

## Installation

You can clone the repository directly into your project.

```bash
git clone --depth 1 https://github.com/realgeorge/shlog
```

## Mechanism

shlog operates by detecting the active shell environment (Zsh, Bash, or Sh) upon sourcing. It establishes a master `log` function that dynamically evaluates log levels and formatting preferences.

When a log function is called, shlog:

1. Checks the severity against the defined `LOG_LEVEL_STDOUT` treshhold.
2. If passable, formats the string with ANSI colors and prints to the terminal.
3. Checks the severity against the `LOG_LEVEL_LOG` treshhold.
4. If passable, strips all ANSI codes and appends the clean text to the file defined in `LOG_PATH`.

## Usage

Place `shlog.sh` in your project directory and source it within your script. You can define configuration variables before sourcing to override defaults.

```bash
#!/usr/bin/env zsh

# Configuration (Optional)
LOG_PATH="/var/log/myscript.log"
LOG_LEVEL_STDOUT="INFO"

# Import
source ./path/to/shlog.sh

# Usage
log_info "Starting process..."
```

## Configuration

The following variables control the behavior of shlog. Define them before sourcing the script.

| Variable | Default | Description |
| :--- | :--- | :--- |
| `LOG_PATH` | `./shlog.log` | File path for the stripped log output. |
| `LOG_LEVEL_DEFAULT` | `DEBUG` | The default log level assigned if none is provided. |
| `LOG_LEVEL_STDOUT` | `DEBUG` | Minimum severity level required to print to terminal. |
| `LOG_LEVEL_LOG` | `DEBUG` | Minimum severity level required to write to file. |
| `LOG_USE_CUSTOM_LABELS` | `on` | If set to `off`, custom labels will be treated as `INFO`. |
| `LOG_FORMAT_PRESET` | `enhanced` | Visual style (`enhanced`, `standard`, `classic`). |

## API

### Standard functions

These wrappers utilize the predefined colors and standard log levels.

```bash
log_info "message"
log_success "message"
log_warning "message"
log_error "message"
log_debug "message"
```

### Tracing

```bash
log_trace_in "message"
log_trace_out "message"
```

## Custom logging

You can invoke the `log` function directly to create custom log labels using the following syntax:

```bash
log LABEL "message" COLOR
```

#### Example

```bash
# Define a custom color (Cyan)
LOG_CUSTOM_COLOR="$(tput setaf 6)"

# Log with custom label
log "DATABASE" "Connection Established" "LOG_CUSTOM_COLOR"
# Output: [YYYY-MM-DD HH-M-S] [DATABASE] Connection established (in cyan)
```

## Reference

### Predefined colors

|Global variable    |Integer|ANSI Color Code|
|-------------------|-------|----------------|
|`LOG_INFO_COLOR`   |0      |Default         |
|`LOG_ERROR_COLOR`  |1      |Red             |
|`LOG_SUCCESS_COLOR`|2      |Green           |
|`LOG_WARNING_COLOR`|3      |Yellow          |
|`LOG_DEBUG_COLOR`  |4      |Magenta         |
|`LOG_TRACE_COLOR`  |8      |Grey            |
|`LOG_CUSTOM_COLOR` |(default 69)      |User defined    |

## Predefined styles

Controlled by `LOG_FORMAT_PRESET` (default: enhanced)

```
-----------------------Style: standard-----------------------
[2026-02-18 15:23:45] [TRACE] > print_styles:4 (Here we enter) 
[2026-02-18 15:23:45] [info] This is warning
[2026-02-18 15:23:45] [success] This is success
[2026-02-18 15:23:45] [warning] This is warning
[2026-02-18 15:23:45] [error] This is error
[2026-02-18 15:23:45] [debug] This is debug
[2026-02-18 15:23:45] [custom] This is custom
[2026-02-18 15:23:45] [TRACE] < print_styles:4 (Here we exit) 
-----------------------Style: enhanced-----------------------
[2026-02-18 15:23:45] [TRACE] > print_styles:4 (Here we enter) 
[2026-02-18 15:23:45] [info]    This is warning
[2026-02-18 15:23:45] [success] This is success
[2026-02-18 15:23:45] [warning] This is warning
[2026-02-18 15:23:45] [error]   This is error
[2026-02-18 15:23:45] [debug]   This is debug
[2026-02-18 15:23:45] [custom]  This is custom
[2026-02-18 15:23:45] [TRACE] < print_styles:4 (Here we exit) 
-----------------------Style: classic-----------------------
[2026-02-18 15:23:45] TRACE: > print_styles:4 (Here we enter) 
[2026-02-18 15:23:45] info: This is warning
[2026-02-18 15:23:45] success: This is success
[2026-02-18 15:23:45] warning: This is warning
[2026-02-18 15:23:45] error: This is error
[2026-02-18 15:23:45] debug: This is debug
[2026-02-18 15:23:45] custom: This is custom
[2026-02-18 15:23:45] TRACE: < print_styles:4 (Here we exit) 
-------------------------------------------------------
```

## TODO

* [ ] **POSIX Compliance:** Ensure strictly POSIX-compliant syntax (remove `local` keyword in `sh` blocks).
* [ ] **Custom Level Logic:** Review `LOG_LEVEL_CUSTOM` integer logic. Currently, custom labels are treated as level 0 (Debug), meaning they are hidden if `LOG_LEVEL_STDOUT` is set to `INFO`.
* [ ] **Config Loading:** Refine `--load-config` and `--save-config` flags for better stability.

## Credits

**shlog** is heavily inspired by and based on logic from [slog](https://github.com/swelljoe/slog) by Fred Palmer and Joe Cooper.

|Option|Appended printf string|Appended output value|Comment|
|-|-|-|-|
|c|`%s`|`$(tput sgr0)`|TODO: Determine a good name for this option|
|c\[1-255\]|`%s`|`$(tput setaf [0-255]`|Color must be uint8|
|date|`%s`|`$(date +"$LOG_DATE_FORMAT")`|Date format string. Defined with  `$LOG_DATE_FORMAT`|
|label|`%s`|`$_lbl`|Displays log label. Padding offsets defined with: `$LOG_FMT_OFFSET_<LABEL/LEVEL>`|
|message|`%s`|`$_msg`|Displays log message|
|hostname|`%s`|`$HOSTNAME`|Invoker hostname|
|filename|`%s`|`$SCRIPT_NAME`|Invoker scriptname|
|lineno|`%s`|`$_caller_lineno`|Displays the linenumber where a log is called. Compatibilty across multiple POSIX shells resolved with alias expansion `log_func='_caller_lineno=$LINENO log_func'`|
|level_int|`%s`|`$_lvl_int`| Dynamically evaluated level integer <br>TODO: Should append `%d`|
|sym|`%s`|`$_sym`| Dynamically evaluated label symbol. Define `$LOG_FMT_SYM_<LABEL>`|
|log_path|`%s`|`$`|Log output path. Defined with `$LOG_PATH`|
|path|`%s`|`$`|TODO|
|pwd|`%s`|`$`|TODO|
|{\<raw text\>}|`%s`|`raw text`|Paddable raw text<br>OPTIMIZE|


|Modifiers|Appended to printf string|Example|
|-|-|-|
|@\[padding\]|`%[padding]s`|`%label@-3` would append `%-3s`|
|@|`%[dynamic_padding]s`|IDEA: Could leave as is and use `?` instead. It makes much more sence that you have to specify the longest expected length of a string to do automatic alignment|
|?||Idea: Set the longest offset length, something like `%label?7` would set `LOG_FMT_OFFSET_LABEL=7`, i.e. the longest expected label is 7 characters long but can functionally behave the same as only `@`|

