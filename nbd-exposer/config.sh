#!/bin/bash
# config.sh — runs inside the image root after package installation
# for the NBD Exposer live ISO.

set -euxo pipefail
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "==> Configuring NBD Exposer image..."

# ── Machine-id: reset so every boot gets a unique one ──────────────
rm -f /etc/machine-id
echo 'uninitialized' > /etc/machine-id

# ── Clear root password and lock the account ───────────────────────
passwd -d root
passwd -l root

# ── Enable NetworkManager (DHCP on all interfaces by default) ─────
systemctl enable NetworkManager.service

# ── Enable our custom target that pulls in the NBD dialog ─────────
systemctl enable nbd-expose.target

# ── Make sure the nbd kernel module is available early ────────────
echo "nbd" > /etc/modules-load.d/nbd.conf

# ── Disable services that don't make sense on a live tool ISO ─────
systemctl disable firewalld.service 2>/dev/null || true
systemctl disable auditd.service     2>/dev/null || true

# ── Set a short grub timeout (the ISO boots straight to the dialog)
if [ -f /etc/default/grub ]; then
    echo 'GRUB_DEFAULT=0'      >> /etc/default/grub
    echo 'GRUB_TIMEOUT=3'      >> /etc/default/grub
    echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub
fi

# ── Disable plymouth (no graphical splash needed) ─────────────────
systemctl mask plymouth-start.service 2>/dev/null || true

# ── Finalization ──────────────────────────────────────────────────
touch -r "/usr" "/etc/.updated" "/var/.updated"

exit 0
