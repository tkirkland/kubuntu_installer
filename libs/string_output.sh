#!/bin/bash
# shellcheck disable=SC2034
# shellcheck shell=bash
# =============================================================================
# Text Handler Library v1.1.0
# =============================================================================
# A comprehensive Bash output library for text formatting, colors, and display
#
# Usage: source ./string_output.sh
# License: MIT
#
# Changelog:
#   v1.1.0 (2025-10-16)
#     - Enhanced -P -w combination for professional wrapped output
#     - Continuation lines now auto-indent under message content
#     - First line skips indent when prefix is present
#   v1.0.1
#     - Initial documented release
# =============================================================================

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

# ANSI Color Codes
readonly TH_RED='\033[0;31m'
readonly TH_GREEN='\033[0;32m'
readonly TH_YELLOW='\033[0;33m'
readonly TH_BLUE='\033[0;34m'
readonly TH_MAGENTA='\033[0;35m'
readonly TH_CYAN='\033[0;36m'
readonly TH_WHITE='\033[0;37m'

# ANSI Style Codes
readonly TH_BOLD='\033[1m'
readonly TH_DIM='\033[2m'
readonly TH_UNDERLINE='\033[4m'
readonly TH_RESET='\033[0m'

# Box Drawing Characters
readonly TH_BOX_TL='┌'
readonly TH_BOX_TR='┐'
readonly TH_BOX_BL='└'
readonly TH_BOX_BR='┘'
readonly TH_BOX_H='─'
readonly TH_BOX_V='│'
readonly TH_BOX_CROSS='┼'
readonly TH_BOX_T='┬'
readonly TH_BOX_B='┴'
readonly TH_BOX_L='├'
readonly TH_BOX_R='┤'

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

