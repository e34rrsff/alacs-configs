#!/bin/bash
# config.sh — post-build configuration for the ALACS Workstation image

set -euxo pipefail
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "==> Configuring ALACS Workstation image..."

# ── Machine-id: reset so every boot gets a unique one ──────────────
rm -f /etc/machine-id
echo 'uninitialized' > /etc/machine-id

# ── Hostname: set the system's hostname ────────────────────────────
echo "alacs-workstation" > /etc/hostname

# ── Clear root password and lock the account ───────────────────────
passwd -d root
passwd -l root

# ── Enable essential services ──────────────────────────────────────
systemctl enable NetworkManager.service
systemctl enable firewalld.service
systemctl enable gdm.service

# ── Configure grub ────────────────────────────────────────────────
echo "GRUB_DEFAULT=saved" >> /etc/default/grub
echo "GRUB_DISABLE_SUBMENU=true" >> /etc/default/grub
echo "GRUB_DISABLE_RECOVERY=true" >> /etc/default/grub

# ── Set up fstab ──────────────────────────────────────────────────
if [ -f /etc/fstab ]; then
    # Add umask=0077,shortname=winnt to ESP mount options
    sed -i '/\/boot\/efi/s/defaults/defaults,umask=0077,shortname=winnt/' /etc/fstab
fi

# ── Root partition resize on first boot ───────────────────────────
mkdir -p /etc/repart.d/
cat > /etc/repart.d/50-root.conf << EOF
[Partition]
Type=root
EOF

# ── Finalization ──────────────────────────────────────────────────
touch -r "/usr" "/etc/.updated" "/var/.updated"

exit 0
