#!/bin/sh
# Mobile NixOS Boot Orchestrator
# Main entry point for generation selection and kexec

# Source the boot config functions
if [ -f /bin/nixos-boot-cfg.sh ]; then
    . /bin/nixos-boot-cfg.sh
else
    echo "Warning: nixos-boot-cfg.sh not found"
    return 0
fi

MISC_PART="${MISC_PART:-/dev/disk/by-partlabel/misc}"
GENERATIONS_DIR="${GENERATIONS_DIR:-/mnt/nix/var/nix/profiles}"
DEFAULT_TIMEOUT="${DEFAULT_TIMEOUT:-2}"

# Check if any button is pressed (volume or power)
# Returns: 0 if button pressed, 1 otherwise
check_any_button() {
    # Check common input event devices
    for event_dev in /dev/input/event*; do
        if [ -e "$event_dev" ]; then
            # Try to check for volume or power keys
            if evtest --query "$event_dev" EV_KEY KEY_VOLUMEUP 2>/dev/null || \
               evtest --query "$event_dev" EV_KEY KEY_VOLUMEDOWN 2>/dev/null || \
               evtest --query "$event_dev" EV_KEY KEY_POWER 2>/dev/null; then
                return 0
            fi
        fi
    done
    return 1
}

# Check if we're in recovery mode
check_recovery_mode() {
    # Check cmdline for recovery indicators
    if grep -q "recovery" /proc/cmdline 2>/dev/null; then
        return 0
    fi
    # Check for special flag in NIXOS_BOOT_CFG
    local cfg
    if cfg=$(read_boot_cfg "$MISC_PART" 2>/dev/null); then
        local flags
        read _ flags _ _ <<< "$cfg"
        if [ $((flags & 4)) -ne 0 ]; then
            return 0
        fi
    fi
    return 1
}

# Main boot logic
main() {
    echo ""
    echo "========================================"
    echo "  Mobile NixOS Boot Orchestrator"
    echo "========================================"
    
    # Check if misc partition exists
    if [ ! -b "$MISC_PART" ]; then
        echo "Warning: Misc partition not found, continuing with normal boot"
        return 0
    fi
    
    # Read current configuration
    local cfg_valid=0
    local cfg_flags=0
    local cfg_path=""
    local cfg_copy=0
    
    if cfg=$(read_boot_cfg "$MISC_PART" 2>/dev/null); then
        cfg_valid=1
        read _ cfg_flags cfg_path cfg_copy <<< "$cfg"
        echo "Read config from copy $cfg_copy: flags=$cfg_flags"
    else
        echo "No valid config found on misc partition"
    fi
    
    # Determine if we should show the menu
    local show_menu=0
    local timeout=$DEFAULT_TIMEOUT
    
    if check_recovery_mode; then
        echo "Recovery mode detected - showing menu"
        show_menu=1
        timeout=0  # Wait forever in recovery
    elif [ $cfg_valid -eq 1 ] && [ $((cfg_flags & 1)) -ne 0 ]; then
        echo "Menu flag set in config"
        show_menu=1
    elif check_any_button; then
        echo "Button pressed - showing menu"
        show_menu=1
    fi
    
    # Show menu if needed
    if [ $show_menu -eq 1 ]; then
        if [ -x /bin/mobile-nixos-menu ]; then
            # Switch to VT2 for menu
            chvt 2 2>/dev/null || echo "Warning: Could not switch VT"
            
            # Run menu
            /bin/mobile-nixos-menu "$timeout"
            
            # Switch back to VT1
            chvt 1 2>/dev/null || true
        else
            echo "Warning: mobile-nixos-menu not found"
        fi
        return 0
    fi
    
    # No menu - attempt to boot configured generation
    if [ $cfg_valid -eq 1 ] && [ -n "$cfg_path" ]; then
        echo "Booting configured generation: $cfg_path"
        
        # Check if generation exists
        local full_path=""
        if [ -d "$cfg_path" ]; then
            full_path="$cfg_path"
        elif [ -d "$GENERATIONS_DIR/$cfg_path" ]; then
            full_path="$GENERATIONS_DIR/$cfg_path"
        elif [ -d "/mnt$cfg_path" ]; then
            full_path="/mnt$cfg_path"
        fi
        
        if [ -n "$full_path" ]; then
            # Check for boot_once flag
            if [ $((cfg_flags & 2)) -ne 0 ]; then
                echo "Boot-once flag set, clearing config after boot"
                clear_boot_cfg "$MISC_PART" 2>/dev/null || true
            fi
            
            # Boot via kexec
            if boot_generation "$full_path"; then
                # kexec succeeded (should not reach here)
                return 0
            fi
            
            # If kexec failed, continue with normal boot
            echo "Warning: kexec failed, continuing with normal boot"
        else
            echo "Warning: Configured generation not found: $cfg_path"
            echo "Falling back to normal boot"
        fi
    fi
    
    # Continue with normal boot
    echo "Continuing with default generation..."
    return 0
}

# Execute kexec to boot a generation
boot_generation() {
    local gen_path="$1"
    
    # Check for required files
    if [ ! -f "$gen_path/kernel" ]; then
        echo "Error: Kernel not found at $gen_path/kernel"
        return 1
    fi
    
    if [ ! -f "$gen_path/initrd" ]; then
        echo "Error: Initrd not found at $gen_path/initrd"
        return 1
    fi
    
    echo "Loading kernel from $gen_path/kernel..."
    
    # Build kernel parameters
    local params=""
    if [ -f "$gen_path/kernel-params" ]; then
        params=$(cat "$gen_path/kernel-params")
    fi
    
    local init_path
    if [ -L "$gen_path/init" ]; then
        init_path=$(readlink -f "$gen_path/init")
    else
        init_path="$gen_path/init"
    fi
    
    local full_params="init=$init_path $params"
    
    # Load kexec
    if ! kexec --load "$gen_path/kernel" --initrd="$gen_path/initrd" --append="$full_params" 2>/dev/null; then
        echo "Error: kexec load failed"
        return 1
    fi
    
    echo "Executing kexec..."
    kexec -e
    
    # Should not reach here
    return 1
}

# Run main logic
main
exit $?
