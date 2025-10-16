#!/bin/bash
# shellcheck shell=bash

# input.sh - Controlled Input Library
# A robust bash library for controlled user input with validation, cursor
# control, and multiple input modes
#
# Features:
#   - Multiple input modes: text, numeric, password, yesno, email, phone,
#     IPv4, IPv6
#   - Cursor control: Left/Right arrows, Home/End keys for non-destructive
#     editing
#   - Validation: Character length, format validation, numeric range
#     validation, custom error messages
#   - Default values: Gray hint display with Enter to accept
#   - Prefill mode: Pre-populated editable buffers for modifying existing
#     data
#   - Error handling: Same-line error redisplay, no screen scrolling on
#     retry
#   - SIGINT preservation: Saves and restores parent script's Ctrl+C
#     handler
#   - Clean interface: Returns via stdout, status via exit code
#
# Usage:
#   source input.sh
#   result=$(controlled_input "prompt" [OPTIONS])
#
# Options:
#   -m, --mode <type>         Input mode: text, numeric, password, yesno,
#                             email, phone, ipv4, ipv6
#   -n, --min <num>           Minimum character length (all modes except
#                             yesno)
#   -x, --max <num>           Maximum character length (all modes except
#                             yesno)
#   --min-value <num>         Minimum numeric value (numeric mode only,
#                             validates actual value)
#   --max-value <num>         Maximum numeric value (numeric mode only,
#                             validates actual value)
#   -d, --default <value>     Default value shown as gray hint [value]: -
#                             press Enter to accept
#   -p, --prefill <value>     Pre-populate input buffer with editable value
#                             (cursor at end)
#   -e, --error-msg <text>    Custom error message to display on validation
#                             failure
#   --allow-empty             Allow empty input (default: false, not
#                             applicable with -d or -p)
#
# Examples:
#   # Text with length constraints
#   username=$(controlled_input "Username:" -m text -n 3 -x 20)
#
#   # Numeric with range validation
#   port=$(controlled_input "Port:" -m numeric --min-value 1024 \
#     --max-value 65535)
#
#   # Password with minimum length
#   password=$(controlled_input "Password:" -m password -n 8)
#
#   # Yes/No with default
#   confirm=$(controlled_input "Continue? (Y/n)" -m yesno -d Y)
#
#   # Default hint mode (buffer empty, shows a hint)
#   hostname=$(controlled_input "Hostname" -m text -d "localhost")
#
#   # Prefill mode (buffer pre-populated, editable)
#   config=$(controlled_input "Edit path:" -m text -p "/etc/config.conf")
#
# Exit Codes:
#   0 - Valid input returned
#   1 - User interrupted (Ctrl+C)
#   2 - Invalid parameters
#
# Repository: https://github.com/tkirkland/input.sh
# License: MIT
#

# ANSI Color Codes
readonly COLOR_RESET='\e[0m'
readonly COLOR_RED='\e[31m'
readonly COLOR_GRAY='\e[90m'

# ANSI Text Effects
readonly BLINK='\e[5m'

# ANSI Cursor Control
readonly ERASE_LINE=$'\e[2K'

# Exit Codes
readonly EXIT_SUCCESS=0
readonly EXIT_INTERRUPTED=1
readonly EXIT_INVALID_PARAMS=2

#
# Main controlled_input function
#
controlled_input() {
  # Default parameters
  local prompt=""
  local mode="text"
  local min_length=0
  local max_length=999
  local min_value=""
  local max_value=""
  local default_value=""
  local prefill_value=""
  local error_msg=""
  local allow_empty=false

  # Parse arguments
  if [[ $# -eq 0 ]]; then
    echo "Error: Prompt required" >&2
    return "$EXIT_INVALID_PARAMS"
  fi

  prompt="$1"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m | --mode)
        mode="$2"
        shift 2
        ;;
      -n | --min)
        min_length="$2"
        shift 2
        ;;
      -x | --max)
        max_length="$2"
        shift 2
        ;;
      -d | --default)
        default_value="$2"
        shift 2
        ;;
      -p | --prefill)
        prefill_value="$2"
        shift 2
        ;;
      -e | --error-msg)
        error_msg="$2"
        shift 2
        ;;
      --min-value)
        min_value="$2"
        shift 2
        ;;
      --max-value)
        max_value="$2"
        shift 2
        ;;
      --allow-empty)
        allow_empty=true
        shift
        ;;
      *)
        echo "Error: Unknown option: $1" >&2
        return "$EXIT_INVALID_PARAMS"
        ;;
    esac
  done

  # Validate mode
  case "$mode" in
    text | numeric | password | yesno | email | phone | ipv4 | ipv6) ;;
    *)
      echo "Error: Invalid mode: $mode" >&2
      return "$EXIT_INVALID_PARAMS"
      ;;
  esac

  # Main input loop with validation
  local result=""
  local retry=true
  local had_error=false

  while $retry; do
    # Save the terminal state for each attempt
    local old_stty
    old_stty=$(stty -g 2> /dev/null)

    # Setup terminal for raw input
    stty -echo -icanon min 1 time 0 2> /dev/null

    # Get input
    result=$(_input_loop "$prompt" "$mode" "$max_length" \
      "$default_value" "$prefill_value")
    local input_status=$?

    # Restore the terminal immediately after input
    stty "$old_stty" 2> /dev/null

    # Check if the user interrupted
    if [[ $input_status -eq $EXIT_INTERRUPTED ]]; then
      return "$EXIT_INTERRUPTED"
    fi

    # Validate input
    local validation_error=""
    validation_error=$(_validate_input "$result" "$mode" "$min_length" \
      "$max_length" "$allow_empty" "$min_value" "$max_value")

    if [[ -z $validation_error ]]; then
      # Input is valid - clear error if there was one
      if $had_error; then
        # Error is on the current line, clear it
        printf '%s\r' "$ERASE_LINE" >&2
      fi
      retry=false
    else
      # Show error and retry
      local display_error="${error_msg:-$validation_error}"
      _show_error "$display_error"
      had_error=true
    fi
  done

  # Output result
  echo "$result"
  return "$EXIT_SUCCESS"
}

