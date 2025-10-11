# shellcheck disable=SC2034
# shellcheck shell=bash
# =============================================================================
# Text Handler Library v1.0.1
# =============================================================================
# A comprehensive Bash output library for text formatting, colors, and display
#
# Usage: source ./string_output.sh
# License: MIT
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

# Strip ANSI escape codes from text
strip_ansi() {
  echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# Get current terminal width
get_terminal_width() {
  local width=80
  if [[ -t 1 ]] && command -v tput > /dev/null 2>&1; then
    width=$(tput cols 2> /dev/null || echo 80)
  fi
  echo "$width"
}

# Process text to handle newline escapes properly
process_newlines() {
  local text="$1"
  # Convert literal \n to actual newlines
  echo -e "$text"
}

# -----------------------------------------------------------------------------
# Text Manipulation Functions
# -----------------------------------------------------------------------------

# Word-wrap text at specified column
wrap_text() {
  local text="$1"
  local indent="${2:-0}"
  local max_width="${3:-79}"
  local line_width=$((max_width - indent))
  local indent_str=""
  local result=""
  local line=""
  local word input_line
  local -a lines

  # Process newlines first
  text=$(process_newlines "$text")

  if [[ $indent -gt 0 ]]; then
    printf -v indent_str "%${indent}s" ""
  fi

  # Process line by line, preserving empty lines
  mapfile -t lines <<< "$text"

  for input_line in "${lines[@]}"; do
    # Preserve empty lines
    if [[ -z $input_line ]]; then
      result+=$'\n'
      continue
    fi

    local clean_line
    clean_line=$(strip_ansi "$input_line")

    if [[ ${#clean_line} -le $line_width ]]; then
      result+="$indent_str$input_line"$'\n'
      continue
    fi

    line=""
    for word in $clean_line; do
      local clean_word
      clean_word=$(strip_ansi "$word")
      local test_line

      if [[ -z $line ]]; then
        test_line="$clean_word"
      else
        test_line="$line $clean_word"
      fi

      if [[ ${#test_line} -le $line_width ]]; then
        if [[ -z $line ]]; then
          line="$word"
        else
          line="$line $word"
        fi
      else
        result+="$indent_str$line"$'\n'
        line="$word"
      fi
    done

    if [[ -n $line ]]; then
      result+="$indent_str$line"$'\n'
    fi
  done

  echo -n "${result%$'\n'}"
}

# Truncate text to a specified width
truncate_text() {
  local text="$1"
  local max_width="${2:-79}"
  local clean_text
  clean_text=$(strip_ansi "$text")

  if [[ ${#clean_text} -le $max_width ]]; then
    echo "$text"
  else
    echo "${text:0:$((max_width - 3))}..."
  fi
}

# Align text (left/center/right)
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
      padding=$(((width - text_len) / 2))
      if [[ $padding -gt 0 ]]; then
        printf "%${padding}s%s" "" "$text"
      else
        echo "$text"
      fi
      ;;
    right)
      padding=$((width - text_len))
      if [[ $padding -gt 0 ]]; then
        printf "%${padding}s%s" "" "$text"
      else
        echo "$text"
      fi
      ;;
    left | *)
      echo "$text"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Core Output Function
# -----------------------------------------------------------------------------

#######################################
# Main output function
# Globals:
#   TH_BLUE
#   TH_BOLD
#   TH_CYAN
#   TH_DIM
#   TH_GREEN
#   TH_MAGENTA
#   TH_RED
#   TH_RESET
#   TH_UNDERLINE
#   TH_WHITE
#   TH_YELLOW
#   th_use_color
#   th_verbosity
# Arguments:
#  None
# Returns:
#   0 ...
#   1 ...
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
    else
      # Color the entire line (original behavior)
      text="$prefix $text"
    fi
  fi

  # Apply text transformations after prefix is added
  if [[ $wrap -eq 1 ]]; then
    text=$(wrap_text "$text" "$indent" "$max_width")
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
# description
# Arguments:
#  None
#######################################
output_info() { output_text -l info "$@"; }
#######################################
# description
# Arguments:
#  None
#######################################
output_success() { output_text -l success "$@"; }
#######################################
# description
# Arguments:
#  None
#######################################
output_warning() { output_text -l warning "$@"; }
#######################################
# description
# Arguments:
#  None
#######################################
output_error() { output_text -l error "$@" >&2; }
#######################################
# Internal logging with full timestamp
# For trap handlers, cleanup routines, and system-level debugging
# Arguments:
#   Error message
# Outputs:
#   Writes to stderr with format: [YYYY-MM-DD HH:MM:SS]: message
#######################################
output_internal() { output_text -l internal "$@" >&2; }

# -----------------------------------------------------------------------------
# Decorative Output Functions
# -----------------------------------------------------------------------------

#######################################
# description
# Globals:
#   TH_BOX_BL
#   TH_BOX_BR
#   TH_BOX_H
#   TH_BOX_TL
#   TH_BOX_TR
#   TH_BOX_V
# Arguments:
#   1
#   2
#######################################
output_box() {
  local text="$1"
  local width="${2:-77}"
  local clean_text
  clean_text=$(strip_ansi "$text")
  local text_len=${#clean_text}
  local padding=$(((width - text_len - 2) / 2))
  local right_pad=$((width - text_len - padding - 2))

  printf "%s" "$TH_BOX_TL"
  printf "%${width}s" "" | tr ' ' "$TH_BOX_H"
  printf "%s\n" "$TH_BOX_TR"

  printf "%s" "$TH_BOX_V"
  printf "%${padding}s" ""
  printf "%b" "$text"
  printf "%${right_pad}s" ""
  printf "%s\n" "$TH_BOX_V"

  printf "%s" "$TH_BOX_BL"
  printf "%${width}s" "" | tr ' ' "$TH_BOX_H"
  printf "%s\n" "$TH_BOX_BR"
}

#######################################
# description
# Globals:
#   TH_BOLD
#   TH_CYAN
#   TH_RESET
# Arguments:
#   1
#   2
#######################################
output_header() {
  local text="$1"
  local width="${2:-77}"
  local colored_text
  colored_text=$(printf "%b%b%b%b" "$TH_CYAN" "$TH_BOLD" "$text" "$TH_RESET")
  echo ""
  output_box "$colored_text" "$width"
  echo ""
}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
output_separator() {
  local char="${1:-─}"
  local width="${2:-79}"
  printf "%${width}s\n" "" | tr ' ' "$char"
}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
output_indent() {
  local text="$1"
  local indent="${2:-4}"
  local indent_str line

  # Process newlines first
  text=$(process_newlines "$text")

  printf -v indent_str "%${indent}s" ""
  while IFS= read -r line; do
    echo "${indent_str}${line}"
  done <<< "$text"
}

# -----------------------------------------------------------------------------
# Interactive Functions
# -----------------------------------------------------------------------------

#######################################
# description
# Arguments:
#   1
#   2
# Returns:
#   0 ...
#   1 ...
#######################################
output_confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local response

  if [[ $default == "y" ]]; then
    output_text -c yellow -n "$prompt [Y/n] "
  else
    output_text -c yellow -n "$prompt [y/N] "
  fi

  read -r response
  response="${response:-$default}"

  case "$response" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Progress Indicators
# -----------------------------------------------------------------------------

#######################################
# description
# Arguments:
#   1
#   2
#######################################
output_spinner() {
  local pid=$1
  local message="${2:-Working}"
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  while kill -0 "$pid" 2> /dev/null; do
    i=$(((i + 1) % ${#spin}))
    output_text -c cyan -n $'\r'"${spin:i:1} $message"
    sleep 0.1
  done

  output_text -n $'\r'
  printf "%$((${#message} + 3))s\r" ""
}

#######################################
# Progress function
# Arguments:
#   1 - Progress x/total
#   2 - Progress total
#   3 - Text
#######################################
output_progress() {
  local current=$1
  local total=$2
  local message="${3:-Progress}"
  local width=40
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  printf "\r%s: [" "$message"
  printf "%${filled}s" "" | tr ' ' '='
  if [[ $filled -lt $width ]]; then
    printf ">"
    printf "%$((empty - 1))s" ""
  fi
  printf "] %3d%%" "$percentage"

  if [[ $current -eq $total ]]; then
    echo ""
  fi
}

# -----------------------------------------------------------------------------
# Table Functions
# -----------------------------------------------------------------------------

#######################################
# description
# Globals:
#   TH_BOX_CROSS
#   TH_BOX_H
#   TH_BOX_L
#   TH_BOX_R
#   TH_BOX_V
# Arguments:
#  None
#######################################
output_table() {
  local -a rows=("$@")
  local -a col_widths=()
  local num_cols=0
  local row cols i

  # Calculate column widths
  for row in "${rows[@]}"; do
    IFS='|' read -ra cols <<< "$row"
    num_cols=${#cols[@]}
    for i in "${!cols[@]}"; do
      local clean_col
      clean_col=$(strip_ansi "${cols[$i]}")
      local len=${#clean_col}
      if [[ -z ${col_widths[$i]} ]] || [[ $len -gt ${col_widths[$i]} ]]; then
        col_widths[i]=$len
      fi
    done
  done

  # Output table
  local is_header=1
  for row in "${rows[@]}"; do
    IFS='|' read -ra cols <<< "$row"
    printf "%s " "$TH_BOX_V"
    for i in "${!cols[@]}"; do
      printf "%-${col_widths[$i]}s" "${cols[$i]}"
      if [[ $i -lt $((num_cols - 1)) ]]; then
        printf " %s " "$TH_BOX_V"
      fi
    done
    printf " %s\n" "$TH_BOX_V"

    # Draw separator after header
    if [[ $is_header -eq 1 ]]; then
      printf "%s" "$TH_BOX_L"
      for i in "${!col_widths[@]}"; do
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
# description
# Arguments:
#  None
#######################################
output_library_info() {
  output_header "Text Handler Library v1.0.1"
  output_text "A comprehensive Bash output library for text formatting"
  output_separator
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
# description
# Globals:
#   text_handler_loaded
#   th_term_width
#   th_use_color
#   th_verbosity
# Arguments:
#  None
# Returns:
#   0 ...
#######################################
_init_text_handler() {
  local text_handler_loaded
  # Prevent multiple initialization
  if [[ -n ${text_handler_loaded:-} ]]; then
    return 0
  fi

  # Mark as loaded
  readonly text_handler_loaded=1

  # Set default configuration
  : "${th_verbosity:=1}"
  : "${th_use_color:=1}"
  : "${th_term_width:=80}"

  # Auto-detect color support
  if [[ -t 1 ]] && command -v tput > /dev/null 2>&1; then
    local colors
    colors=$(tput colors 2> /dev/null || echo 0)
    if [[ $colors -ge 8 ]]; then
      th_use_color=1
    else
      th_use_color=0
    fi

    # Get terminal width
    th_term_width=$(tput cols 2> /dev/null || echo 80)
  else
    th_use_color=0
  fi

  # Set pipefail for better error handling
  set -o pipefail
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
# Check if the script is being sourced or executed
main() {
  if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    # Script is being executed directly
    echo "Error: This is a library file and should be sourced, not executed." >&2
    echo "" >&2
    echo "Usage: source ${BASH_SOURCE[0]}" >&2
    echo "   or: . ${BASH_SOURCE[0]}" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  #!/bin/bash" >&2
    echo "  source ./text_handler.sh" >&2
    echo "  output_success 'Library loaded!'" >&2
    exit 1
  else
    # Script is being sourced
    _init_text_handler
  fi
}
