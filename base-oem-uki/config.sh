#!/bin/bash
# config.sh — post-build configuration for the base OEM image

set -euxo pipefail
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "==> Configuring Base OEM image..."

# ── Machine-id: reset so every boot gets a unique one ──────────────
rm -f /etc/machine-id
echo 'uninitialized' > /etc/machine-id

# ── Clear root password and lock the account ───────────────────────
passwd -d root
passwd -l root

# ── Enable essential services ──────────────────────────────────────
systemctl enable NetworkManager.service
systemctl enable firewalld.service
systemctl enable gdm.service

# ── Configure systemd-firstboot to skip interactive setup ─────────
mkdir -p /etc/systemd/system/systemd-firstboot.service.d
cat > /etc/systemd/system/systemd-firstboot.service.d/skip.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/bin/true
EOF

# ── Set up fstab ──────────────────────────────────────────────────
if [ -f /etc/fstab ]; then
    # Add umask=0077,shortname=winnt to ESP mount options
    sed -i '/\/boot\/efi/s/defaults/defaults,umask=0077,shortname=winnt/' /etc/fstab
fi

# ── Finalization ──────────────────────────────────────────────────
touch -r "/usr" "/etc/.updated" "/var/.updated"

exit 0
