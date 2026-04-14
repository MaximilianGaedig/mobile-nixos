#!/bin/sh
# Update NIXOS_BOOT_CFG with current generation after successful boot
# This runs on shutdown to mark boot as successful and update last booted gen

MISC_PART="/dev/disk/by-partlabel/misc"

# Find current generation
CURRENT_GEN=$(readlink -f /nix/var/nix/profiles/system)
if [ -z "$CURRENT_GEN" ]; then
    echo "Could not determine current generation" >&2
    exit 1
fi

# Get relative path from /nix/var/nix/profiles
GEN_PATH="/nix/var/nix/profiles/$(basename "$CURRENT_GEN")"

# Build flags: show_menu=0, boot_once=0, recovery=0
FLAGS=0

# Update misc partition
if [ -x /run/current-system/sw/bin/nixos-boot-cfg ]; then
    /run/current-system/sw/bin/nixos-boot-cfg write "$FLAGS" "$GEN_PATH" "$MISC_PART"
elif [ -x /nix/var/nix/profiles/system/sw/bin/nixos-boot-cfg ]; then
    /nix/var/nix/profiles/system/sw/bin/nixos-boot-cfg write "$FLAGS" "$GEN_PATH" "$MISC_PART"
fi
