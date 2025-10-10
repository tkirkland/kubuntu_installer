# Google Shell Style Guide - Comprehensive Documentation

## Table of Contents

1. [Introduction](#introduction)
2. [Background & Philosophy](#background--philosophy)
3. [File Structure & Organization](#file-structure--organization)
4. [Formatting Standards](#formatting-standards)
5. [Shell Features & Best Practices](#shell-features--best-practices)
6. [Naming Conventions](#naming-conventions)
7. [Error Handling & Command Execution](#error-handling--command-execution)
8. [Code Examples & Patterns](#code-examples--patterns)
9. [Quick Reference](#quick-reference)
10. [Common Pitfalls & Solutions](#common-pitfalls--solutions)

---

## Introduction

This document provides a comprehensive guide to the Google Shell Style Guide, which establishes standards for writing maintainable, reliable, and consistent shell scripts. The guide is maintained by Google engineers and has become a de facto standard for shell scripting in many organizations.

### Key Principles

- **Bash Only**: Use Bash as the only shell scripting language for executables
- **Simplicity First**: Shell scripts should be simple utilities or wrappers
- **Readability Matters**: Code should be clear and maintainable by others
- **Consistency is Key**: Follow established patterns throughout the codebase

---

## Background & Philosophy

### Which Shell to Use

**Rule**: Bash is the only permitted shell scripting language for executables.

```bash
#!/bin/bash
# Always use this shebang line for executables
```

**Rationale**: 
- Provides consistent shell language across all systems
- No need to strive for POSIX-compatibility
- Bashisms are acceptable and often preferred

### When to Use Shell

**Guidelines for appropriate shell usage:**

✅ **Use Shell When:**
- Calling other utilities with minimal data manipulation
- Writing simple wrapper scripts
- Creating small utilities (< 100 lines)
- Performing straightforward system tasks

❌ **Avoid Shell When:**
- Performance is critical
- Complex control flow is needed
- Script exceeds 100 lines
- Complex data structures are required
- Code maintainability becomes questionable

---

## File Structure & Organization

### File Extensions

| File Type | Extension | Example | Notes |
|-----------|-----------|---------|-------|
| Executable with build rule | `.sh` | `deploy.sh` → `deploy` | Source has extension, built artifact doesn't |
| Direct PATH executable | No extension | `mytool` | Users don't need to know implementation language |
| Library | `.sh` (required) | `utils.sh` | Must not be executable |

### SUID/SGID

**Rule**: SUID and SGID are **FORBIDDEN** on shell scripts.

```bash
# NEVER DO THIS
chmod +s script.sh  # Security vulnerability!

# Instead, use sudo for elevated access
sudo ./script.sh
```

### File Header Template

```bash
#!/bin/bash
#
# Script: backup_manager.sh
# Purpose: Perform incremental backups of critical system files
# Author: John Doe (jdoe@example.com)
# Date: 2024-01-15
# Version: 1.0.0
#
# Usage: ./backup_manager.sh [options]
#   -d DIRECTORY  Backup directory path
#   -v            Verbose output
#   -h            Show help message
```

### Function Organization

```bash
#!/bin/bash

# 1. Shebang line (first)
# 2. File header comment
# 3. Global constants and variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# 4. Function definitions (all together)
function validate_input() {
  # Function implementation
}

function process_data() {
  # Function implementation
}

# 5. Main function (if needed)
function main() {
  validate_input "$@"
  process_data
}

# 6. Script execution (last line)
main "$@"
```

---

## Formatting Standards

### Indentation

**Rule**: 2 spaces, NO TABS

```bash
# Correct: 2-space indentation
function process_files() {
  local file
  for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
      echo "Processing: ${file}"
    fi
  done
}

# Exception: Heredocs with tab indentation
cat <<-EOF
	This heredoc uses tabs for indentation
	which will be stripped from output
EOF
```

### Line Length

**Rule**: Maximum 80 characters per line

```bash
# Long strings - use heredocs
cat <<END
This is an exceptionally long string that would exceed 
the 80 character limit if written on a single line
END

# Long strings - use line continuation
long_message="This is a very long message that needs to be \
split across multiple lines for better readability and to \
comply with the 80 character line limit"

# Long file paths - keep on single line when beneficial
readonly LONG_PATH="/usr/local/share/applications/very/long/path/to/important/file.conf"

# Complex commands - use backslash continuation
find /var/log \
  -type f \
  -name "*.log" \
  -mtime +30 \
  -exec rm {} \;
```

### Pipelines

```bash
# Short pipeline - single line
ps aux | grep nginx | wc -l

# Long pipeline - one command per line
cat /var/log/syslog \
  | grep "ERROR" \
  | sed 's/^.*ERROR: //' \
  | sort \
  | uniq -c \
  | sort -rn
```

### Control Flow Formatting

```bash
# if statement
if [[ -f "${config_file}" ]]; then
  load_config
else
  create_default_config
fi

# for loop
for server in "${servers[@]}"; do
  ping -c 1 "${server}" || log_error "Server ${server} unreachable"
done

# while loop
while read -r line; do
  process_line "${line}"
done < input.txt

# case statement
case "${action}" in
  start)
    start_service
    ;;
  stop)
    stop_service
    ;;
  restart)
    stop_service
    start_service
    ;;
  *)
    echo "Unknown action: ${action}" >&2
    exit 1
    ;;
esac
```

---

## Shell Features & Best Practices

### Variable Usage

#### Quoting Rules

```bash
# ALWAYS quote variables
name="John Doe"
echo "Hello, ${name}"  # Correct
echo Hello, $name      # Wrong - will break with spaces

# Quote command substitutions
current_dir="$(pwd)"   # Correct
current_dir=$(pwd)     # Wrong - can break with special characters

# Arrays require special quoting
files=("file 1.txt" "file 2.txt")
process_files "${files[@]}"  # Correct - preserves array elements
process_files ${files[@]}    # Wrong - will word-split

# Exception: Integer comparisons
count=5
if (( count > 3 )); then  # No quotes needed for arithmetic
  echo "Count is large"
fi
```

#### Variable Expansion

```bash
# Preferred: Use braces for clarity
echo "PATH=${PATH}, USER=${USER}"

# Special variables: No braces needed
echo "Args: $1 $2 $3"
echo "Count: $#, PID: $$, Exit: $?"

# When braces are required
echo "${10}"  # For positional parameters > 9
echo "${var}suffix"  # When followed by valid variable characters
```

### Command Substitution

```bash
# Modern syntax - use $()
result="$(command)"
nested="$(echo "$(date)")"

# Legacy syntax - avoid backticks
result=`command`  # Don't use this
nested=`echo \`date\``  # Especially avoid nested backticks
```

### Test Conditions

```bash
# Use [[ ]] for tests (preferred)
if [[ -f "${file}" ]]; then
  echo "File exists"
fi

# String comparisons
if [[ "${var}" == "value" ]]; then  # Use == for clarity
  echo "Match"
fi

# Pattern matching (unquoted on right side)
if [[ "${filename}" =~ ^[a-z]+\.txt$ ]]; then
  echo "Valid filename"
fi

# Numeric comparisons
if (( num > 10 )); then  # Use (( )) for arithmetic
  echo "Greater than 10"
fi

# Check for empty/non-empty
if [[ -z "${var}" ]]; then  # Explicitly check for empty
  echo "Variable is empty"
fi

if [[ -n "${var}" ]]; then  # Explicitly check for non-empty
  echo "Variable has content"
fi
```

### Arrays

```bash
# Declare arrays
declare -a my_array
my_array=("element1" "element2" "element with spaces")

# Append to arrays
my_array+=("new element")

# Access arrays
echo "${my_array[0]}"        # First element
echo "${my_array[@]}"        # All elements as separate words
echo "${#my_array[@]}"       # Number of elements

# Iterate over arrays
for element in "${my_array[@]}"; do
  echo "Processing: ${element}"
done

# Pass arrays to functions
function process_array() {
  local items=("$@")
  for item in "${items[@]}"; do
    echo "Item: ${item}"
  done
}
process_array "${my_array[@]}"
```

### Process Substitution

```bash
# Avoid pipes to while (creates subshell)
# BAD: Variables modified in the loop won't persist
cat file.txt | while read -r line; do
  last_line="${line}"  # This won't work as expected
done
echo "${last_line}"  # Will be empty!

# GOOD: Use process substitution
while read -r line; do
  last_line="${line}"  # This works correctly
done < <(cat file.txt)
echo "${last_line}"  # Contains the actual last line

# Alternative: Use readarray (Bash 4+)
readarray -t lines < file.txt
for line in "${lines[@]}"; do
  process_line "${line}"
done
```

### Arithmetic

```bash
# Use (( )) for arithmetic
result=$(( 5 + 3 ))
(( counter++ ))
(( total += value ))

# Arithmetic comparisons
if (( x > y )); then
  echo "x is greater"
fi

# Avoid deprecated forms
result=$[ 5 + 3 ]     # Don't use
result=$(expr 5 + 3)  # Don't use
let result=5+3        # Don't use
```

---

## Naming Conventions

### Functions

```bash
# Lowercase with underscores
function process_data() {
  local input="$1"
  # Implementation
}

# Package functions use ::
function mylib::initialize() {
  # Implementation
}

# Consistent style (choose one per project)
function my_function() { ... }  # With 'function' keyword
my_function() { ... }           # Without keyword (also valid)
```

### Variables

```bash
# Local variables: lowercase with underscores
local file_count=0
local temp_dir="/tmp/processing"

# Global variables: lowercase with underscores
script_version="1.0.0"

# Constants: UPPERCASE with underscores
readonly MAX_RETRIES=3
readonly DEFAULT_TIMEOUT=30

# Environment variables: UPPERCASE
export PATH_TO_DATA="/data"
declare -xr ORACLE_HOME="/opt/oracle"

# Loop variables: descriptive names
for user in "${users[@]}"; do
  process_user "${user}"
done
```

### Using Local Variables

```bash
# CORRECT: Separate declaration and assignment for command substitution
function get_data() {
  local result
  result="$(complex_command)"
  if (( $? != 0 )); then
    return 1
  fi
  echo "${result}"
}

# WRONG: Combined declaration masks exit code
function get_data() {
  local result="$(complex_command)"  # $? will always be 0 (from 'local')
  if (( $? != 0 )); then  # This will never trigger!
    return 1
  fi
}
```

---

## Error Handling & Command Execution

### Error Messages to STDERR

```bash
# Define error function
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

# Use it throughout the script
if ! command; then
  err "Command failed"
  exit 1
fi
```

### Checking Return Values

```bash
# Method 1: Direct check with if
if ! cp "${source}" "${dest}"; then
  err "Failed to copy ${source} to ${dest}"
  exit 1
fi

# Method 2: Check $? explicitly
mv "${old}" "${new}"
if (( $? != 0 )); then
  err "Failed to move ${old} to ${new}"
  exit 1
fi

# Method 3: Using || for simple cases
mkdir -p "${dir}" || exit 1

# Checking pipeline status
tar -czf - "${source_dir}" | ssh user@host "tar -xzf - -C ${dest_dir}"
if (( PIPESTATUS[0] != 0 )); then
  err "Tar command failed"
elif (( PIPESTATUS[1] != 0 )); then
  err "SSH command failed"
fi
```

### Function Comments

```bash
#######################################
# Download and validate a file from URL
# Globals:
#   DOWNLOAD_DIR
#   MAX_RETRIES
# Arguments:
#   $1 - URL to download
#   $2 - Expected SHA256 checksum
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   Downloaded filename to stdout
#######################################
function download_and_validate() {
  local url="$1"
  local expected_checksum="$2"
  local filename
  
  filename="${DOWNLOAD_DIR}/$(basename "${url}")"
  
  # Download with retries
  local attempts=0
  while (( attempts < MAX_RETRIES )); do
    if wget -q -O "${filename}" "${url}"; then
      break
    fi
    (( attempts++ ))
    sleep 5
  done
  
  # Validate checksum
  local actual_checksum
  actual_checksum="$(sha256sum "${filename}" | cut -d' ' -f1)"
  
  if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
    err "Checksum mismatch for ${filename}"
    rm -f "${filename}"
    return 1
  fi
  
  echo "${filename}"
  return 0
}
```

---

## Code Examples & Patterns

### Complete Script Template

```bash
#!/bin/bash
#
# Script: service_monitor.sh
# Purpose: Monitor system services and restart if needed
# Author: DevOps Team
# Version: 2.0.0

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Global constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/${SCRIPT_NAME%.sh}.log"
readonly PID_FILE="/var/run/${SCRIPT_NAME%.sh}.pid"

# Configuration
readonly SERVICES=("nginx" "mysql" "redis")
readonly CHECK_INTERVAL=60
readonly MAX_RESTART_ATTEMPTS=3

# Global variables
declare -i restart_count=0

#######################################
# Print error message to STDERR and log
# Arguments:
#   Error message string
#######################################
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] ERROR: $*" | tee -a "${LOG_FILE}" >&2
}

#######################################
# Print info message to log
# Arguments:
#   Info message string
#######################################
info() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] INFO: $*" >> "${LOG_FILE}"
}

#######################################
# Check if service is running
# Arguments:
#   Service name
# Returns:
#   0 if running, 1 if not
#######################################
check_service() {
  local service="$1"
  systemctl is-active --quiet "${service}"
}

#######################################
# Restart a service
# Arguments:
#   Service name
# Returns:
#   0 on success, 1 on failure
#######################################
restart_service() {
  local service="$1"
  
  info "Attempting to restart ${service}"
  
  if systemctl restart "${service}"; then
    info "Successfully restarted ${service}"
    return 0
  else
    err "Failed to restart ${service}"
    return 1
  fi
}

#######################################
# Monitor and restart services
# Globals:
#   SERVICES
#   MAX_RESTART_ATTEMPTS
#   restart_count
#######################################
monitor_services() {
  local service
  local -A restart_attempts
  
  for service in "${SERVICES[@]}"; do
    restart_attempts["${service}"]=0
  done
  
  while true; do
    for service in "${SERVICES[@]}"; do
      if ! check_service "${service}"; then
        err "Service ${service} is not running"
        
        if (( restart_attempts["${service}"] < MAX_RESTART_ATTEMPTS )); then
          if restart_service "${service}"; then
            restart_attempts["${service}"]=0
            (( restart_count++ ))
          else
            (( restart_attempts["${service}"]++ ))
          fi
        else
          err "Max restart attempts reached for ${service}"
        fi
      fi
    done
    
    sleep "${CHECK_INTERVAL}"
  done
}

#######################################
# Setup signal handlers
#######################################
setup_signals() {
  trap 'cleanup' EXIT
  trap 'info "Received SIGTERM"; exit 0' TERM
  trap 'info "Received SIGINT"; exit 0' INT
}

#######################################
# Cleanup on exit
#######################################
cleanup() {
  info "Cleaning up..."
  rm -f "${PID_FILE}"
}

#######################################
# Main function
#######################################
main() {
  # Check if already running
  if [[ -f "${PID_FILE}" ]]; then
    local old_pid
    old_pid="$(cat "${PID_FILE}")"
    if kill -0 "${old_pid}" 2>/dev/null; then
      err "Already running with PID ${old_pid}"
      exit 1
    fi
    rm -f "${PID_FILE}"
  fi
  
  # Write PID file
  echo $$ > "${PID_FILE}"
  
  # Setup
  setup_signals
  info "Starting ${SCRIPT_NAME}"
  
  # Main loop
  monitor_services
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

### Common Patterns

#### Safe Script Options

```bash
#!/bin/bash
set -euo pipefail  # Recommended for most scripts
# -e: Exit on command failure
# -u: Exit on undefined variable
# -o pipefail: Exit on pipe failure

# For debugging
set -x  # Print commands as they execute
```

#### Argument Parsing

```bash
function usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  -h, --help        Show this help message
  -v, --verbose     Enable verbose output
  -f, --file FILE   Input file path
  -o, --output DIR  Output directory
  
Examples:
  ${SCRIPT_NAME} -f input.txt -o /tmp/output
  ${SCRIPT_NAME} --verbose --file data.csv
EOF
}

# Parse arguments
verbose=false
input_file=""
output_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--verbose)
      verbose=true
      shift
      ;;
    -f|--file)
      input_file="$2"
      shift 2
      ;;
    -o|--output)
      output_dir="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

# Validate required arguments
if [[ -z "${input_file}" ]]; then
  err "Input file is required"
  usage
  exit 1
fi
```

#### Configuration Files

```bash
# config.conf
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="myapp"
DB_USER="appuser"

# Loading configuration
function load_config() {
  local config_file="$1"
  
  if [[ ! -f "${config_file}" ]]; then
    err "Configuration file not found: ${config_file}"
    return 1
  fi
  
  # Source configuration safely
  # shellcheck source=/dev/null
  source "${config_file}"
}
```

---

## Quick Reference

### Do's and Don'ts

| Topic | ✅ DO | ❌ DON'T |
|-------|-------|----------|
| **Shell** | Use `#!/bin/bash` | Use `#!/bin/sh` or other shells |
| **Variables** | Quote all variables: `"${var}"` | Leave unquoted: `$var` |
| **Tests** | Use `[[ ]]` | Use `[ ]` or `test` |
| **Command Substitution** | Use `$(command)` | Use `` `command` `` |
| **Arithmetic** | Use `$(( ))` or `(( ))` | Use `expr` or `let` |
| **Arrays** | Use `"${array[@]}"` | Use `${array[@]}` or `${array[*]}` |
| **Functions** | Use `local` for variables | Use global variables |
| **Errors** | Send to STDERR: `>&2` | Send to STDOUT |
| **Files** | Use explicit paths: `./*` | Use wildcards alone: `*` |

### ShellCheck Integration

```bash
# Install ShellCheck
apt-get install shellcheck  # Debian/Ubuntu
brew install shellcheck      # macOS

# Check a script
shellcheck script.sh

# Check with specific shell
shellcheck -s bash script.sh

# Ignore specific warnings
# shellcheck disable=SC2086
unquoted_var=$var  # Intentionally unquoted

# Check all scripts in directory
find . -name "*.sh" -exec shellcheck {} \;
```

### Common Variable Operations

```bash
# String operations
${var}            # Value of var
${var:-default}   # Use default if var is unset or empty
${var:=default}   # Set var to default if unset or empty
${var:?error}     # Exit with error if var is unset or empty
${var:+alt}       # Use alt if var is set and not empty

# String manipulation
${#var}           # Length of var
${var#pattern}    # Remove shortest match from beginning
${var##pattern}   # Remove longest match from beginning
${var%pattern}    # Remove shortest match from end
${var%%pattern}   # Remove longest match from end
${var/old/new}    # Replace first occurrence
${var//old/new}   # Replace all occurrences
${var^^}          # Convert to uppercase (Bash 4+)
${var,,}          # Convert to lowercase (Bash 4+)

# Array operations
${array[@]}       # All elements as separate words
${array[*]}       # All elements as single word
${#array[@]}      # Number of elements
${!array[@]}      # All indices
${array[@]:2:3}   # Slice: 3 elements starting at index 2
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Unquoted Variables

```bash
# PROBLEM
file="my file.txt"
rm $file  # Tries to remove "my" and "file.txt"

# SOLUTION
rm "${file}"  # Correctly removes "my file.txt"
```

### Pitfall 2: Pipe to While

```bash
# PROBLEM - Variable changes lost
cat file | while read line; do
  count=$((count + 1))
done
echo $count  # Still 0!

# SOLUTION - Use process substitution
while read line; do
  count=$((count + 1))
done < <(cat file)
echo $count  # Correct count
```

### Pitfall 3: Test Command Confusion

```bash
# PROBLEM - Word splitting
if [ $var == "value with spaces" ]; then  # Syntax error!

# SOLUTION - Use [[ ]] and quote
if [[ "${var}" == "value with spaces" ]]; then
```

### Pitfall 4: Local Variable Exit Codes

```bash
# PROBLEM - Exit code masked
function bad() {
  local result="$(command_that_fails)"
  if (( $? != 0 )); then  # Always 0 (from 'local')
    return 1
  fi
}

# SOLUTION - Separate declaration
function good() {
  local result
  result="$(command_that_fails)"
  if (( $? != 0 )); then  # Correct exit code
    return 1
  fi
}
```

### Pitfall 5: Globbing Issues

```bash
# PROBLEM - File starting with dash
rm *  # If file "-rf" exists, disaster!

# SOLUTION - Use explicit path
rm ./*  # Safe from interpretation as options
```

---

## Summary

The Google Shell Style Guide promotes:

1. **Consistency**: Use Bash exclusively, follow naming conventions
2. **Safety**: Quote variables, check return values, avoid dangerous constructs
3. **Readability**: Clear formatting, meaningful names, helpful comments
4. **Simplicity**: Keep scripts small, use appropriate tools for complex tasks
5. **Maintainability**: Organized structure, local variables, proper error handling

By following these guidelines, shell scripts become more reliable, maintainable, and professional. Remember: when in doubt, prioritize clarity and safety over cleverness.

---

## Additional Resources

- [Official Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck - Shell Script Analysis Tool](https://www.shellcheck.net/)
- [Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls)

---

*This documentation is based on the Google Shell Style Guide and includes practical examples and extended explanations for better understanding and application.*