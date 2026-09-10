# Base OEM Image with systemd-boot + UKI

A minimal Fedora-based system image with:
- **Two partitions only**: EFI (FAT32, 512MB) + root (ext4)
- **systemd-boot** bootloader
- **Unified Kernel Image (UKI)** for secure boot compatibility
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
│  │  ├─ systemd/ │  └─ ...                             │
│  │  │  └─ *.efi │                                     │
│  │  ├─ BOOT/    │                                     │
│  │  │  └─ *.EFI │                                     │
│  │  └─ Linux/   │                                     │
│  │     └─ *.efi │  (UKI images)                       │
│  └─ loader/     │                                     │
│     └─ loader.conf                                     │
└─────────────────┴──────────────────────────────────────┘
```

## Build

```bash
# On a Fedora host with kiwi installed:
sudo dnf install kiwi kiwi-systemdeps distribution-gpg-keys
sudo kiwi-ng --type oem system build \
    --description ./base-oem-uki \
    --target-dir ./outdir
```

## Usage

### Writing to a drive directly

```bash
# Write the raw image to a drive (WARNING: destroys all data!)
sudo dd if=Fedora-Base-OEM-UKI.raw of=/dev/sdX bs=4M status=progress
```

### Writing via NBD (from the NBD Exposer ISO)

```bash
# On the build host, after the laptop is running the NBD Exposer ISO:
modprobe nbd
nbd-client <laptop-ip> 10809 /dev/nbd0
dd if=Fedora-Base-OEM-UKI.raw of=/dev/nbd0 bs=4M status=progress
nbd-client -d /dev/nbd0
```

### Expanding the root partition

If you write the image to a larger drive, the root partition and filesystem
should automatically expanded on the first boot to make use of the whole drive.

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
4. Rebuild the image

## Files

| File | Purpose |
|------|---------|
| `config.xml` | Kiwi image description |
| `config.sh` | Post-build configuration script |
| `editbootconfig.sh` | Sets up systemd-boot + UKI in the ESP |

## Notes

- The image uses `systemd.firstboot=off` to skip interactive first-boot setup
- Root password is locked by default (set via `passwd` after first boot)
- The UKI approach means the kernel, initramfs, and cmdline are bundled into
  a single EFI binary, simplifying the boot process
