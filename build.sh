#!/bin/bash
# build.sh — Build the NBD Exposer ISO and/or the Base OEM UKI image
#
# Usage: ./build.sh [nbd|oem|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_BASE="${SCRIPT_DIR}/build-output"

usage() {
    cat << EOF
Usage: $0 [nbd|oem|all]

Build targets:
  nbd   - Build the NBD Exposer live ISO
  oem   - Build the Base OEM UKI image (Fedora Workstation with GNOME)
  all   - Build both images

Examples:
  $0 nbd    # Builds nbd-exposer/ -> build-output/nbd-exposer/
  $0 oem    # Builds base-oem-uki/ -> build-output/base-oem-uki/
  $0 all    # Builds both images to their respective output dirs
EOF
    exit 1
}

build_image() {
    local target="$1"
    local desc_dir out_dir kiwi_type

    case "$target" in
        nbd)
            desc_dir="${SCRIPT_DIR}/nbd-exposer"
            out_dir="${OUTPUT_BASE}/nbd-exposer"
            kiwi_type="iso"
            echo "==> Building NBD Exposer ISO..."
            ;;
        oem)
            desc_dir="${SCRIPT_DIR}/base-oem-uki"
            out_dir="${OUTPUT_BASE}/base-oem-uki"
            kiwi_type="oem"
            echo "==> Building Base OEM UKI image..."
            ;;
        *)
            echo "Error: Unknown target '$target'"
            usage
            ;;
    esac

    # Create output directory
    mkdir -p "${out_dir}"

    # Build the image
    kiwi-ng --type "${kiwi_type}" \
            system build \
            --description "${desc_dir}" \
            --target-dir "${out_dir}" \
            --allow-existing-root

    echo
    echo "==> Build complete for ${target}!"
    echo "==> Output: ${out_dir}"
    echo
}

if [ $# -ne 1 ]; then
    usage
fi

case "$1" in
    all)
        build_image "nbd"
        build_image "oem"
        echo "==> All builds complete!"
        ;;
    nbd|oem)
        build_image "$1"
        ;;
    *)
        echo "Error: Unknown target '$1'"
        usage
        ;;
esac
