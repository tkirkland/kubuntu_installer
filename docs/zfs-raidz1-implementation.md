# ZFS RAID-Z1 Implementation Guide for Kubuntu Installer

## Extracted RAID-Z1 Logic from Proxmox

### 1. Disk Requirements Validation

```perl
# From Proxmox Install.pm lines 321-333
my $level = 1;  # For RAID-Z1
my $mindisks = 2 + $level;  # Minimum 3 disks for RAID-Z1
die "zfs (RAIDZ-$level): need at least $mindisks devices\n"
    if scalar(@$devlist) < $mindisks;
```

**Kubuntu Implementation**:
```bash
# Minimum disk validation for RAID-Z1
validate_raidz1_disks() {
    local -a disks
    disks=("$@")
    
    readonly MIN_DISKS_RAIDZ1
    MIN_DISKS_RAIDZ1=3
    
    if [[ ${#disks[@]} -lt $MIN_DISKS_RAIDZ1 ]]; then
        echo "ERROR: RAID-Z1 requires at least $MIN_DISKS_RAIDZ1 disks, found ${#disks[@]}" >&2
        return 1
    fi
    
    return 0
}
```

### 2. Disk Size Validation

```perl
# From Install.pm - All disks must be within 10% size of each other
sub zfs_mirror_size_check {
    my ($expected, $actual) = @_;
    die "mirrored disks must have same size\n"
        if abs($expected - $actual) > $expected / 10;
}
```

**Kubuntu Implementation**:
```bash
# Check all disks are similar size (within 10%)
check_disk_sizes() {
    local -a disk_sizes
    disk_sizes=("$@")
    
    local expected_size
    expected_size="${disk_sizes[0]}"
    
    local tolerance
    tolerance=$((expected_size / 10))
    
    local disk_num
    disk_num=1
    for size in "${disk_sizes[@]:1}"; do
        local diff
        diff=$((expected_size - size))
        diff=${diff#-}  # absolute value
        
        if [[ $diff -gt $tolerance ]]; then
            echo "ERROR: Disk $((disk_num + 1)) size mismatch (expected ~$expected_size, got $size)" >&2
            return 1
        fi
        ((disk_num++))
    done
    
    return 0
}
```

### 3. Complete ZFS Pool Creation Command

**Proxmox Actual Command Construction**:
```perl
# Pool creation with RAID-Z1
my $cmd = "zpool create -f -o cachefile=none";
$cmd .= " -o ashift=12";  # For 4K sector drives
$cmd .= " $pool_name raidz1";
foreach my $hd (@$devlist) {
    $cmd .= " @$hd[1]";  # Append each disk
}
```

**Kubuntu Bash Implementation**:
```bash
#!/bin/bash
# Complete RAID-Z1 pool creation following Proxmox logic and ZFS best practices

create_raidz1_pool() {
    local pool_name
    pool_name="$1"
    shift
    local -a disk_paths
    disk_paths=("$@")
    
    # Check for existing pool
    if zpool list "$pool_name" &>/dev/null; then
        local renamed_pool
        renamed_pool="${pool_name}-OLD-$(date +%s)"
        echo "WARNING: Pool '$pool_name' exists. Rename to '$renamed_pool'? (y/n)"
        read -r response
        if [[ "$response" == "y" ]]; then
            zpool export "$pool_name" || return 1
            zpool import "$pool_name" "$renamed_pool" || return 1
            zpool export "$renamed_pool" || return 1
        else
            return 1
        fi
    fi
    
    # Build the zpool create command
    local zpool_cmd
    zpool_cmd="zpool create"
    zpool_cmd+=" -f"                    # Force creation
    zpool_cmd+=" -o cachefile=none"     # Don't cache pool config
    zpool_cmd+=" -o ashift=12"          # 4K sectors (per ZFS best practices)
    zpool_cmd+=" -o autotrim=on"        # SSD optimization (from ZFS best practices)
    zpool_cmd+=" $pool_name"
    zpool_cmd+=" raidz1"                # RAID-Z1 configuration
    
    # Add all disk paths
    for disk in "${disk_paths[@]}"; do
        zpool_cmd+=" $disk"
    done
    
    echo "Executing: $zpool_cmd"
    eval "$zpool_cmd" || return 1
    
    # Create dataset structure per Proxmox + ZFS best practices
    echo "Creating dataset structure..."
    zfs create "${pool_name}/ROOT" || return 1
    zfs create "${pool_name}/ROOT/ubuntu" || return 1
    zfs create "${pool_name}/home" || return 1
    
    # Set properties per ZFS best practices document
    echo "Setting ZFS properties..."
    
    # Core settings from best practices
    zfs set atime=on "${pool_name}"
    zfs set relatime=on "${pool_name}"
    zfs set compression=lz4 "${pool_name}"
    zfs set acltype=posixacl "${pool_name}"
    zfs set xattr=sa "${pool_name}"
    zfs set normalization=formD "${pool_name}"
    
    # Root dataset specific
    zfs set mountpoint=/ "${pool_name}/ROOT/ubuntu"
    
    # Home dataset
    zfs set mountpoint=/home "${pool_name}/home"
    
    return 0
}
```

