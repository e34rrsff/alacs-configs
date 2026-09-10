#!/bin/bash
# build.sh — Build either the NBD Exposer ISO or the Base OEM UKI image
#
# Usage: ./build.sh [nbd|oem]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_BASE="${SCRIPT_DIR}/build-output"

usage() {
    cat << EOF
Usage: $0 [nbd|oem]

Build targets:
  nbd   - Build the NBD Exposer live ISO
  oem   - Build the Base OEM UKI image (Fedora Workstation with GNOME)

Examples:
  $0 nbd    # Builds nbd-exposer/ -> build-output/nbd-exposer/
  $0 oem    # Builds base-oem-uki/ -> build-output/base-oem-uki/
EOF
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

case "$1" in
    nbd)
        DESC_DIR="${SCRIPT_DIR}/nbd-exposer"
        OUT_DIR="${OUTPUT_BASE}/nbd-exposer"
        echo "==> Building NBD Exposer ISO..."
        ;;
    oem)
        DESC_DIR="${SCRIPT_DIR}/base-oem-uki"
        OUT_DIR="${OUTPUT_BASE}/base-oem-uki"
        echo "==> Building Base OEM UKI image..."
        ;;
    *)
        echo "Error: Unknown target '$1'"
        usage
        ;;
esac

# Create output directory
mkdir -p "${OUT_DIR}"

# Build the image
kiwi-ng --type "$( [ "$1" = "nbd" ] && echo "iso" || echo "oem" )" \
        system build \
        --description "${DESC_DIR}" \
        --target-dir "${OUT_DIR}"

echo
echo "==> Build complete!"
echo "==> Output: ${OUT_DIR}"
