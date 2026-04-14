# NIXOS_BOOT_CFG - Mobile NixOS Generation Selection

## Overview

This module provides generation selection for Mobile NixOS using the misc partition for storage. It supports:

- **Dual-block storage** (primary + backup) for reliability
- **Interactive menu** with buffyboard touchscreen keyboard
- **Automatic boot** with timeout
- **kexec support** for switching generations
- **Button detection** (volume/power) to trigger menu
- **Recovery mode** detection

## Storage Format

The misc partition (1MB) is divided into two 512KB blocks:
- **Block 0** (primary): offset 0
- **Block 1** (backup): offset 524288

Each block contains a 75-byte configuration:
```
Bytes 0-13:   Magic "NIXOS_BOOT_CFG"
Byte 14:      Null terminator
Byte 15:      Version (1)
Byte 16:      Flags (bit 0=show_menu, bit 1=boot_once, bit 2=recovery)
Bytes 17-20:  Reserved
Bytes 21-74:  Generation path (null-terminated, max 53 chars)
```

## Boot Flow

1. **Initrd mounts root filesystem**
2. **Reads NIXOS_BOOT_CFG** from misc partition
   - Tries primary block first
   - Falls back to backup if primary is corrupted
3. **Determines if menu should show:**
   - Recovery mode detected
   - Any button pressed during boot
   - show_menu flag set in config
4. **If menu shown:**
   - Switches to VT2 for clean UI
   - Starts buffyboard for touchscreen input
   - Shows list of available generations
   - User selects via keyboard or touch
   - kexecs into selected generation
5. **If no menu:**
   - kexecs into configured generation from misc partition
   - Or continues with default boot

## Interactive Menu

The menu displays:
- Available generations (up to 20, sorted by date)
- Default configuration option
- Shell drop option
- Reboot/Poweroff options

**Navigation:**
- Type number + Enter to select generation
- Type 'D' for default, 'S' for shell, 'R' for reboot, 'P' for poweroff
- Volume buttons (if evtest available)

## NixOS Rebuild Workflow

When you run `nixos-rebuild switch`:

1. **New generation created** in `/nix/var/nix/profiles/system-XX-link`
2. **Menu shows new generation** on next boot (scans directory)
3. **But misc partition unchanged** - still points to previous generation

To handle this, a **systemd service** runs on shutdown:
- Updates misc partition with current generation
- Clears special flags
- Ensures next boot uses the generation you just built

### Manual Control

**Write current generation to misc partition:**
```bash
sudo nixos-boot-cfg write 0 "/nix/var/nix/profiles/system-$(sudo nix-env -p /nix/var/nix/profiles/system --list-generations | tail -1 | awk '{print $1}')-link"
```

**Force menu on next boot:**
```bash
# Set show_menu flag (bit 0 = 1)
sudo nixos-boot-cfg write 1 "/nix/var/nix/profiles/system"
```

**Set boot-once (clears after boot):**
```bash
# Set boot_once flag (bit 1 = 2)
sudo nixos-boot-cfg write 2 "/nix/var/nix/profiles/system-123-link"
```

**Clear configuration:**
```bash
sudo nixos-boot-cfg clear
```

## Configuration

```nix
mobile.boot.generation-menu = {
  enable = true;                    # Enable the menu system
  autobootSeconds = 2;              # Timeout before auto-booting default (0 = wait forever)
  miscPartition = "/dev/disk/by-partlabel/misc";  # Misc partition path
  enableBuffyboard = true;          # Enable on-screen keyboard
  showInRecovery = true;            # Always show menu in recovery mode
  updateOnShutdown = true;          # Update boot cfg on shutdown (for nixos-rebuild)
};
```

## Files

- `nixos-boot-cfg.c` - C binary for reading/writing misc partition
- `mobile-nixos-menu.sh` - Interactive TUI menu
- `default.nix` - Nix derivation
- `test.sh` - Test suite

## Testing

```bash
cd pkgs/nixos-boot-cfg
nix-build
# or
bash test.sh
```

Tests verify:
- Basic read/write
- Backup fallback when primary corrupted
- Both blocks corrupted detection
- Clear operation
- Max path length handling

## Implementation Notes

- **VT switching**: Menu uses VT2 to avoid interfering with boot logs on VT1
- **kexec**: Loads new kernel without full reboot for faster switching
- **Dual storage**: If primary block is corrupted (bad flash write), backup is used
- **Null byte handling**: C implementation properly handles binary data with null bytes

## Troubleshooting

**Menu doesn't appear:**
- Check if misc partition exists: `ls -la /dev/disk/by-partlabel/misc`
- Check configuration: `sudo nixos-boot-cfg read`

**kexec fails:**
- Verify generation exists: `ls -la /nix/var/nix/profiles/system-*/kernel`
- Check kernel params file exists

**Touch input not working:**
- Ensure buffyboard is in initrd: `lsinitrd /boot/initrd | grep buffyboard`
- Check uinput module loaded: `lsmod | grep uinput`