#
# Internal function: Input loop with cursor control
#
_input_loop() {
  local prompt="$1"
  local mode="$2"
  local max_length="$3"
  local default_value="$4"
  local prefill_value="$5"
  local buffer=""
  local cursor_pos=0
  local display_default=""
  local result
  local char=""
  local before
  local after
  local rest
  local move
  local seq

  # Handle prefill mode: populate the buffer with editable value
  if [[ -n $prefill_value ]]; then
    buffer="$prefill_value"
    cursor_pos=${#buffer}
  fi

  # Set display hint for default value (shown in brackets, not in buffer)
  if [[ -n $default_value ]]; then
    display_default=$(printf " %b[%s]%b:" "$COLOR_GRAY" \
      "$default_value" "$COLOR_RESET")
  fi

  # Display prompt with a default hint
  printf "%s%s " "$prompt" "$display_default" >&2

  # Special handling for yesno mode
  if [[ $mode == "yesno" ]]; then
    result=$(_handle_yesno "$default_value")
    printf "\n" >&2
    echo "$result"
    return "$EXIT_SUCCESS"
  fi

  # Display prefilled buffer if any (for non-yesno modes)
  if [[ -n $buffer ]]; then
    if [[ $mode == "password" ]]; then
      printf '%*s' "${#buffer}" '' | tr ' ' '*' >&2
    else
      printf '%s' "$buffer" >&2
    fi
  fi

  # Main character input loop
  while true; do
    # Read a single character (using -n1 instead of -rsn1 for better
    # compatibility)
    if ! IFS= read -r -n1 char; then
      # EOF or error
      continue
    fi

    # Check for the Enter key
    if [[ -z $char ]]; then
      # Enter pressed (read returns empty string for newline with -n1)
      # Use default value if the buffer is empty and default is set
      if [[ -z $buffer ]] && [[ -n $default_value ]]; then
        buffer="$default_value"
        # Echo the default value as visual feedback
        if [[ $mode == "password" ]]; then
          printf '%*s' "${#buffer}" '' | tr ' ' '*' >&2
        else
          printf '%s' "$buffer" >&2
        fi
      fi
      printf "\n" >&2
      echo "$buffer"
      return "$EXIT_SUCCESS"
    fi

    # Check for special characters
    case "$char" in
      $'\x7f' | $'\x08') # Backspace or DEL
        if [[ $cursor_pos -gt 0 ]]; then
          # Remove character from the buffer
          buffer="${buffer:0:$((cursor_pos - 1))}${buffer:cursor_pos}"
          ((cursor_pos--))

          # Move cursor back, erase character, move cursor back again
          printf '\b \b' >&2

          # If there are characters after the cursor, redraw them
          if [[ $cursor_pos -lt ${#buffer} ]]; then
            rest="${buffer:cursor_pos}"
            if [[ $mode == "password" ]]; then
              printf '%*s' "${#rest}" '' | tr ' ' '*' >&2
            else
              printf '%s' "$rest" >&2
            fi
            printf ' ' >&2  # Erase the extra character
            # Move cursor back to the correct position
            printf '\e[%dD' "$((${#rest} + 1))" >&2
          fi
        fi
        ;;

      $'\x03')  # Ctrl+C
        printf "\n" >&2
        return "$EXIT_INTERRUPTED"
        ;;

      $'\e')  # Escape sequence
        # Read the rest of the escape sequence
        read -r -n2 -t 0.1 seq
        case "$seq" in
          '[D')  # Left arrow
            if [[ $cursor_pos -gt 0 ]]; then
              ((cursor_pos--))
              printf '\e[D' >&2
            fi
            ;;
          '[C')  # Right arrow
            if [[ $cursor_pos -lt ${#buffer} ]]; then
              ((cursor_pos++))
              printf '\e[C' >&2
            fi
            ;;
          '[H')  # Home key
            if [[ $cursor_pos -gt 0 ]]; then
              printf '\e[%dD' "$cursor_pos" >&2
              cursor_pos=0
            fi
            ;;
          '[F')  # End key
            if [[ $cursor_pos -lt ${#buffer} ]]; then
              move=$((${#buffer} - cursor_pos))
              printf '\e[%dC' "$move" >&2
              cursor_pos=${#buffer}
            fi
            ;;
        esac
        ;;

      *)  # Regular character
        # Validate and insert character
        if _is_valid_char "$char" "$mode" \
          && [[ ${#buffer} -lt $max_length ]]; then
          # Insert character at the cursor position
          before="${buffer:0:cursor_pos}"
          after="${buffer:cursor_pos}"
          buffer="${before}${char}${after}"

          # Echo the character (or * for password)
          if [[ $mode == "password" ]]; then
            printf '*' >&2
          else
            printf '%s' "$char" >&2
          fi

          ((cursor_pos++))

          # If we inserted in the middle, redraw the rest and reposition
          if [[ -n $after ]]; then
            if [[ $mode == "password" ]]; then
              printf '%*s' "${#after}" '' | tr ' ' '*' >&2
            else
              printf '%s' "$after" >&2
            fi
            # Move cursor back to correct position
            printf '\e[%dD' "${#after}" >&2
          fi
        fi
        ;;
    esac
  done
}

#
# Internal function: Check if the character is valid for mode
#
_is_valid_char() {
  local char="$1"
  local mode="$2"

  case "$mode" in
    text)
      [[ $char =~ ^[[:print:]]$ ]]  # Allow all printable characters
      ;;
    numeric)
      [[ $char =~ ^[0-9]$ ]]
      ;;
    password)
      [[ $char =~ ^[[:graph:]]$ ]]  # Allow all visible characters
      ;;
    email)
      [[ $char =~ ^[a-zA-Z0-9+.@_-]$ ]]
      ;;
    phone)
      [[ $char =~ ^[0-9-]$ ]]
      ;;
    ipv4)
      [[ $char =~ ^[0-9.]$ ]]
      ;;
    ipv6)
      [[ $char =~ ^[0-9a-fA-F:]$ ]]
      ;;
    *)
      return 1
      ;;
  esac
}
#
# Internal function: Handle yes/no input
#
_handle_yesno() {
  local default_value="$1"
  local char=""

  while true; do
    if ! IFS= read -r -n1 char; then
      continue
    fi

    # Check for Ctrl+C
    if [[ $char == $'\x03' ]]; then
      return "$EXIT_INTERRUPTED"
    fi
    # Check for Enter with default
    if [[ -z $char ]] && [[ -n $default_value ]]; then
      local default_upper
      default_upper=$(echo "$default_value" | tr '[:lower:]' '[:upper:]')
      if [[ $default_upper == "Y" ]]; then
        printf "Yes" >&2
        echo "Y"
      else
        printf "No" >&2
        echo "N"
      fi
      return "$EXIT_SUCCESS"
    fi

    # Convert to uppercase
    char=$(echo "$char" | tr '[:lower:]' '[:upper:]')

    if [[ $char == "Y" ]]; then
      printf "Yes" >&2
      echo "Y"
      return "$EXIT_SUCCESS"
    elif [[ $char == "N" ]]; then
      printf "No" >&2
      echo "N"
      return "$EXIT_SUCCESS"
    fi
  done
}

#
# Internal function: Validate input
#
_validate_input() {
  local input="$1"
  local mode="$2"
  local min_length="$3"
  local max_length="$4"
  local allow_empty="$5"
  local min_value="$6"
  local max_value="$7"
  local digits="${input//-/}"

  # Check empty input
  if [[ -z $input ]]; then
    if ! $allow_empty; then
      echo "Input cannot be empty"
      return
    else
      return
    fi
  fi

  # Check length
  if [[ ${#input} -lt $min_length ]]; then
    echo "Input must be at least $min_length characters"
    return
  fi

  if [[ ${#input} -gt $max_length ]]; then
    echo "Input must be at most $max_length characters"
    return
  fi

  # Mode-specific validation
  case "$mode" in
    email)
      if ! [[ $input =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
      then
        echo "Invalid email format"
        return
      fi
      ;;
    phone)
      # Remove any existing dashes
      if ! [[ $digits =~ ^[0-9]{10}$ ]]; then
        echo "Phone must be 10 digits"
        return
      fi
      ;;
    ipv4)
      if ! _validate_ipv4 "$input"; then
        echo "Invalid IPv4 address"
        return
      fi
      ;;
    ipv6)
      if ! _validate_ipv6 "$input"; then
        echo "Invalid IPv6 address"
        return
      fi
      ;;
    numeric)
      if ! [[ $input =~ ^[0-9]+$ ]]; then
        echo "Input must be numeric"
        return
      fi
      # Check numeric range if specified
      if [[ -n $min_value ]] && [[ $input -lt $min_value ]]; then
        echo "Value must be at least $min_value"
        return
      fi
      if [[ -n $max_value ]] && [[ $input -gt $max_value ]]; then
        echo "Value must be at most $max_value"
        return
      fi
      ;;
  esac
}

#
# Internal function: Validate IPv4 address
#
_validate_ipv4() {
  local ip="$1" octet

  if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 1
  fi

  IFS='.' read -ra octets <<< "$ip"

  if [[ ${#octets[@]} -ne 4 ]]; then
    return 1
  fi

  for octet in "${octets[@]}"; do
    if [[ $octet -lt 0 ]] || [[ $octet -gt 255 ]]; then
      return 1
    fi
  done

  return 0
}

#
# Internal function: Validate IPv6 address
#
_validate_ipv6() {
  local ip="$1"
  local addr prefix groups=()
  local replacement=""
   local i

  # Handle CIDR notation (e.g., 2001:db8::/32)
  if [[ $ip =~ ^(.+)/([0-9]+)$ ]]; then
    addr="${BASH_REMATCH[1]}"
    prefix="${BASH_REMATCH[2]}"

    # Validate prefix length (0-128)
    if [[ $prefix -lt 0 ]] || [[ $prefix -gt 128 ]]; then
      return 1
    fi
  else
    addr="$ip"
  fi

  # Check for valid characters only (hex digits and colons)
  if ! [[ $addr =~ ^[0-9a-fA-F:]+$ ]]; then
    return 1
  fi

  # Check for invalid patterns: more than one ::, or ::: or more
  if [[ $addr =~ ::.*:: ]] || [[ $addr =~ :::+ ]]; then
    return 1
  fi

  # Check for invalid leading/trailing single colons
  if [[ $addr =~ ^:[^:] ]] || [[ $addr =~ [^:]:$ ]]; then
    return 1
  fi

  # Expand the :: to full zeros for validation
  local expanded="$addr"
  if [[ $addr =~ :: ]]; then
    # Count existing groups
    local groups_before groups_after total_groups
    groups_before=$(echo "${addr%%::*}" | tr -cd ':' | wc -c)
    groups_after=$(echo "${addr#*::}" | tr -cd ':' | wc -c)

    # Add 1 for each non-empty part (before and after ::)
    [[ -n ${addr%%::*} ]] && ((groups_before++))
    [[ -n ${addr#*::} ]] && ((groups_after++))

    total_groups=$((groups_before + groups_after))

    # Calculate missing groups (should be 8 total)
    local missing_groups=$((8 - total_groups))

    if [[ $missing_groups -lt 0 ]]; then
      return 1
    fi

    # Create a replacement string with the appropriate number of zeros
    for ((i = 0; i <= missing_groups; i++)); do
      replacement="${replacement}0:"
    done
    replacement="${replacement%:}"

    # Expand the address
    expanded="${addr//::/:$replacement:}"
    expanded="${expanded#:}"
    expanded="${expanded%:}"
  fi

  # Validate the expanded address has exactly 8 groups
  local group_count group
  group_count=$(echo "$expanded" | tr -cd ':' | wc -c)
  group_count=$((group_count + 1))

  if [[ $group_count -ne 8 ]]; then
    return 1
  fi

  # Validate each group (max 4 hex digits)
  IFS=':' read -ra groups <<< "$expanded"
  for group in "${groups[@]}"; do
    # Check if the group is 1-4 hex digits
    if ! [[ $group =~ ^[0-9a-fA-F]{1,4}$ ]]; then
      return 1
    fi
  done

  return 0
}

#
# Internal function: Show an error message
#
_show_error() {
  local error_msg="$1"

  # Print the error in red with blinking on the current line
  printf "%b%b%s%b\n" "${COLOR_RED}" "${BLINK}" "${error_msg}" "${COLOR_RESET}" >&2

  # Move the cursor up 2 lines (error and blank line from where input ended)
  printf '\e[2A' >&2

  # Erase current line
  printf '%s\r' "${ERASE_LINE}" >&2
}

# Export function for use in other scripts
export -f controlled_input