### 4. Disk Detection with Filesystem Check

**Missing in Proxmox - Added for Safety**:
```bash
# Detect existing filesystems before any destructive operations
check_existing_filesystems() {
    local disk
    disk="$1"
    
    echo "Checking $disk for existing filesystems..."
    
    # Check for ZFS labels
    if zpool labelclear -n "$disk" &>/dev/null; then
        echo "  WARNING: ZFS pool detected on $disk"
        return 1
    fi
    
    # Check for other filesystems
    local fs_type
    fs_type=$(blkid -o value -s TYPE "$disk" 2>/dev/null)
    if [[ -n "$fs_type" ]]; then
        echo "  WARNING: $fs_type filesystem detected on $disk"
        return 1
    fi
    
    # Check partitions
    local parts
    parts=$(lsblk -n -o NAME "$disk" | tail -n +2)
    if [[ -n "$parts" ]]; then
        echo "  WARNING: Existing partitions detected on $disk"
        for part in $parts; do
            local part_fs
            part_fs=$(blkid -o value -s TYPE "/dev/$part" 2>/dev/null)
            [[ -n "$part_fs" ]] && echo "    - /dev/$part: $part_fs"
        done
        return 1
    fi
    
    echo "  No existing filesystems detected"
    return 0
}
```

### 5. Complete Disk Preparation

```bash
# Prepare disks for ZFS RAID-Z1
prepare_disks_for_zfs() {
    local -a disks
    disks=("$@")
    
    echo "Preparing disks for ZFS RAID-Z1..."
    
    # Check each disk
    local warnings
    warnings=0
    for disk in "${disks[@]}"; do
        if ! check_existing_filesystems "$disk"; then
            ((warnings++))
        fi
    done
    
    if [[ $warnings -gt 0 ]]; then
        echo ""
        echo "WARNING: Existing data detected on $warnings disk(s)"
        echo "This operation will DESTROY ALL DATA on the selected disks!"
        echo "Continue? (type 'yes' to confirm)"
        read -r response
        if [[ "$response" != "yes" ]]; then
            echo "Operation cancelled"
            return 1
        fi
    fi
    
    # Wipe disks
    echo "Wiping disks..."
    for disk in "${disks[@]}"; do
        echo "  Wiping $disk..."
        
        # Clear partition table
        sgdisk -Z "$disk" &>/dev/null
        
        # Clear any ZFS labels
        zpool labelclear -f "$disk" &>/dev/null
        
        # Wipe filesystem signatures
        wipefs -a "$disk" &>/dev/null
        
        # Zero out first and last 1MB
        dd if=/dev/zero of="$disk" bs=1M count=1 &>/dev/null
        dd if=/dev/zero of="$disk" bs=1M count=1 seek=$(($(blockdev --getsz "$disk") / 2048 - 1)) &>/dev/null
    done
    
    # Ensure kernel sees the changes
    partprobe "${disks[@]}" 2>/dev/null
    udevadm settle
    
    return 0
}
```

### 6. Partitioning for ZFS Boot

```bash
# Partition disks for ZFS root with boot support
partition_for_zfs_boot() {
    local disk
    disk="$1"
    local boot_mode
    boot_mode="$2"  # "uefi" or "bios"
    
    echo "Partitioning $disk for ZFS boot ($boot_mode mode)..."
    
    # Clear existing partitions
    sgdisk -Z "$disk"
    
    if [[ "$boot_mode" == "uefi" ]]; then
        # UEFI layout
        # Part 1: EFI System Partition (1GB for multiple kernels)
        # Part 2: ZFS partition (rest)
        sgdisk -n1:1M:+1024M -t1:EF00 "$disk"
        sgdisk -n2:0:0 -t2:BF01 "$disk"
        
        # Format EFI partition
        mkfs.vfat -F32 "${disk}1"
    else
        # BIOS layout
        # Part 1: BIOS boot partition (1MB)
        # Part 2: ZFS partition (rest)
        sgdisk -a1 -n1:34:2047 -t1:EF02 "$disk"
        sgdisk -n2:0:0 -t2:BF01 "$disk"
    fi
    
    # Inform kernel of partition changes
    partprobe "$disk"
    udevadm settle
    
    return 0
}
```