#######################################
# Strip ANSI escape codes from text
# Removes all color and formatting escape sequences from a string,
# leaving only the plain text content. Useful for length calculations
# and logging to files.
# Arguments:
#   $1 - Text containing ANSI escape codes
# Outputs:
#   Text with all ANSI codes removed
# Returns:
#   0 - Success
#######################################
strip_ansi() {
  echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

#######################################
# Get current terminal width
# Detects the terminal width using tput if available, otherwise
# defaults to 80 columns. Only works when stdout is a terminal.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Terminal width in columns
# Returns:
#   0 - Success
#######################################
get_terminal_width() {
  local width=80
  # Check if stdout is a terminal and tput command exists
  if [[ -t 1 ]] && command -v tput > /dev/null 2>&1; then
    width=$(tput cols 2> /dev/null || echo 80)
  fi
  echo "$width"
}

#######################################
# Process text to handle newline escapes properly
# Converts literal \n escape sequences to actual newline characters.
# This allows users to embed newlines in their text strings.
# Arguments:
#   $1 - Text potentially containing literal \n sequences
# Outputs:
#   Text with \n converted to actual newlines
# Returns:
#   0 - Success
#######################################
process_newlines() {
  local text="$1"
  # Convert literal \n to actual newlines
  echo -e "$text"
}

# -----------------------------------------------------------------------------
# Text Manipulation Functions
# -----------------------------------------------------------------------------

#######################################
# Word-wrap text at specified column
# Wraps long text lines to fit within a specified width while
# preserving ANSI color codes. Handles indentation, empty lines,
# and word boundaries intelligently. ANSI codes are stripped for
# length calculations but preserved in output.
# Arguments:
#   $1 - Text to wrap (may contain ANSI codes and \n sequences)
#   $2 - Indentation width in spaces (default: 0)
#   $3 - Maximum line width in columns (default: 79)
#   $4 - Skip first line indent: 0=indent all, 1=skip first (default: 0)
# Outputs:
#   Word-wrapped text with indentation applied
# Returns:
#   0 - Success
# Example:
#   wrap_text "This is a long line that needs wrapping" 4 40
#   wrap_text "Prefix: long text..." 8 79 1  # First line no indent
#######################################
wrap_text() {
  local text="$1"
  local indent="${2:-0}"
  local max_width="${3:-79}"
  local skip_first="${4:-0}"
  local line_width=$((max_width - indent))
  local indent_str=""
  local result=""
  local line=""
  local word input_line
  local -a lines
  local is_first_line=1

  # Process newlines first
  text=$(process_newlines "$text")

  # Build indentation string if needed
  if [[ $indent -gt 0 ]]; then
    printf -v indent_str "%${indent}s" ""
  fi

  # Process line by line, preserving empty lines
  mapfile -t lines <<< "$text"

  for input_line in "${lines[@]}"; do
    # Preserve empty lines in output
    if [[ -z $input_line ]]; then
      result+=$'\n'
      is_first_line=0
      continue
    fi

    # Strip ANSI codes for length calculation
    local clean_line
    clean_line=$(strip_ansi "$input_line")

    # Determine if we should indent this line
    local current_indent=""
    if [[ $skip_first -eq 1 ]] && [[ $is_first_line -eq 1 ]]; then
      current_indent=""
      # First line uses full width
      line_width=$((max_width))
    else
      current_indent="$indent_str"
      line_width=$((max_width - indent))
    fi

    # If line fits within width, no wrapping needed
    if [[ ${#clean_line} -le $line_width ]]; then
      result+="$current_indent$input_line"$'\n'
      is_first_line=0
      continue
    fi

    # Wrap long lines word by word
    line=""
    local is_first_wrap_line=1
    for word in $clean_line; do
      local clean_word
      clean_word=$(strip_ansi "$word")
      local test_line

      # Test if adding this word exceeds line width
      if [[ -z $line ]]; then
        test_line="$clean_word"
      else
        test_line="$line $clean_word"
      fi

      if [[ ${#test_line} -le $line_width ]]; then
        # Word fits, add it to current line
        if [[ -z $line ]]; then
          line="$word"
        else
          line="$line $word"
        fi
      else
        # Word doesn't fit, output current line and start new one
        # Apply indent logic for wrapped lines
        if [[ $is_first_wrap_line -eq 1 ]] && [[ $skip_first -eq 1 ]] && [[ $is_first_line -eq 1 ]]; then
          result+="$line"$'\n'
          is_first_wrap_line=0
          is_first_line=0
          # Subsequent wrapped lines get indent
          line_width=$((max_width - indent))
        else
          result+="$indent_str$line"$'\n'
        fi
        line="$word"
      fi
    done

    # Output remaining text in line buffer
    if [[ -n $line ]]; then
      if [[ $is_first_wrap_line -eq 1 ]] && [[ $skip_first -eq 1 ]] && [[ $is_first_line -eq 1 ]]; then
        result+="$line"$'\n'
      else
        result+="$indent_str$line"$'\n'
      fi
    fi
    is_first_line=0
  done

  # Remove trailing newline and output
  echo -n "${result%$'\n'}"
}

#######################################
# Truncate text to a specified width
# Cuts text that exceeds max_width and appends "..." to indicate
# truncation. ANSI codes are stripped for length calculation but
# preserved in output up to the truncation point.
# Arguments:
#   $1 - Text to truncate (may contain ANSI codes)
#   $2 - Maximum width in columns (default: 79)
# Outputs:
#   Original text if it fits, or truncated text with "..." suffix
# Returns:
#   0 - Success
# Example:
#   truncate_text "This is a very long line" 10  # Output: "This is..."
#######################################
truncate_text() {
  local text="$1"
  local max_width="${2:-79}"
  local clean_text
  clean_text=$(strip_ansi "$text")

  if [[ ${#clean_text} -le $max_width ]]; then
    echo "$text"
  else
    # Reserve 3 characters for "..." suffix
    echo "${text:0:$((max_width - 3))}..."
  fi
}

#######################################
# Align text (left/center/right)
# Aligns text within a specified width by adding padding spaces.
# ANSI codes are stripped for length calculation but preserved in
# the output. If text is longer than width, returns text as-is.
# Arguments:
#   $1 - Text to align (may contain ANSI codes)
#   $2 - Alignment: "left", "center", or "right" (default: "left")
#   $3 - Total width in columns (default: 79)
# Outputs:
#   Text aligned within the specified width
# Returns:
#   0 - Success
# Example:
#   align_text "Title" "center" 40  # Centers "Title" in 40 chars
#######################################
align_text() {
  local text="$1"
  local alignment="${2:-left}"
  local width="${3:-79}"
  local clean_text
  clean_text=$(strip_ansi "$text")
  local text_len=${#clean_text}
  local padding

  case "$alignment" in
    center)
      # Calculate padding for centering (rounds down if odd)
      padding=$(((width - text_len) / 2))
      if [[ $padding -gt 0 ]]; then
        printf "%${padding}s%s" "" "$text"
      else
        echo "$text"
      fi
      ;;
    right)
      # Calculate padding for right alignment
      padding=$((width - text_len))
      if [[ $padding -gt 0 ]]; then
        printf "%${padding}s%s" "" "$text"
      else
        echo "$text"
      fi
      ;;
    left | *)
      # Left alignment requires no padding
      echo "$text"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Core Output Function
# -----------------------------------------------------------------------------

#######################################
# Main output function with comprehensive formatting options
# Provides a unified interface for all text output with support for
# colors, styles, levels (info/success/warning/error/internal),
# timestamps, wrapping, truncation, alignment, and file logging.
# Supports both argument-based and stdin-based input.
#
# Globals:
#   TH_BLUE, TH_GREEN, TH_YELLOW, TH_RED, TH_MAGENTA, TH_CYAN, TH_WHITE
#   TH_BOLD, TH_DIM, TH_UNDERLINE, TH_RESET
#   th_use_color - Enable/disable color output (1/0)
#   th_verbosity - Control output verbosity (0=quiet, 1=normal)
#
# Arguments:
#   Multiple flags and options (see below), followed by text
#   -c, --color <name>        Color: red|green|yellow|blue|magenta|cyan|white
#   -s, --style <name>        Style: bold|dim|underline
#   -l, --level <name>        Level: info|success|warning|error|internal
#   -n, --no-newline          Suppress trailing newline
#   -t, --timestamp           Add timestamp prefix
#   -f, --file <path>         Also log to file (without colors)
#   -w, --wrap                Enable word wrapping
#   -W, --width <num>         Set maximum width (default: 79)
#   -T, --truncate            Truncate long lines
#   -a, --align <type>        Alignment: left|center|right
#   -i, --indent <num>        Indentation width in spaces
#   -p, --prefix <text>       Custom prefix text
#   -P, --prefix-color-only   Color only the prefix, not entire line
#   --                        Treat remaining args as text (stops parsing)
#
# Outputs:
#   Formatted text to stdout (or stderr for error/internal levels)
#
# Returns:
#   0 - Success
#   1 - Error level was used, or invalid option
#
# Examples:
#   output_text -l info "Starting process..."
#   output_text -l error "Failed to connect" >&2
#   output_text -P -l success "Done"  # Colored prefix only
#   output_text -w -W 60 "Long text that needs wrapping..."
#   output_text -t -l internal "Cleanup completed"  # With timestamp
#   output_text -P -w -l warning "Long message..."  # Auto-indent continuation
#   # Output: [WARNING] Long message that wraps with
#   #                   continuation lines aligned
#######################################
output_text() {
  local text=""
  local color=""
  local style=""
  local level=""
  local no_newline=0
  local timestamp=0
  local log_file=""
  local wrap=0
  local truncate=0
  local alignment="left"
  local indent=0
  local prefix=""
  local max_width=79
  local prefix_color_only=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--color)
      color="$2"
      shift 2
      ;;
    -s|--style)
      style="$2"
      shift 2
      ;;
    -l|--level)
      level="$2"
      shift 2
      ;;
    -n|--no-newline)
      no_newline=1
      shift
      ;;
    -t|--timestamp)
      timestamp=1
      shift
      ;;
    -f|--file)
      log_file="$2"
      shift 2
      ;;
    -w|--wrap)
      wrap=1
      shift
      ;;
    -W|--width)
      max_width="$2"
      shift 2
      ;;
    -T|--truncate)
      truncate=1
      shift
      ;;
    -a|--align)
      alignment="$2"
      shift 2
      ;;
    -i|--indent)
      indent="$2"
      shift 2
      ;;
    -p|--prefix)
      prefix="$2"
      shift 2
      ;;
    -P|--prefix-color-only)
      prefix_color_only=1
      shift
      ;;
    --)
      shift
      text="$*"
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      return 1
      ;;
    *)
      text="$*"
      break
      ;;
  esac
