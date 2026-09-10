#!/bin/bash
# editbootconfig.sh — set up systemd-boot + UKI in the ESP
#
# This script runs after the root filesystem is created but before
# the image is finalized. It installs systemd-boot to the ESP and
# copies UKI images to the correct location.
#
# The ESP is mounted at boot/efi/ relative to the image root.

set -euxo pipefail

echo "==> editbootconfig: Setting up systemd-boot + UKI..."

# ── Determine architecture ────────────────────────────────────────
case "$(uname -m)" in
    x86_64)  sdboot="systemd-bootx64.efi"; fallback="BOOTX64.EFI";;
    aarch64) sdboot="systemd-bootaa64.efi"; fallback="BOOTAA64.EFI";;
    *)
        echo "Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

# ── Install systemd-boot to ESP ───────────────────────────────────
# Copy the systemd-boot EFI binary to the ESP
mkdir -p boot/efi/EFI/systemd
mkdir -p boot/efi/EFI/BOOT

# The systemd-boot binary is installed by the systemd package
if [ -f "usr/lib/systemd/boot/efi/$sdboot" ]; then
    cp "usr/lib/systemd/boot/efi/$sdboot" "boot/efi/EFI/systemd/"
    cp "usr/lib/systemd/boot/efi/$sdboot" "boot/efi/EFI/BOOT/$fallback"
    echo "Installed systemd-boot to ESP"
else
    echo "WARNING: systemd-boot binary not found at usr/lib/systemd/boot/efi/$sdboot"
    echo "Attempting to use bootctl..."
    # Try using bootctl if available
    if command -v bootctl >/dev/null 2>&1; then
        bootctl --esp-path=boot/efi install --no-variables || true
    fi
fi

# ── Create loader configuration ───────────────────────────────────
mkdir -p boot/efi/loader
cat > boot/efi/loader/loader.conf << 'EOF'
# systemd-boot loader configuration
default @uki
timeout 3
editor no
EOF

# ── Copy UKI images to ESP ────────────────────────────────────────
# UKI images are created by kernel-install with the uki-direct plugin
# They end up in /lib/modules/*/vmlinuz*.efi
mkdir -p boot/efi/EFI/Linux

for uki in lib/modules/*/vmlinuz*.efi; do
    if [ -f "$uki" ]; then
        # Extract version from path: lib/modules/VERSION/vmlinuz-VERSION.efi
        ver=${uki#lib/modules/}
        ver=${ver%/*}
        echo "Copying UKI: $uki -> boot/efi/EFI/Linux/${ver}.efi"
        cp --reflink=auto "$uki" "boot/efi/EFI/Linux/${ver}.efi"
    fi
done

# ── Clean up leftover initramfs and kernel files ──────────────────
# With UKI, we don't need separate initramfs or kernel files in /boot
rm -f boot/initramfs-* 2>/dev/null || true
rm -f boot/vmlinuz-* 2>/dev/null || true
rm -f boot/EFI/Linux/* 2>/dev/null || true

# ── Disable grub and dracut kernel-install plugins ────────────────
# These are already disabled in config.sh, but ensure they're masked
mkdir -p etc/kernel/install.d
touch etc/kernel/install.d/20-grub.install
touch etc/kernel/install.d/50-dracut.install

echo "==> editbootconfig: Done"

exit 0
