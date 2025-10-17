# Kubuntu Installer

Automated installation scripts for Linux distributions with ZFS root filesystem support, including Calamares installer configuration.

## ⚠️ Warning

**These scripts perform destructive disk operations that will erase all data on the target disk.**

- Only run in live ISO environments
- Never execute on systems with important data
- Always verify target disk selection before proceeding
- Requires root/sudo privileges

## Features

- **Automated ZFS Root Installation** - Single-disk and RAID-Z1 configurations
- **UEFI Boot Support** - systemd-boot with Unified Kernel Images (UKI)
- **Calamares Integration** - Pre-configured installer for Kubuntu
- **Comprehensive Error Handling** - Automatic cleanup on failures
- **OEM Mode Support** - Configuration for OEM installations

## Components

### Installation Scripts

- `zfs_installer.sh` - Full-featured ZFS installer with advanced error handling
- `installer.sh` - Simplified Arch Linux ZFS installer
- `libs/string_output.sh` - Shared output formatting library

### Calamares Configuration

- `calamares/` - Complete Calamares installer configuration
- `calamares/modules/` - Module configurations for partitioning, users, bootloader, etc.
- `calamares/branding/kubuntu/` - Kubuntu branding assets and slideshow

### Documentation

- `instruct.txt` - Manual installation instructions
- `docs/google-shell-style-guide.md` - Coding standards
- `docs/zfs-best-practices-spec.md` - ZFS implementation guidelines
- `docs/zfs-raidz1-implementation.md` - RAID-Z1 setup documentation

## Quick Start

### Prerequisites

Boot from a Linux live ISO with ZFS support (e.g., Arch Linux LTS ZFS ISO):
- https://github.com/r-maerz/archlinux-lts-zfs

### Basic Installation

**⚠️ Important**: This project uses Git submodules for external libraries. You must clone with submodules or initialize them manually.

**Option 1: Clone with submodules (recommended)**
```bash
# Clone repository with all submodules
git clone --recursive https://github.com/tkirkland/kubuntu_installer.git
cd kubuntu_installer

# Run the installer (as root)
sudo ./zfs_installer.sh
```

**Option 2: Clone then initialize submodules**
```bash
# Standard clone
git clone https://github.com/tkirkland/kubuntu_installer.git
cd kubuntu_installer

# Initialize and update submodules
git submodule update --init --recursive

# Run the installer (as root)
sudo ./zfs_installer.sh
```

**Submodule Libraries:**
- `libs/input.sh` - Controlled input library (https://github.com/tkirkland/input.sh)
- `libs/string_output.sh` - Output formatting library (https://github.com/tkirkland/string_output.sh)

### Manual Installation

Follow the step-by-step instructions in `instruct.txt` for manual ZFS root setup.

## System Requirements

- **Boot Mode**: UEFI (recommended)
- **Architecture**: x86_64 or ARM64
- **Memory**: Minimum 2 GB RAM, recommended 4 GB
- **Disk**: Single disk or multiple disks for RAID configurations

## ZFS Configuration

The installer creates the following ZFS structure:

```
rpool/ROOT/linux              # OS root filesystem
├── /home                     # User home directories
├── /var/cache                # Cache data
└── /var/log                  # System logs
```

**Pool Settings:**
- ashift=12 (4K sector alignment)
- compression=lz4 (lightweight compression)
- autotrim=on (SSD optimization)
- acltype=posixacl (POSIX ACL support)

## Development

### Code Standards

This project follows the [Google Shell Style Guide](docs/google-shell-style-guide.md):

- 2-space indentation (no tabs)
- Maximum line length: 84 characters
- All scripts use `set -Eeuo pipefail`
- Comprehensive function documentation required

### Testing

```bash
# Validate scripts with shellcheck
shellcheck zfs_installer.sh
shellcheck installer.sh

# Check syntax
bash -n zfs_installer.sh

# Test in VM or live ISO environment
```

### Project Structure

```
kubuntu_installer/
├── zfs_installer.sh          # Main installer script
├── installer.sh              # Simplified installer
├── libs/                     # Shared libraries (Git submodules)
│   ├── input.sh/             # Controlled input library (submodule)
│   └── string_output.sh/     # Output formatting library (submodule)
├── calamares/                # Calamares configuration
│   ├── modules/              # Module configs
│   ├── branding/             # Branding assets
│   └── settings.conf         # Main settings
├── docs/                     # Documentation
│   ├── git-submodules.md     # Submodule management guide
│   └── ...                   # Other documentation
└── instruct.txt              # Manual instructions
```

**Note**: Files in `libs/` are Git submodules maintained in separate repositories. Do not modify these files directly.

## Contributing

1. Follow the Google Shell Style Guide
2. Run shellcheck on all modified scripts
3. Test in isolated environment (VM or live ISO)
4. Document all functions with structured comments
5. Maintain error handling and cleanup mechanisms

## License

See LICENSE file for details.

## Support

For issues, questions, or contributions, please refer to the project documentation in the `docs/` directory.

---

**Safety First**: Always backup important data before running system installers. Test in virtual machines before deploying to physical hardware.
