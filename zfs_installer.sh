#!usr/bin/env bash
# shellcheck shell=bash

# NOTE FOR AI: The following libraries are Git submodules with their own repositories.
# DO NOT modify files in libs/input.sh or libs/string_output.sh
# These are maintained separately at:
# - libs/input.sh: https://github.com/tkirkland/input.sh
# - libs/string_output.sh: https://github.com/tkirkland/string_output.sh

set -Eeuo pipefail

# ============================================================================
# GLOBAL STATE TRACKING
# ============================================================================
declare -g cleanup_in_progress=0
declare -g chroot_active=0
declare -g script_dir=""
declare -g _txt
declare -ga pools_created=()
declare -g disk
declare -g user_name
declare -g host_name="hostname"
declare -g pool_name="zroot"
declare -g swap_size="4"
declare -g time_zone="UTC"
declare -g kernel="linux"

#######################################
# Print error message to stderr with timestamp
# Uses output_internal() from string_output.sh
# Globals:
#   None
# Arguments:
#   Error message
# Outputs:
#   Writes error to stderr with format: [YYYY-MM-DD HH:MM:SS]: message
#######################################
err() {
    output_internal "$*"
}

#######################################
# Error handler with detailed context
# Provides line numbers, function call stack, and error codes
# for debugging trapped ERR signals
# Globals:
#   LINENO, BASH_LINENO, FUNCNAME, BASH_SOURCE
# Arguments:
#   None (captures context from trap)
# Outputs:
#   Writes detailed error context to stderr
#######################################
err_handler() {
  local line_num="${1:-unknown}"
  local exit_code="${2:-$?}"
  local func_name="${FUNCNAME[1]:-main}"
  local i

  # Build error context message
  err "════════════════════════════════════════════════"
  err "ERROR TRAP TRIGGERED"
  err "════════════════════════════════════════════════"
  err "Exit Code: ${exit_code}"
  err "Failed at: ${BASH_SOURCE[1]:-$0}:${line_num}"
  err "Function: ${func_name}"

  # Show the function call stack if available
  if [[ ${#FUNCNAME[@]} -gt 2 ]]; then
    err "Call Stack:"
    for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
      err "  [$((i - 1))] ${FUNCNAME[i]} @ ${BASH_SOURCE[i]}:${BASH_LINENO[i - 1]}"
    done
  fi

  err "════════════════════════════════════════════════"
}

#######################################
# Cleanup function for emergency exits
# Handles chroot exit, filesystem unmounting, and ZFS pool export
# Globals:
#   cleanup_in_progress, chroot_active, pools_created
# Arguments:
#   None (uses $? internally)
# Outputs:
#   Status messages to stderr
#######################################
cleanup() {
  local exit_code=$?
  local pid fs i

  # Prevent recursive cleanup
  if [[ ${cleanup_in_progress} -eq 1 ]]; then
    return 0
  fi
  cleanup_in_progress=1

  # Disable traps to prevent recursion
  trap - EXIT ERR INT TERM HUP

  # Handle chroot exit
  if [[ ${chroot_active} -eq 1 ]]; then
    err "ERROR: Cleanup triggered from within chroot (exit code: ${exit_code})"
    err "ERROR: Manual cleanup required"
    chroot_active=0
    exit "${exit_code}"
  fi

  # Only cleanup on error
  if [[ ${exit_code} -ne 0 ]]; then
    output_text -P -l error "Emergency cleanup triggered (exit code: ${exit_code})"

    # Kill processes using /mnt
    output_text -P -l warning "Terminating processes using /mnt..."
    local -a pids_to_kill=()
    for pid in $(lsof -t /mnt 2> /dev/null || true); do
      if [[ -e "/proc/${pid}/root" ]]; then
        local proc_root
        proc_root=$(readlink -f "/proc/${pid}/root" 2> /dev/null || true)
        if [[ ${proc_root} == "/mnt"   ]] || [[ ${proc_root} == "/mnt/"*   ]]; then
          pids_to_kill+=("${pid}")
        fi
      fi
    done

    if [[ ${#pids_to_kill[@]} -gt 0 ]]; then
      for pid in "${pids_to_kill[@]}"; do
        kill -TERM "${pid}" 2> /dev/null || true
      done
      sleep 1
      for pid in "${pids_to_kill[@]}"; do
        if [[ -e "/proc/${pid}" ]]; then
          kill -KILL "${pid}" 2> /dev/null || true
        fi
      done
      sleep 1
    fi

    # Unmount filesystems
    for fs in sys/firmware/efi/efivars dev/pts dev sys proc boot/efi; do
      umount -f "/mnt/${fs}" 2> /dev/null || true
    done
    umount -R -f /mnt 2> /dev/null || true

    # Export ZFS pools in reverse order
    if [[ ${#pools_created[@]} -gt 0 ]]; then
      for ((i = ${#pools_created[@]} - 1; i >= 0; i--)); do
        zpool export -f "${pools_created[i]}" 2> /dev/null || true
      done
    fi
    output_text -P -l success "Emergency cleanup completed."
  fi

  exit "${exit_code}"
}

#######################################
# Checks if the current user has su rights
# Globals:
#   EUID
# Arguments:
#  None
#######################################
require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

#######################################
# Get Confirmation
# Globals:
#   ans
# Arguments:
#   1
#######################################
confirm() {
  local prompt=${1:-"Continue?"} ans
  read -r -p "$prompt [y/N]: " ans || true
  [[ ${ans,,} == y ]]
}

#######################################
# Sets the correction Partition Name
# ! TODO: Fix to use /dev/by-disk-id
# Arguments:
#   1
#   2
#######################################
part_name() {
  # Echoes partition path (handles /dev/sdX vs /dev/nvme0n1 style)
  local disk="$1" idx="$2"
  if [[ $disk =~ (nvme|mmcblk|loop)   ]]; then
    echo "${disk}p${idx}"
  else
    echo "${disk}${idx}"
  fi
}

#######################################
# Ensure that all external libs exist
# Globals:
#   script_dir
# Arguments:
#  None
# Returns:
#  0 - All present
#  1 - If one or more missing
#######################################
# shellcheck disable=SC1091
verify_libs_exist() {
  local lib_dir="${script_dir}/libs/"
  local -a libs=("string_output.sh")
  local lib=""

  # Check if libraries exist before sourcing
  for lib in "${libs[@]}"; do
    if [[ ! -f "${lib_dir}${lib}" ]]; then
      echo "ERROR: Required library not found: ${script_dir}${lib}" >&2
      echo "Please ensure the library exists in the script directory" >&2
      exit 1
    fi
    # shellcheck source=${lib_dir}${lib}
    source "${lib_dir}${lib}"
  done
}

#######################################
# Parse command line arguments
# Globals:
#   disk, user_name, host_name, pool_name, swap_size, timezone, kernel
# Arguments:
#   Command line arguments
#######################################
parse_args() {
  local opt
  while getopts "d:u:h:p:s:t:k:" opt; do
    case $opt in
      d) disk="$OPTARG" ;;
      u) user_name="$OPTARG" ;;
      h) host_name="$OPTARG" ;;
      p) pool_name="$OPTARG" ;;
      s) swap_size="$OPTARG" ;;
      t) time_zone="$OPTARG" ;;
      k) kernel="$OPTARG" ;;
      *) return 1 ;;
    esac
  done
}

#######################################
# Validate disk parameter if provided via CLI
# Globals:
#   disk
# Arguments:
#   None
#######################################
validate_params() {
  # Only validate the disk if it was provided via command line
  if [[ -n ${disk:-} ]] && [[ ! -b ${disk} ]]; then
    output_text -P -l error "Invalid disk device: ${disk}"
    exit 1
  fi
}

#######################################
# Main code thread
# Arguments:
#   Command line arguments
#######################################
main() {
  # Get script directory
  local boot_part root_part disk partuuid
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  readonly script_dir

  # Execute main if this script is run directly
  if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
    return 0
  fi

  # Set traps for error handling and cleanup
  trap 'err_handler ${LINENO} $?' ERR
  trap cleanup EXIT INT TERM HUP

  # Load required libraries
  verify_libs_exist

  # Check root access
  require_root

  # Parse and validate arguments
  parse_args "$@"
  validate_params

  _txt="This script will perform a DESTRUCTIVE install to a target disk with ZFS root."
  _txt+=" Use this script ONLY in a Linux live ISO environment with network access."
  output_text -w "${_txt}"
  echo ""

  output_text -P -l info "Checking internet access..."

  if ! ping -c 1 -W 2 archlinux.org > /dev/null 2>&1; then
    _txt="Network connectivity confirmed."
    output_text -P -l success "${_txt}"
  else
    _txt="Ping failed; continuing anyway. Some features may require internet connectivity."
    output_text -w -P -l warning "${_txt}"
  fi
  timedatectl set-ntp true || true

}

main "$@"
