# ZFS Best Practices Specification

**Reference URL:** https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS%20for%20Raspberry%20Pi.html

**Document Purpose:** Technical specification for ZFS root filesystem implementation in Linux-based installer systems

---

## System Requirements

### Hardware Requirements
- **Memory:** Minimum 2 GiB RAM, recommended 4 GiB for normal performance
- **Storage:** Support for microSD, USB disk (SSD preferred for performance)
- **Architecture:** Support for ARM64 and x86_64 architectures
- **UEFI/BIOS:** Support for both UEFI and legacy BIOS booting

### Software Prerequisites
- Linux kernel with ZFS support
- ZFS utilities package (zfsutils-linux)
- Repository access for package installation

---

## ZFS Pool Configuration Standards

### Core Pool Settings
```bash
# Modern drive optimization
ashift=12                    # Standard for modern drives

# POSIX compliance
acltype=posixacl            # Enable POSIX ACL support
xattr=sa                    # Extended attributes in system attributes

# Unicode normalization
normalization=formD         # UTF-8 filename handling

# Performance optimization
compression=lz4             # Lightweight compression
autotrim=on                 # SSD optimization
relatime=on                 # Access time optimization
```

### Encryption Configuration Options

1. **Unencrypted** (Best Performance)
   - No encryption overhead
   - Fastest installation and runtime performance

2. **ZFS Native Encryption** (Recommended)
   - Algorithm: `aes-256-gcm`
   - Encrypts data and most metadata
   - Better integration with ZFS features

3. **LUKS Encryption**
   - Full disk encryption
   - Compatible with existing LUKS workflows
   - Additional encryption overhead

---

## Dataset Structure Architecture

### Root Pool Datasets
```
rpool/ROOT/linux           # OS root filesystem
rpool/ROOT/linux/srv       # Service data
rpool/ROOT/linux/usr       # User programs  
rpool/ROOT/linux/var       # Variable data
rpool/ROOT/linux/var/log   # System logs
rpool/ROOT/linux/var/tmp   # Temporary files
rpool/ROOT/linux/tmp       # Optional: temporary filesystem
```

### User Data Datasets
```
rpool/home                 # User home directories
rpool/home/user1          # Individual user datasets
```

### System Datasets
```
rpool/var/lib/docker      # Optional: Docker storage
rpool/var/snap            # Optional: Snap packages
```

---

## Performance Optimization Settings

### Memory Management
```bash
# Disable memory zeroing for performance
echo "init_on_alloc=0" >> kernel_parameters

# ARC (Adaptive Replacement Cache) tuning
# Let ZFS automatically manage ARC size
```

### Storage Optimization
```bash
# Record size optimization (dataset-specific)
recordsize=128K           # For databases
recordsize=1M             # For large files

# Synchronous write handling
sync=standard             # Default: data integrity
sync=disabled             # Performance mode (data loss risk)

# Log compression
logcompression=off        # Disable for performance
```

### Network and I/O
```bash
# Disable synchronous requests for faster performance (optional)
# WARNING: May result in data loss on power failure
sync=disabled
```

---

## Installation Process Framework

### Phase 1: System Preparation
1. Boot from live environment
2. Install ZFS utilities
3. Prepare target storage devices
4. Configure network connectivity

### Phase 2: Pool Creation
1. Partition target devices
2. Create root pool with optimal settings
3. Enable required ZFS features
4. Configure encryption (if selected)

### Phase 3: Dataset Structure
1. Create root filesystem datasets
2. Set dataset-specific properties
3. Create user data datasets
4. Configure dataset mount points

### Phase 4: System Installation
1. Mount ZFS datasets
2. Install base system
3. Configure system files
4. Install bootloader

### Phase 5: Bootloader Configuration
1. Update initramfs with ZFS support
2. Configure GRUB for ZFS root
3. Set kernel parameters
4. Enable ZFS services

---

## Security Considerations

### Encryption Best Practices
- Use ZFS native encryption for new installations
- Generate strong encryption keys
- Secure key storage and backup procedures
- Consider key rotation policies

### Dataset Permissions
```bash
# Secure user dataset creation
zfs create -o mountpoint=/home/user1 rpool/home/user1
chown user1:user1 /home/user1
chmod 750 /home/user1
```

### System Hardening
- Enable ZFS audit trail
- Configure proper ACLs
- Implement dataset quotas
- Monitor pool health

---

## Troubleshooting Guidelines

### Common Issues
1. **Boot failures:** Check initramfs ZFS modules
2. **Mount issues:** Verify dataset mount points
3. **Performance problems:** Review ARC settings
4. **Space issues:** Check snapshots and compression

### Recovery Procedures
1. Boot from live environment
2. Import existing pools
3. Mount datasets for repair
4. Use ZFS rollback capabilities

### Hardware Compatibility
- Verify controller support (avoid problematic Areca, MPT2SAS)
- Test with target hardware before deployment
- Document known compatibility issues

---

## Monitoring and Maintenance

### Health Monitoring
```bash
# Pool status checking
zpool status                # Overall pool health
zpool list                  # Capacity and usage
zfs list                    # Dataset information

# Automatic monitoring
systemctl enable zfs-zed    # ZFS Event Daemon
```

### Regular Maintenance
- Schedule scrub operations
- Monitor pool capacity
- Review system logs
- Update ZFS utilities

---

## Implementation Notes for Installer

### Integration Points
- Hardware detection must assess ZFS compatibility
- Memory requirements validation
- Storage device optimization recommendations
- Encryption decision workflow
- Performance expectations calculation

### Automation Considerations
- Default pool configurations per hardware type
- Intelligent dataset structure creation
- Automated encryption setup
- Performance tuning based on detected hardware

### Error Handling
- Pool creation failure recovery
- Storage device compatibility checks
- Memory requirement validation
- Bootloader installation verification

---

**Document Status:** Active specification for ZFS implementation
**Last Updated:** Based on OpenZFS documentation as of 2024
**Validation:** Requires testing across target hardware configurations