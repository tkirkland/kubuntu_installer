# Kubuntu Installer Project - Claude Configuration

## Project Context

This is a **Linux system installer automation project** focused on ZFS root filesystem installations. You are working with **production-critical system installation scripts** that perform destructive disk operations.

### Critical Safety Notices

⚠️ **DESTRUCTIVE OPERATIONS**: Scripts in this project perform disk partitioning, formatting, and system installation. These operations are **irreversible** and will **erase all data** on target disks.

🔒 **TESTING REQUIREMENTS**:
- All scripts must be tested in isolated environments (VMs or dedicated hardware)
- Never execute these scripts on production systems or systems with important data
- Always verify target disk selection before proceeding

🛡️ **ROOT PRIVILEGES**: All installer scripts require root/sudo access and should be executed only in live ISO environments.

## Project-Specific Instructions

### 1. Code Modification Guidelines

When modifying installer scripts:

1. **NEVER remove or bypass safety confirmations**
2. **ALWAYS maintain error handling and cleanup mechanisms**
3. **PRESERVE trap handlers** for EXIT, INT, TERM, HUP signals
4. **MAINTAIN pool tracking** for proper ZFS cleanup
5. **VERIFY chroot handling** to prevent orphaned processes

### 2. Shell Scripting Standards

This project strictly follows the **Google Shell Style Guide**:

```bash
# Mandatory script options
set -Eeuo pipefail

# Function documentation is REQUIRED
#######################################
# Brief description
# Globals:
#   VAR_NAME
# Arguments:
#   $1 - description
# Returns:
#   0 on success, 1 on failure
#######################################
function_name() {
  local var="$1"
  # implementation
}

# Variable quoting is MANDATORY
echo "${var}"           # ✓ Correct
echo $var               # ✗ Wrong

# Modern syntax preferences
result="$(command)"     # ✓ Correct
result=`command`        # ✗ Wrong

# Test conditions
[[ -f "${file}" ]]      # ✓ Correct
[ -f "$file" ]          # ✗ Avoid
```

### 3. Output Formatting Requirements

Use the `libs/string_output.sh` library for ALL user-facing output:

```bash
# Source library first
source "${script_dir}/libs/string_output.sh"

# Use prefix-color-only mode for cleaner output
output_text -P -l info "Informational message"
output_text -P -l success "Operation completed successfully"
output_text -P -l warning "Potential issue detected"
output_text -P -l error "Operation failed"

# For internal error logging (trap handlers, cleanup)
err "Internal error message"  # Auto-uses output_internal() when available
# Or use directly:
output_internal "Low-level system event"  # [YYYY-MM-DD HH:MM:SS]: message
```

**Logging Level Guidelines:**

| Function | Use Case | Format | Color | Reliability |
|----------|----------|--------|-------|-------------|
| `output_info()` | User notifications | `[INFO] msg` | Blue | Normal |
| `output_success()` | Confirmations | `[SUCCESS] msg` | Green | Normal |
| `output_warning()` | Non-critical issues | `[WARNING] msg` | Yellow | Normal |
| `output_error()` | User-facing errors | `[ERROR] msg` | Red | Normal |
| `output_internal()` | Trap/cleanup logging | `[YYYY-MM-DD HH:MM:SS]: msg` | None | High |
| `err()` | Enhanced wrapper | Auto-detects library | None | Maximum |

### 4. ZFS Best Practices

When working with ZFS operations, adhere to the specifications in `docs/zfs-best-practices-spec.md`:

**Pool Creation Standards:**
```bash
zpool create -f \
  -o ashift=12 \
  -o autotrim=on \
  -O mountpoint=none \
  -O acltype=posixacl \
  -O atime=off \
  -O relatime=off \
  -O xattr=sa \
  -O normalization=formD \
  -O compression=lz4 \
  -R /mnt \
  rpool /dev/disk/by-partuuid/${partuuid}
```

**Dataset Structure:**
- Root: `rpool/ROOT/linux`
- Home: `rpool/home`
- Variable data: `rpool/ROOT/linux/var`
- Logs: `rpool/ROOT/linux/var/log`