### 7. Main Installation Flow

```bash
# Main RAID-Z1 installation workflow
install_kubuntu_zfs_raidz1() {
    echo "=== Kubuntu ZFS RAID-Z1 Installer ==="
    
    # Step 1: Detect disks
    echo "Step 1: Detecting available disks..."
    local -a available_disks
    mapfile -t available_disks < <(find /dev/disk/by-id -name "ata-*" -o -name "nvme-*" | grep -v "part[0-9]")
    
    # Step 2: Display disks for selection
    echo "Step 2: Select disks for RAID-Z1 (minimum 3)"
    local i
    i=0
    for disk in "${available_disks[@]}"; do
        local size_bytes
        size_bytes=$(blockdev --getsize64 "$disk" 2>/dev/null)
        local size_gb
        size_gb=$((size_bytes / 1024 / 1024 / 1024))
        echo "  [$i] $disk (${size_gb}GB)"
        ((i++))
    done
    
    # Step 3: Get user selection
    echo "Enter disk numbers separated by spaces (e.g., '0 1 2 3'):"
    read -r -a selections
    
    local -a selected_disks
    for sel in "${selections[@]}"; do
        selected_disks+=("${available_disks[$sel]}")
    done
    
    # Step 4: Validate selection
    echo "Step 4: Validating disk selection..."
    validate_raidz1_disks "${selected_disks[@]}" || return 1
    
    # Step 5: Check disk sizes
    local -a disk_sizes
    for disk in "${selected_disks[@]}"; do
        disk_sizes+=($(blockdev --getsize64 "$disk"))
    done
    check_disk_sizes "${disk_sizes[@]}" || return 1
    
    # Step 6: Prepare disks
    echo "Step 6: Preparing disks..."
    prepare_disks_for_zfs "${selected_disks[@]}" || return 1
    
    # Step 7: Determine boot mode
    local boot_mode
    if [[ -d /sys/firmware/efi ]]; then
        boot_mode="uefi"
    else
        boot_mode="bios"
    fi
    echo "Boot mode: $boot_mode"
    
    # Step 8: Partition first disk for boot
    echo "Step 8: Partitioning boot disk..."
    partition_for_zfs_boot "${selected_disks[0]}" "$boot_mode" || return 1
    
    # Step 9: Create RAID-Z1 pool
    echo "Step 9: Creating ZFS RAID-Z1 pool..."
    local -a zfs_partitions
    if [[ "$boot_mode" == "uefi" ]]; then
        zfs_partitions=("${selected_disks[0]}2")  # Partition 2 on first disk
    else
        zfs_partitions=("${selected_disks[0]}2")  # Partition 2 on first disk
    fi
    
    # Add whole disks for remaining drives
    for disk in "${selected_disks[@]:1}"; do
        zfs_partitions+=("$disk")
    done
    
    create_raidz1_pool "rpool" "${zfs_partitions[@]}" || return 1
    
    echo "=== RAID-Z1 pool created successfully ==="
    zpool status rpool
    
    return 0
}
```

## Command Sequence Summary

Based on Proxmox installer analysis, the exact command sequence for RAID-Z1:

1. **Disk Detection**:
   ```bash
   find /dev/disk/by-id -name "ata-*" -o -name "nvme-*" | grep -v "part"
   ```

2. **Disk Wiping**:
   ```bash
   sgdisk -Z /dev/disk/by-id/ata-XXX
   wipefs -a /dev/disk/by-id/ata-XXX
   ```

3. **Partitioning** (for boot disk):
   ```bash
   # UEFI
   sgdisk -n1:1M:+1024M -t1:EF00 /dev/disk/by-id/ata-XXX
   sgdisk -n2:0:0 -t2:BF01 /dev/disk/by-id/ata-XXX
   ```

4. **Pool Creation**:
   ```bash
   zpool create -f -o cachefile=none -o ashift=12 rpool raidz1 \
     /dev/disk/by-id/ata-XXX-part2 \
     /dev/disk/by-id/ata-YYY \
     /dev/disk/by-id/ata-ZZZ
   ```

5. **Dataset Creation**:
   ```bash
   zfs create rpool/ROOT
   zfs create rpool/ROOT/ubuntu
   zfs set mountpoint=/ rpool/ROOT/ubuntu
   ```

6. **Property Setting**:
   ```bash
   zfs set compression=lz4 rpool
   zfs set atime=on relatime=on rpool
   zfs set acltype=posixacl rpool
   zfs set xattr=sa rpool
   ```

This implementation matches Proxmox's approach while incorporating the ZFS best practices from your documentation.