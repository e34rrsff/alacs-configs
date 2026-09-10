#!/bin/bash
# nbd-expose.sh — interactive block-device → NBD exposer
#
# Shows a dialog that lets the operator pick a local block device
# and then starts nbd-server(8) to export it read-write on port 10809.
# A remote build host connects with:
#   nbd-client <this-ip> 10809 /dev/nbd0
# and can then dd / mkfs / write a raw image onto it.

set -euo pipefail

# ── Colours / helpers ──────────────────────────────────────────────
DIALOG="dialog --colors --backtitle \"ALACS NBD Exposer\""
NBD_PORT=10809
NBD_PID=""

trap cleanup EXIT INT TERM

cleanup() {
    if [ -n "$NBD_PID" ] && kill -0 "$NBD_PID" 2>/dev/null; then
        kill "$NBD_PID" 2>/dev/null || true
        wait "$NBD_PID" 2>/dev/null || true
    fi
}

# ── Wait for at least one non-loopback IPv4 address ───────────────
wait_for_network() {
    local tries=0
    while [ $tries -lt 60 ]; do
        ip_addr=$(ip -4 -br addr show \
                  | grep -v 'lo\|docker\|veth\|br-' \
                  | awk '$3 ~ /^[0-9]/ {print $3; exit}' \
                  | cut -d/ -f1)
        if [ -n "$ip_addr" ]; then
            return 0
        fi
        tries=$((tries + 1))
        sleep 2
    done
    return 1
}

# ── Gather real block devices (skip the live media, loop, etc.) ───
build_device_list() {
    local live_disk
    live_disk=$(findmnt -n -o SOURCE /run/initramfs/live 2>/dev/null \
                | sed 's/[0-9]*$//' || echo "")

    while IFS= read -r line; do
        local name size model tran
        name=$(echo "$line"  | awk '{print $1}')
        size=$(echo "$line"  | awk '{print $2}')
        model=$(echo "$line" | awk '{for(i=3;i<=NF-1;i++) printf "%s ", $i; print $NF}')
        tran=$(echo "$line"  | awk '{print $NF}')

        # Skip the live device itself
        [ "/dev/$name" = "$live_disk" ] && continue

        # Format: tag  description
        echo "$name"
        echo "$size  $model  [$tran]"
    done < <(lsblk -d -n -b -o NAME,SIZE,MODEL,TRAN | sort)
}

# ── Main ───────────────────────────────────────────────────────────
main() {
    clear

    # 1) Network -------------------------------------------------------
    $DIALOG --infobox "\nWaiting for network (DHCP)..." 5 50
    if wait_for_network; then
        ip_addr=$(ip -4 -br addr show \
                  | grep -v 'lo\|docker\|veth\|br-' \
                  | awk '$3 ~ /^[0-9]/ {print $3; exit}' \
                  | cut -d/ -f1)
    else
        ip_addr="(no IP — check cable/Wi-Fi)"
    fi

    # 2) Device selection -----------------------------------------------
    local dev_entries
    dev_entries=$(build_device_list)

    if [ -z "$dev_entries" ]; then
        $DIALOG --msgbox "No suitable block devices found." 7 50
        exit 1
    fi

    local choice
    choice=$(echo "$dev_entries" | xargs \
             | $DIALOG --stdout \
                       --title "Select block device" \
                       --menu "\nPick the drive to expose via NBD:\nServer IP: \Zb${ip_addr}\Zn" \
                       18 70 10)

    if [ -z "$choice" ]; then
        $DIALOG --msgbox "Cancelled." 5 40
        exit 0
    fi

    local device="/dev/$choice"

    # 3) Confirm --------------------------------------------------------
    $DIALOG --yesno "Expose \Zb${device}\Zn read-write\nat \Zb${ip_addr}:${NBD_PORT}\Zn?" 8 55
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # 4) Start nbd-server -----------------------------------------------
    #    Using the old-style CLI: nbd-server <port> <device>
    nbd-server "$NBD_PORT" "$device" &
    NBD_PID=$!
    sleep 1

    if ! kill -0 "$NBD_PID" 2>/dev/null; then
        $DIALOG --msgbox "Failed to start nbd-server." 7 50
        exit 1
    fi

    # 5) Show connection info -------------------------------------------
    $DIALOG --title "NBD Server Running" \
            --msgbox "\
\Zb${device}\Zn is now exposed via NBD.\n\
\n\
Server IP : \Zb${ip_addr}\Zn\n\
Port      : \Zb${NBD_PORT}\Zn\n\
\n\
On the build host, connect with:\n\
  \Zbmodprobe nbd\Zn\n\
  \Zbnbd-client ${ip_addr} ${NBD_PORT} /dev/nbd0\Zn\n\
\n\
Then write the image:\n\
  \Zbdd if=image.raw of=/dev/nbd0 bs=4M status=progress\Zn\n\
\n\
Press OK when done — the server will stop."

    cleanup
}

main "$@"
