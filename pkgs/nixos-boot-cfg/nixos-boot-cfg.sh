#!/bin/sh
# NIXOS_BOOT_CFG - Mobile NixOS generation selection storage
# Wrapper that calls the compiled binary

if [ -n "$1" ]; then
    exec nixos-boot-cfg "$@"
fi