### 5. Error Handling Requirements

Every function that performs critical operations must:

1. **Check prerequisites** before execution
2. **Validate inputs** before processing
3. **Track resources** for cleanup (pools, mounts, chroot)
4. **Return meaningful exit codes** (0 = success, non-zero = failure)
5. **Log errors to stderr** with context and timestamps

**Choosing the Right Logging Function:**

```bash
# User-facing errors (validation, configuration)
if [[ ! -f "${config_file}" ]]; then
  output_text -P -l error "Configuration file not found: ${config_file}"
  return 1
fi

# Internal errors (trap handlers, cleanup, low-level)
if [[ ! -b "${disk}" ]]; then
  err "Disk ${disk} does not exist"  # Auto-fallback to printf if lib fails
  return 1
fi

# Direct library use (when library is known to be loaded)
if ! zpool create ...; then
  output_internal "Failed to create pool ${pool_name}"
  return 1
fi
```

**Example Pattern:**
```bash
create_zfs_pool() {
  local disk="$1"
  local pool_name="$2"

  # Validate with user-facing error
  if [[ ! -b "${disk}" ]]; then
    output_text -P -l error "Invalid disk: ${disk}"
    return 1
  fi

  # Execute with error checking
  if ! zpool create ...; then
    # Internal error logging (trap-safe)
    err "Failed to create pool ${pool_name}"
    return 1
  fi

  # Track for cleanup
  pools_created+=("${pool_name}")

  # Success confirmation
  output_text -P -l success "Pool ${pool_name} created successfully"
  return 0
}
```

### 6. Testing and Validation

Before committing any changes:

```bash
# 1. ShellCheck validation (REQUIRED)
shellcheck zfs_installer.sh
shellcheck installer.sh
find libs -name "*.sh" -exec shellcheck {} \;

# 2. Syntax validation
bash -n zfs_installer.sh

# 3. Manual testing in VM/ISO
# Boot live ISO with ZFS support
# Run script with test disk
# Verify all operations complete successfully
# Test cleanup on errors (Ctrl+C during operation)

# 4. Code review checklist
# - All functions documented
# - Variables quoted
# - Error handling present
# - Cleanup handlers working
# - Line length ≤ 84 chars
```

### 7. Calamares Configuration

When modifying Calamares configuration files:

1. **Validate YAML syntax** before committing
2. **Test in Calamares GUI** if possible
3. **Document module dependencies** in comments
4. **Preserve existing branding structure**
5. **Update settings.conf sequence** if adding/removing modules

### 8. Documentation Requirements

When adding new features or functions:

1. **Update relevant docs/** files
2. **Add inline comments** for complex logic
3. **Document external dependencies**
4. **Update CLAUDE.md** if changing project structure
5. **Keep Serena memories updated** via `mcp__serena__write_memory`

## Development Workflow

### Typical Development Cycle

```bash
# 1. Start session - load project context
/sc:load  # If using SuperClaude session management

# 2. Make changes following style guide

# 3. Validate with shellcheck
shellcheck modified_file.sh

# 4. Test in safe environment (VM)

# 5. Commit with descriptive message
git add modified_file.sh
git commit -m "feat: add RAID-Z1 pool creation support

- Implemented multi-disk pool creation
- Added disk validation and size checking
- Updated cleanup to handle RAID pools
- Added comprehensive error handling"

# 6. Save session context
/sc:save  # If using SuperClaude session management
```

### When to Use Which Script

**installer.sh**:
- Simple single-disk ZFS installations
- Testing basic ZFS functionality
- Minimal configuration requirements
- Learning and experimentation

**zfs_installer.sh**:
- Production installations
- Advanced ZFS configurations
- Complex error scenarios
- OEM/deployment scenarios

## Common Operations

### Adding a New ZFS Dataset

```bash
# 1. Plan the dataset hierarchy
# 2. Add creation logic to dataset setup section
# 3. Set appropriate properties (compression, mountpoint, etc.)
# 4. Update documentation
# 5. Test dataset creation and mounting

zfs create -o compression=lz4 -o mountpoint=/var/cache rpool/ROOT/linux/varcache
```

### Modifying Bootloader Configuration

```bash
# 1. Update initramfs configuration
# 2. Modify kernel command line parameters
# 3. Regenerate initramfs
# 4. Test boot process in VM
# 5. Verify ZFS pool import on boot
```

### Adding New Output Messages

```bash
# Use the output library consistently
output_text -P -l info "Starting disk partitioning..."
output_text -P -l success "Partitioning completed successfully"

# For errors that should stop execution
if ! partition_disk "${disk}"; then
  output_text -P -l error "Disk partitioning failed"
  return 1
fi
```

## Architecture Insights

### Global State Management

The project uses global state tracking for cleanup:

```bash
declare -g cleanup_in_progress=0 chroot_active=0 script_dir=""
declare -ga pools_created=()  # Array of created pools for cleanup
```

**Why this pattern?**
- Cleanup must work from signal handlers (trap)
- Must handle interruptions at any point
- Prevents resource leaks (mounted filesystems, imported pools)

### Trap Mechanism

```bash
trap 'err_handler ${LINENO} $?' ERR
trap cleanup EXIT INT TERM HUP
```

**Execution flow:**
1. Error occurs → `err_handler` logs context
2. Exit/signal → `cleanup` performs cleanup
3. Cleanup checks `cleanup_in_progress` to prevent recursion
4. Exports pools in reverse order of creation

### Library Architecture

`libs/string_output.sh` provides:
- Consistent output formatting
- Color management with ANSI codes
- Box drawing and tables
- Text wrapping and alignment
- Separation of concerns (presentation vs. logic)

## Project-Specific Personas

When working on this project, adopt these mindsets:

### 🛡️ Safety Engineer
- Validate all destructive operations
- Implement confirmation prompts
- Design robust cleanup mechanisms
- Test error scenarios extensively

### 📚 Documentation Specialist
- Maintain clear function documentation
- Keep inline comments updated
- Document assumptions and limitations
- Provide examples for complex operations

### 🔧 Systems Architect
- Understand ZFS architecture
- Design proper dataset hierarchies
- Configure optimal pool settings
- Plan for recovery scenarios

## Quick Reference

### File Locations
- **Main scripts**: `./zfs_installer.sh`, `./installer.sh`
- **Libraries**: `./libs/string_output.sh`
- **Documentation**: `./docs/`
- **Calamares config**: `./calamares/`
- **Manual instructions**: `./instruct.txt`

### Key Constants
- **Max line length**: 84 characters
- **Indentation**: 2 spaces (no tabs)
- **ZFS ashift**: 12 (for modern drives)
- **Default compression**: lz4
- **Boot mode**: UEFI with systemd-boot

### Critical Files to Never Modify Carelessly
- `libs/string_output.sh` (used by multiple scripts)
- Calamares `settings.conf` (module sequence order matters)
- `.editorconfig` (ensures consistent formatting)

## Integration with SuperClaude Framework

This project works with your global SuperClaude framework:

- **MCP Serena**: Use for project memory, symbol navigation, and session persistence
- **Sequential Thinking**: Use for complex debugging of installation failures
- **Token Efficiency Mode**: Activate when analyzing large configuration files

### Recommended Workflow Modes

**For debugging installation issues:**
```
--think-hard --serena --sequential
```

**For code modifications:**
```
--task-manage --serena
```

**For documentation updates:**
```
--token-efficient
```

## Final Reminders

1. ✅ **ALWAYS test in VMs/live ISO before committing**
2. ✅ **NEVER skip shellcheck validation**
3. ✅ **PRESERVE existing error handling patterns**
4. ✅ **MAINTAIN function documentation standards**
5. ✅ **UPDATE Serena memories when project structure changes**
6. ✅ **FOLLOW Google Shell Style Guide religiously**
7. ✅ **TEST cleanup and error scenarios**
8. ⚠️ **REMEMBER: These scripts can destroy data - handle with care**

---

**Project Status**: Active development
**Last Updated**: 2025-10-10
**Validation**: All scripts must pass shellcheck with zero warnings
