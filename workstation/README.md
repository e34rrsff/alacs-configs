# ALACS Workstation — Raw Disk Image

A Fedora Workstation-based system image with:
- **Two partitions only**: EFI (FAT32, 512MB) + root (ext4)
- **GRUB2** bootloader (EFI)
- **GNOME** desktop environment
- Basic Fedora system, ready for customization

## Partition Layout

```
┌─────────────────┬──────────────────────────────────────┐
│ EFI System      │ Root filesystem                      │
│ Partition       │ (ext4)                               │
│ (FAT32, 512MB)  │                                      │
│                 │                                      │
│ /boot/efi/      │ /                                    │
│  ├─ EFI/        │  ├─ bin, lib, usr, etc...           │
│  │  ├─ BOOT/    │  └─ ...                             │
│  │  │  └─ *.EFI │                                     │
│  │  └─ fedora/  │                                     │
│  │     └─ grub.cfg                                     │
│  └─ loader/     │                                     │
│     └─ ...      │                                     │
└─────────────────┴──────────────────────────────────────┘
```

## Shared Configuration

Common preferences (timezone, locale, repos, core packages) are defined in
`../common.xml` and included by both this image and the NBD Exposer image.

## Build

```bash
# On a Fedora host with kiwi installed:
sudo dnf install kiwi kiwi-systemdeps distribution-gpg-keys
sudo kiwi-ng --type oem system build \
    --description ./workstation \
    --target-dir ./outdir
```

Or use the build script:
```bash
sudo ./build.sh workstation
```

## Usage

### Writing to a drive directly

```bash
# Write the raw image to a drive (WARNING: destroys all data!)
sudo dd if=ALACS-Workstation.x86_64-1.0.0.raw of=/dev/sdX bs=4M status=progress
```

### Writing via NBD (from the NBD Exposer ISO)

```bash
# On the build host, after the laptop is running the NBD Exposer ISO:
modprobe nbd
nbd-client <laptop-ip> 10809 /dev/nbd0
dd if=ALACS-Workstation.x86_64-1.0.0.raw of=/dev/nbd0 bs=4M status=progress
nbd-client -d /dev/nbd0
```

### Expanding the root partition

If you write the image to a larger drive, the root partition and filesystem
should automatically expand on the first boot to make use of the whole drive
(via systemd-repart).

Alternatively, manually:
```bash
# After booting the image:
sudo growpart /dev/nvme0n1 2  # Expand partition 2
sudo resize2fs /dev/nvme0n1p2  # Resize filesystem
```

## Customization

To add packages or configuration to the base image:

1. Edit `config.xml` and add packages to the `<packages type="image">` section
2. Add overlay files to the `root/` directory (they get copied to `/` in the image)
3. Modify `config.sh` for post-install configuration
4. For changes shared with the NBD Exposer, edit `../common.xml`
5. Rebuild the image

## Files

| File | Purpose |
|------|---------|
| `config.xml` | Kiwi image description |
| `config.sh` | Post-build configuration script |

## Notes

- Root password is locked by default (set via `passwd` after first boot)
- The image uses GRUB2 with BLS (Boot Loader Specification) entries
- `oem-resize` is enabled so the root partition auto-expands on first boot