done

  # Read from stdin if no text provided
  if [[ -z $text ]] && [[ ! -t 0 ]]; then
    text=$(cat)
  fi

  # Check verbosity level
  if [[ ${th_verbosity:-1} -eq 0 ]] && [[ $level != "error" ]]; then
    return 0
  fi

  # Set defaults based on level
  case "$level" in
    info)
          prefix="${prefix:-[INFO]}"
          color="${color:-blue}"
          ;;
    success)
          prefix="${prefix:-[SUCCESS]}"
          color="${color:-green}"
          ;;
    warning)
          prefix="${prefix:-[WARNING]}"
          color="${color:-yellow}"
          ;;
    error)
          prefix="${prefix:-[ERROR]}"
          color="${color:-red}"
          ;;
    internal)
          # Internal logging: full timestamp, no color for reliability
          prefix="${prefix:-[INTERNAL]}"
          color=""  # Disable color for internal logging
          timestamp=1  # Force full timestamp for internal level
          ;;
  esac

  # Add a timestamp if requested
  if [[ $timestamp -eq 1 ]]; then
    local ts
    # Use full timestamp format for internal level, short for others
    if [[ $level == "internal" ]]; then
      ts=$(date '+%Y-%m-%d %H:%M:%S')
      prefix="[${ts}]"  # Replace prefix entirely for internal
    else
      ts=$(date '+%H:%M:%S')
      prefix="[${ts}] ${prefix}"
    fi
  fi

  # Process newlines in the text first
  text=$(process_newlines "$text")

  # Build output with colors and styles
  local output=""
  local color_code=""
  local style_code=""

  if [[ ${th_use_color:-1} -eq 1 ]]; then
    case "$color" in
      red) color_code="$TH_RED" ;;
      green) color_code="$TH_GREEN" ;;
      yellow) color_code="$TH_YELLOW" ;;
      blue) color_code="$TH_BLUE" ;;
      magenta) color_code="$TH_MAGENTA" ;;
      cyan) color_code="$TH_CYAN" ;;
      white) color_code="$TH_WHITE" ;;
    esac

    case "$style" in
      bold) style_code="$TH_BOLD" ;;
      dim) style_code="$TH_DIM" ;;
      underline) style_code="$TH_UNDERLINE" ;;
    esac
  fi

  # Handle prefix coloring
  if [[ -n $prefix ]]; then
    if [[ $prefix_color_only -eq 1 ]]; then
      # Color only the prefix
      text="${style_code}${color_code}${prefix}${TH_RESET} ${text}"

      # Auto-calculate indent for wrapping if -P and -w are both active
      # This ensures continuation lines align with the message content
      if [[ $wrap -eq 1 ]] && [[ $indent -eq 0 ]]; then
        # Calculate visual width: prefix + space after it
        local clean_prefix
        clean_prefix=$(strip_ansi "$prefix")
        indent=$((${#clean_prefix} + 1))
      fi
    else
      # Color the entire line (original behavior)
      text="$prefix $text"
    fi
  fi

  # Apply text transformations after prefix is added
  if [[ $wrap -eq 1 ]]; then
    # For -P -w combination, skip indent on first line (prefix is already there)
    local skip_first_indent=0
    if [[ $prefix_color_only -eq 1 ]] && [[ $indent -gt 0 ]]; then
      skip_first_indent=1
    fi
    text=$(wrap_text "$text" "$indent" "$max_width" "$skip_first_indent")
  elif [[ $truncate -eq 1 ]]; then
    text=$(truncate_text "$text" "$max_width")
  fi

  if [[ $alignment != "left" ]]; then
    text=$(align_text "$text" "$alignment" "$max_width")
  fi

  # Build final output
  if [[ $prefix_color_only -eq 1 ]]; then
    # Prefix already colored, just output the text
    output="${text}"
  else
    # Apply color to entire output (original behavior)
    output="${style_code}${color_code}${text}${TH_RESET}"
  fi

  # Output the text
  if [[ $no_newline -eq 1 ]]; then
    printf "%b" "$output"
  else
    printf "%b\n" "$output"
  fi

  # Log to the file if specified
  if [[ -n $log_file ]]; then
    local clean_output
    clean_output=$(strip_ansi "$text")
    if [[ $no_newline -eq 1 ]]; then
      printf "%s" "$clean_output" >> "$log_file"
    else
      printf "%s\n" "$clean_output" >> "$log_file"
    fi
  fi

  [[ $level == "error" ]] && return 1
  return 0
}

# -----------------------------------------------------------------------------
# Convenience Functions
# -----------------------------------------------------------------------------

#######################################
# Output informational message
# Convenience wrapper for output_text with info level.
# Displays message with [INFO] prefix in blue color.
# Arguments:
#   $@ - Message text and any output_text options
# Outputs:
#   Formatted info message to stdout
# Returns:
#   0 - Success
# Example:
#   output_info "Processing configuration files..."
#######################################
output_info() { output_text -l info "$@"; }

#######################################
# Output success message
# Convenience wrapper for output_text with success level.
# Displays message with [SUCCESS] prefix in green color.
# Arguments:
#   $@ - Message text and any output_text options
# Outputs:
#   Formatted success message to stdout
# Returns:
#   0 - Success
# Example:
#   output_success "Installation completed successfully"
#######################################
output_success() { output_text -l success "$@"; }

#######################################
# Output warning message
# Convenience wrapper for output_text with warning level.
# Displays message with [WARNING] prefix in yellow color.
# Arguments:
#   $@ - Message text and any output_text options
# Outputs:
#   Formatted warning message to stdout
# Returns:
#   0 - Success
# Example:
#   output_warning "Disk space is running low"
#######################################
output_warning() { output_text -l warning "$@"; }

#######################################
# Output error message
# Convenience wrapper for output_text with error level.
# Displays message with [ERROR] prefix in red color to stderr.
# Arguments:
#   $@ - Message text and any output_text options
# Outputs:
#   Formatted error message to stderr
# Returns:
#   1 - Always returns error code
# Example:
#   output_error "Failed to mount filesystem"
#######################################
output_error() { output_text -l error "$@" >&2; }

#######################################
# Internal logging with full timestamp
# For trap handlers, cleanup routines, and system-level debugging.
# Uses full timestamp format [YYYY-MM-DD HH:MM:SS] and no color
# for maximum reliability in error conditions and log files.
# Arguments:
#   $@ - Error message text
# Outputs:
#   Writes to stderr with format: [YYYY-MM-DD HH:MM:SS]: message
# Returns:
#   0 - Success
# Example:
#   output_internal "Cleanup handler triggered"
#   output_internal "Pool export failed for rpool"
#######################################
output_internal() { output_text -l internal "$@" >&2; }

# -----------------------------------------------------------------------------
# Decorative Output Functions
# -----------------------------------------------------------------------------

#######################################
# Draw a box around text
# Creates a decorative box with Unicode box-drawing characters
# around the provided text. Text is centered within the box.
# Globals:
#   TH_BOX_BL, TH_BOX_BR, TH_BOX_H, TH_BOX_TL, TH_BOX_TR, TH_BOX_V
# Arguments:
#   $1 - Text to display in box (may contain ANSI codes)
#   $2 - Box width in characters (default: 77)
# Outputs:
#   Three-line box with centered text
# Returns:
#   0 - Success
# Example:
#   output_box "Important Notice" 50
#   # ┌──────────────────────────────────────────────────┐
#   # │            Important Notice                      │
#   # └──────────────────────────────────────────────────┘
#######################################
output_box() {
  local text="$1"
  local width="${2:-77}"
  local clean_text
  clean_text=$(strip_ansi "$text")
  local text_len=${#clean_text}
  # Calculate padding for centering (left and right may differ by 1)
  local padding=$(((width - text_len - 2) / 2))
  local right_pad=$((width - text_len - padding - 2))

  # Draw top border
  printf "%s" "$TH_BOX_TL"
  printf "%${width}s" "" | tr ' ' "$TH_BOX_H"
  printf "%s\n" "$TH_BOX_TR"

  # Draw middle with centered text
  printf "%s" "$TH_BOX_V"
  printf "%${padding}s" ""
  printf "%b" "$text"
  printf "%${right_pad}s" ""
  printf "%s\n" "$TH_BOX_V"

  # Draw bottom border
  printf "%s" "$TH_BOX_BL"
  printf "%${width}s" "" | tr ' ' "$TH_BOX_H"
  printf "%s\n" "$TH_BOX_BR"
}

#######################################
# Output a formatted section header
# Creates a decorative header with cyan bold text inside a box,
# with blank lines above and below for visual separation.
# Globals:
#   TH_BOLD, TH_CYAN, TH_RESET
# Arguments:
#   $1 - Header text
#   $2 - Box width in characters (default: 77)
# Outputs:
#   Formatted header with surrounding blank lines
# Returns:
#   0 - Success
# Example:
#   output_header "Configuration Section"
#######################################
output_header() {
  local text="$1"
  local width="${2:-77}"
  local colored_text
  # Apply cyan and bold formatting
  colored_text=$(printf "%b%b%b%b" "$TH_CYAN" "$TH_BOLD" "$text" "$TH_RESET")
  echo ""
  output_box "$colored_text" "$width"
  echo ""
}

#######################################
# Output a horizontal separator line
# Draws a line of repeating characters across the terminal.
# Useful for visually separating sections of output.
# Arguments:
#   $1 - Character to use for line (default: ─)
#   $2 - Line width in characters (default: 79)
# Outputs:
#   Horizontal line of specified character
# Returns:
#   0 - Success
# Example:
#   output_separator "=" 60
#   # ============================================================
#######################################
output_separator() {
  local char="${1:-─}"
  local width="${2:-79}"
  printf "%${width}s\n" "" | tr ' ' "$char"
}

#######################################
# Indent text by specified spaces
# Adds indentation to every line of the provided text.
# Processes embedded \n sequences and preserves empty lines.
# Arguments:
#   $1 - Text to indent (may contain \n sequences)
#   $2 - Indentation width in spaces (default: 4)
# Outputs:
#   Indented text with each line prefixed by spaces
# Returns:
#   0 - Success
# Example:
#   output_indent "Line 1\nLine 2" 8
#   #         Line 1
#   #         Line 2
#######################################
output_indent() {
  local text="$1"
  local indent="${2:-4}"
  local indent_str line

  # Process newlines first
  text=$(process_newlines "$text")

  # Build indentation string
  printf -v indent_str "%${indent}s" ""
  # Apply indentation to each line
  while IFS= read -r line; do
    echo "${indent_str}${line}"
  done <<< "$text"
}

# -----------------------------------------------------------------------------
# Interactive Functions
# -----------------------------------------------------------------------------

#######################################
# Interactive confirmation prompt
# Displays a yes/no prompt and waits for user input.
# Supports default values indicated by uppercase letter in prompt.
# Empty input (just pressing Enter) uses the default value.
# Arguments:
#   $1 - Prompt text
#   $2 - Default value: "y" or "n" (default: "n")
# Outputs:
#   Prompt text in yellow with [Y/n] or [y/N] indicator
# Returns:
#   0 - User confirmed (answered yes)
#   1 - User declined (answered no)
# Example:
#   if output_confirm "Delete all files?" "n"; then
#     echo "Deleting..."
#   else
#     echo "Cancelled"
#   fi
#######################################
output_confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local response

  # Display prompt with appropriate default indicator
  if [[ $default == "y" ]]; then
    output_text -c yellow -n "$prompt [Y/n] "
  else
    output_text -c yellow -n "$prompt [y/N] "
  fi

  # Read user input
  read -r response
  # Use default if user just pressed Enter
  response="${response:-$default}"

  # Check response (case-insensitive)
  case "$response" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Progress Indicators
# -----------------------------------------------------------------------------

#######################################
# Animated spinner for background processes
# Displays a rotating spinner character while a background process runs.
# Automatically clears the spinner when the process completes.
# Uses Unicode Braille pattern characters for smooth animation.
# Arguments:
#   $1 - PID of background process to monitor
#   $2 - Message to display next to spinner (default: "Working")
# Outputs:
#   Animated spinner with message, updated every 0.1 seconds
# Returns:
#   0 - When process completes
# Example:
#   long_process &
#   output_spinner $! "Processing files"
# Note:
#   Cursor is returned to line start after spinner clears
#######################################
output_spinner() {
  local pid=$1
  local message="${2:-Working}"
  # Unicode Braille spinner characters for smooth animation
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  # Loop while process is running
  while kill -0 "$pid" 2> /dev/null; do
    i=$(((i + 1) % ${#spin}))
    output_text -c cyan -n $'\r'"${spin:i:1} $message"
    sleep 0.1
  done

  # Clear the spinner line
  output_text -n $'\r'
  printf "%$((${#message} + 3))s\r" ""
}

#######################################
# Progress bar with percentage
# Displays a visual progress bar showing completion percentage.
# Updates in place by overwriting the current line with \r.
# Automatically adds newline when progress reaches 100%.
# Arguments:
#   $1 - Current progress value
#   $2 - Total/maximum value
#   $3 - Message/label to display (default: "Progress")
# Outputs:
#   Progress bar: Message: [=====>    ] 45%
# Returns:
#   0 - Success
# Example:
#   for i in {1..100}; do
#     output_progress "$i" 100 "Installing"
#     sleep 0.1
#   done
#######################################
output_progress() {
  local current=$1
  local total=$2
  local message="${3:-Progress}"
  local width=40  # Width of the progress bar in characters
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  # Draw progress bar: Message: [=====>    ] 75%
  printf "\r%s: [" "$message"
  # Filled portion (equals signs)
  printf "%${filled}s" "" | tr ' ' '='
  # Arrow at the leading edge (unless complete)
  if [[ $filled -lt $width ]]; then
    printf ">"
    printf "%$((empty - 1))s" ""
  fi
  printf "] %3d%%" "$percentage"

  # Add newline when complete
  if [[ $current -eq $total ]]; then
    echo ""
  fi
}

# -----------------------------------------------------------------------------
# Table Functions
# -----------------------------------------------------------------------------

#######################################
# Output a formatted table with borders
# Creates a table with Unicode box-drawing characters.
# First row is treated as header with separator line after it.
# Columns are pipe-delimited (|). Column widths auto-adjust to
# fit the widest content in each column. ANSI codes supported.
# Globals:
#   TH_BOX_CROSS, TH_BOX_H, TH_BOX_L, TH_BOX_R, TH_BOX_V
# Arguments:
#   $@ - Table rows as strings with pipe-delimited columns
# Outputs:
#   Formatted table with borders and auto-sized columns
# Returns:
#   0 - Success
# Example:
#   output_table \
#     "Name|Age|City" \
#     "Alice|30|NYC" \
#     "Bob|25|LA"
#   # │ Name  │ Age │ City │
#   # ├───────┼─────┼──────┤
#   # │ Alice │ 30  │ NYC  │
#   # │ Bob   │ 25  │ LA   │
#######################################
output_table() {
  local -a rows=("$@")
  local -a col_widths=()
  local num_cols=0
  local row cols i

  # First pass: Calculate column widths
  for row in "${rows[@]}"; do
    IFS='|' read -ra cols <<< "$row"
    num_cols=${#cols[@]}
    for i in "${!cols[@]}"; do
      local clean_col
      # Strip ANSI codes for accurate width calculation
      clean_col=$(strip_ansi "${cols[$i]}")
      local len=${#clean_col}
      # Track maximum width for each column
      if [[ -z ${col_widths[$i]} ]] || [[ $len -gt ${col_widths[$i]} ]]; then
        col_widths[i]=$len
      fi
    done
  done

  # Second pass: Output table with borders
  local is_header=1
  for row in "${rows[@]}"; do
    IFS='|' read -ra cols <<< "$row"
    # Draw row with vertical separators
    printf "%s " "$TH_BOX_V"
    for i in "${!cols[@]}"; do
      printf "%-${col_widths[$i]}s" "${cols[$i]}"
      if [[ $i -lt $((num_cols - 1)) ]]; then
        printf " %s " "$TH_BOX_V"
      fi
    done
    printf " %s\n" "$TH_BOX_V"

    # Draw separator after header row
    if [[ $is_header -eq 1 ]]; then
      printf "%s" "$TH_BOX_L"
      for i in "${!col_widths[@]}"; do
        # Horizontal line for each column
        printf "%$((col_widths[i] + 2))s" "" | tr ' ' "$TH_BOX_H"
        if [[ $i -lt $((num_cols - 1)) ]]; then
          printf "%s" "$TH_BOX_CROSS"
        fi
      done
      printf "%s\n" "$TH_BOX_R"
      is_header=0
    fi
  done
}

#######################################
# Display library information and usage
# Shows a formatted summary of the library's capabilities
# and available functions. Useful for documentation and help.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Formatted library information with function list
# Returns:
#   0 - Success
# Example:
#   output_library_info
#######################################
output_library_info() {
  output_header "Text Handler Library v1.1.0"
  output_text "A comprehensive Bash output library for text formatting"
  output_separator "─" 79
  output_text "Available functions:"
  output_text "  * output_text     - Main output function with options"
  output_text "  * output_info     - Information messages"
  output_text "  * output_success  - Success messages"
  output_text "  * output_warning  - Warning messages"
  output_text "  * output_error    - Error messages"
  output_text "  * output_internal - Internal logging (trap/cleanup)"
  output_text "  * output_box      - Box around text"
  output_text "  * output_header   - Section headers"
  output_text "  * output_table    - Formatted tables"
  output_text "  * output_confirm  - Y/N prompts"
  output_text "  * output_progress - Progress bars"
  output_text "  * output_spinner  - Loading spinners"
  output_text "  * output_separator - Line separators"
  output_text "  * output_indent   - Indented text"
}

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------

#######################################
# Initialize the text handler library
# Sets up default configuration, detects terminal capabilities
# (color support and width), and prevents multiple initialization.
# Called automatically when the library is sourced.
# Globals:
#   text_handler_loaded - Marks library as initialized
#   th_term_width - Detected or default terminal width (80)
#   th_use_color - Enable color output (1) or disable (0)
#   th_verbosity - Output verbosity level: 0=quiet, 1=normal
# Arguments:
#   None
# Returns:
#   0 - Initialization successful or already initialized
# Side Effects:
#   - Sets pipefail option for better error handling
#   - Detects and configures terminal color support
#   - Measures terminal width with tput if available
#######################################
_init_text_handler() {
  local text_handler_loaded
  # Prevent multiple initialization
  if [[ -n ${text_handler_loaded:-} ]]; then
    return 0
  fi

  # Mark as loaded (readonly prevents re-initialization)
  readonly text_handler_loaded=1

  # Set default configuration values
  : "${th_verbosity:=1}"      # Normal verbosity by default
  : "${th_use_color:=1}"      # Colors enabled by default
  : "${th_term_width:=80}"    # Standard 80-column default

  # Auto-detect color support and terminal width
  if [[ -t 1 ]] && command -v tput > /dev/null 2>&1; then
    local colors
    colors=$(tput colors 2> /dev/null || echo 0)
    # Enable color if terminal supports at least 8 colors
    if [[ $colors -ge 8 ]]; then
      th_use_color=1
    else
      th_use_color=0
    fi

    # Get actual terminal width
    th_term_width=$(tput cols 2> /dev/null || echo 80)
  else
    # Not a terminal or tput unavailable - disable colors
    th_use_color=0
  fi

  # Enable pipefail for better error handling in pipes
  set -o pipefail
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------

#######################################
# Main entry point - source detection and initialization
# Checks if the script is being sourced (correct) or executed (error).
# Libraries must be sourced, not executed, so they integrate into
# the calling script's environment.
# Globals:
#   BASH_SOURCE - Array of source filenames
# Arguments:
#   None
# Outputs:
#   Error message if executed instead of sourced
# Returns:
#   0 - When sourced correctly
# Exits:
#   1 - When executed directly (with usage instructions)
#######################################
main() {
  if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    # Script is being executed directly - this is an error
    echo "Error: This is a library file and should be sourced, not executed." >&2
    echo "" >&2
    echo "Usage: source ${BASH_SOURCE[0]}" >&2
    echo "   or: . ${BASH_SOURCE[0]}" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  #!/bin/bash" >&2
    echo "  source ./string_output.sh" >&2
    echo "  output_success 'Library loaded!'" >&2
    exit 1
  else
    # Script is being sourced - initialize library
    _init_text_handler
  fi
}

# Execute main to perform initialization or error handling
main
