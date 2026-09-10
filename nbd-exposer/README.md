# ALACS NBD Exposer — Live ISO

A minimal Fedora-based live ISO that boots to a simple `dialog`-based TUI.
Instead of an installer (Anaconda), it lets the operator pick a local block
device (e.g. `/dev/nvme0n1`) and exposes it over the network via `nbd-server`.

A remote build host can then connect with `nbd-client` and write a raw disk
image straight onto the laptop drive.

## Workflow

```
┌──────────────────────┐          ┌──────────────────────┐
│  Laptop (target)     │          │  Build host          │
│                      │          │                      │
│  [Boot NBD Exposer   │  NBD     │                      │
│   ISO from USB]      │◄────────►│  nbd-client ...      │
│                      │  :10809  │  dd if=image.raw     │
│  Pick /dev/nvme0n1   │          │     of=/dev/nbd0     │
│  in dialog           │          │                      │
└──────────────────────┘          └──────────────────────┘
```

## Build

```bash
# On a Fedora host with kiwi installed:
sudo dnf install kiwi kiwi-systemdeps distribution-gpg-keys
sudo kiwi-ng --type iso system build \
    --description ./nbd-exposer \
    --target-dir ./outdir
```

## Usage

1. Flash the resulting ISO to a USB stick.
2. Boot the target laptop from the USB.
3. The dialog will appear automatically on `tty1`.
4. Select the block device to expose.
5. On the build host:
   ```bash
   modprobe nbd
   nbd-client <laptop-ip> 10809 /dev/nbd0
   dd if=base-oem-uki.raw of=/dev/nbd0 bs=4M status=progress
   nbd-client -d /dev/nbd0
   ```
6. Press OK in the dialog to stop the server, then power off.

## Files

| File | Purpose |
|------|---------|
| `config.xml` | Kiwi image description |
| `config.sh` | Post-build configuration script |
| `root/usr/local/bin/nbd-expose.sh` | The dialog + nbd-server launcher |
| `root/etc/systemd/system/nbd-expose.target` | Custom systemd target (replaces multi-user) |
| `root/etc/systemd/system/nbd-expose.service` | Runs the dialog on tty1 |
