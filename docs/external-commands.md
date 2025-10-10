# External Commands Reference

## Complete List of System Commands Used by Proxmox Installer

### ZFS Commands

| Command | Usage | Purpose |
|---------|-------|---------|
| `zpool create` | `zpool create -f -o cachefile=none -o ashift=12 $pool_name raidz1 $disk1 $disk2 $disk3` | Create RAID-Z1 pool |
| `zpool list` | `zpool list $pool_name` | Check if pool exists |
| `zpool import` | `zpool import` | List importable pools |
| `zpool import -f` | `zpool import -f $poolid $new_name` | Import and rename pool |
| `zpool export` | `zpool export $pool_name` | Export pool |
| `zpool labelclear` | `zpool labelclear -f $partition` | Clear ZFS labels |
| `zpool status` | `zpool status` | Check pool status |
| `zfs create` | `zfs create $pool_name/ROOT` | Create dataset |
| `zfs set` | `zfs set compression=lz4 $pool_name` | Set properties |
| `zfs list` | `zfs list` | List datasets |

### Disk Management Commands

| Command | Usage | Purpose |
|---------|-------|---------|
| `sgdisk` | `sgdisk -Z $disk` | Clear GPT partition table |
| `sgdisk` | `sgdisk -n1:1M:+1024M -t1:EF00 $disk` | Create EFI partition |
| `sgdisk` | `sgdisk -n2:0:0 -t2:BF01 $disk` | Create ZFS partition |
| `sgdisk` | `sgdisk -a1 -n1:34:2047 -t1:EF02 $disk` | Create BIOS boot partition |
| `lsblk` | `lsblk --output kname --noheadings --path --list $disk` | List block devices |
| `blockdev` | `blockdev --getsize64 $disk` | Get disk size in bytes |
| `blockdev` | `blockdev --getsz $disk` | Get disk size in sectors |
| `wipefs` | `wipefs -a $disk` | Wipe filesystem signatures |
| `dd` | `dd if=/dev/zero of=$part bs=1M count=256` | Zero out partition |
| `partprobe` | `partprobe $disk` | Inform kernel of partition changes |
| `blkid` | `blkid -o value -s TYPE $disk` | Detect filesystem type |

### Filesystem Commands

| Command | Usage | Purpose |
|---------|-------|---------|
| `mkfs.ext4` | `mkfs.ext4 -F $partition` | Create ext4 filesystem |
| `mkfs.xfs` | `mkfs.xfs -f $partition` | Create XFS filesystem |
| `mkfs.vfat` | `mkfs.vfat -F32 $efi_partition` | Create EFI filesystem |
| `pvremove` | `pvremove -ff -y $partition` | Remove LVM physical volume |

### Boot/GRUB Commands

| Command | Usage | Purpose |
|---------|-------|---------|
| `grub-install` | `grub-install --target x86_64-efi --no-floppy --bootloader-id='proxmox' $dev` | Install UEFI GRUB |
| `grub-install` | `grub-install --target i386-pc --no-floppy --bootloader-id='proxmox' $dev` | Install BIOS GRUB |
| `update-grub` | `update-grub` | Update GRUB configuration |
| `grub-mkconfig` | `grub-mkconfig -o /boot/grub/grub.cfg` | Generate GRUB config |

### System Commands

| Command | Usage | Purpose |
|---------|-------|---------|
| `udevadm info` | `udevadm info -q property -p /sys/block/$dev` | Get device properties |
| `udevadm trigger` | `udevadm trigger --subsystem-match block` | Trigger udev events |
| `udevadm settle` | `udevadm settle --timeout 10` | Wait for udev to settle |
| `mount` | `mount -t zfs $dataset $mountpoint` | Mount ZFS dataset |
| `umount` | `umount $mountpoint` | Unmount filesystem |
| `chroot` | `chroot $targetdir command` | Run command in chroot |
| `dpkg-divert` | `dpkg-divert --package proxmox --add --rename $cmd` | Divert package file |
| `debconf-set-selections` | `debconf-set-selections $configfile` | Set debconf values |
| `systemctl` | `systemctl enable zfs-import-cache` | Enable systemd service |

## Command Dependencies for Kubuntu Installer

### Required Packages

```bash
# Core utilities
apt-get install -y \
    gdisk \          # sgdisk command
    zfsutils-linux \ # All ZFS commands
    dosfstools \     # mkfs.vfat
    e2fsprogs \      # mkfs.ext4
    xfsprogs \       # mkfs.xfs
    grub-efi-amd64 \ # UEFI GRUB
    grub-pc \        # BIOS GRUB
    util-linux \     # wipefs, blkid, lsblk
    udev \           # udevadm
    parted           # Alternative to sgdisk
```

### Command Validation Function

```bash
# Validate all required commands are available
validate_required_commands() {
    local -a required_commands
    required_commands=(
        "zpool"
        "zfs"
        "sgdisk"
        "wipefs"
        "blkid"
        "lsblk"
        "blockdev"
        "dd"
        "mkfs.vfat"
        "grub-install"
        "update-grub"
        "udevadm"
        "partprobe"
    )
    
    local missing
    missing=0
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: Required command '$cmd' not found" >&2
            ((missing++))
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        echo "ERROR: $missing required commands are missing" >&2
        echo "Install with: apt-get install zfsutils-linux gdisk dosfstools grub-efi-amd64" >&2
        return 1
    fi
    
    return 0
}
```

## Critical Command Options

### zpool create Options
- `-f`: Force creation even if disks appear in use
- `-o cachefile=none`: Don't cache pool configuration (important for live system)
- `-o ashift=12`: Standard for modern drives (4K sector optimization)
- `-o autotrim=on`: Enable automatic TRIM for SSDs

### sgdisk Options
- `-Z`: Zap (destroy) GPT and MBR data structures
- `-n`: Create new partition (number:start:end)
- `-t`: Change partition type code
- `-a`: Set alignment (1 for minimal, 2048 for optimal)

### zfs set Properties
- `compression=lz4`: Enable LZ4 compression (fast, efficient)
- `atime=on relatime=on`: Access time updates (optimized)
- `acltype=posixacl`: POSIX ACL support
- `xattr=sa`: Store extended attributes efficiently
- `normalization=formD`: Unicode normalization for filenames
- `mountpoint=/`: Set mount location

These commands form the complete set needed to implement the Kubuntu ZFS RAID-Z1 installer.