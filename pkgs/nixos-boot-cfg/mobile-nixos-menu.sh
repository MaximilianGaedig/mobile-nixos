#!/bin/sh
# Mobile NixOS Generation Selection Menu
# TUI menu for selecting which generation to boot
# Supports: touch (via buffyboard), keyboard input, volume buttons

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

GENERATIONS_DIR="/mnt/nix/var/nix/profiles"
MISC_PART="${MISC_PART:-/dev/disk/by-partlabel/misc}"
TIMEOUT="${1:-2}"

# Clear screen
clear_screen() {
    printf '\033[2J\033[H'
}

# Get list of available generations (newest first)
get_generations() {
    ls -t "$GENERATIONS_DIR"/system-*-link 2>/dev/null | head -20
}

# Get generation display name
gen_name() {
    local gen_path="$1"
    local num=$(basename "$gen_path" | sed 's/system-\([0-9]*\)-link/\1/')
    local date=$(stat -c %y "$gen_path" 2>/dev/null | cut -d' ' -f1)
    local version=$(cat "$gen_path/nixos-version" 2>/dev/null | head -1)
    if [ -n "$version" ]; then
        echo "NixOS $version (#$num, $date)"
    else
        echo "Generation #$num ($date)"
    fi
}

# Draw the menu
draw_menu() {
    local selected="$1"
    shift
    local gens="$@"
    local num_gens=$#
    local total=$((num_gens + 4))  # gens + default + shell + reboot + poweroff
    
    clear_screen
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║${BOLD}          Mobile NixOS Generation Menu                       ${NC}║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo ""
    
    local i=1
    for gen in $gens; do
        local marker="  "
        [ $i -eq $selected ] && marker="${GREEN}▶${NC} "
        printf "║ %s%s%-58s║\n" "$marker" "$i. " "$(gen_name "$gen")"
        i=$((i + 1))
    done
    
    # Default option
    local marker="  "
    [ $i -eq $selected ] && marker="${GREEN}▶${NC} "
    printf "║ %s%s%-58s║\n" "$marker" "D. " "Boot default configuration"
    i=$((i + 1))
    
    # Shell option
    local marker="  "
    [ $i -eq $selected ] && marker="${GREEN}▶${NC} "
    printf "║ %s%s%-58s║\n" "$marker" "S. " "Drop to shell"
    i=$((i + 1))
    
    # Reboot option
    local marker="  "
    [ $i -eq $selected ] && marker="${GREEN}▶${NC} "
    printf "║ %s%s%-58s║\n" "$marker" "R. " "Reboot"
    i=$((i + 1))
    
    # Power off option
    local marker="  "
    [ $i -eq $selected ] && marker="${GREEN}▶${NC} "
    printf "║ %s%s%-58s║\n" "$marker" "P. " "Power off"
    
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    if [ $TIMEOUT -gt 0 ]; then
        echo "  ${YELLOW}Auto-booting default in ${TIMEOUT}s...${NC}"
    fi
    echo "  ${BLUE}Navigation:${NC} Type number/D/S/R/P + Enter, or use volume buttons"
    echo ""
}

# Read a single key (with optional timeout)
read_key() {
    local timeout_sec="$1"
    local key=""
    
    if [ -n "$timeout_sec" ] && [ "$timeout_sec" -gt 0 ]; then
        # Read with timeout
        IFS= read -rs -t "$timeout_sec" key </dev/tty 2>/dev/null || true
    else
        # Read without timeout
        IFS= read -rs -n 1 key </dev/tty 2>/dev/null || true
    fi
    
    echo "$key"
}

# Main menu loop
show_menu() {
    local gens=$(get_generations)
    local num_gens=$(echo "$gens" | wc -w)
    [ $num_gens -eq 0 ] && num_gens=0
    local total=$((num_gens + 4))
    local selected=1
    local remaining=$TIMEOUT
    
    # Draw initial menu
    draw_menu $selected $gens
    
    # Main loop
    while true; do
        local key=""
        
        if [ $remaining -gt 0 ]; then
            key=$(read_key 1)
            if [ -z "$key" ]; then
                remaining=$((remaining - 1))
                if [ $remaining -le 0 ]; then
                    # Timeout - boot default
                    return 0
                fi
                # Redraw to update countdown
                draw_menu $selected $gens
                continue
            fi
        else
            key=$(read_key)
        fi
        
        case "$key" in
            [0-9])
                # Number input - accumulate digits
                local num="$key"
                while true; do
                    local next=$(read_key 0.5)
                    if [ -z "$next" ]; then break; fi
                    if [[ "$next" =~ [0-9] ]]; then
                        num="${num}${next}"
                    else
                        break
                    fi
                done
                
                if [ "$num" -ge 1 ] && [ "$num" -le $num_gens ] 2>/dev/null; then
                    return $num
                elif [ "$num" -eq 0 ]; then
                    # D was pressed (number 0 not valid, treat as default)
                    return 0
                fi
                ;;
            d|D)
                return 0
                ;;
            s|S)
                return 255  # Special code for shell
                ;;
            r|R)
                reboot
                ;;
            p|P)
                poweroff
                ;;
            $'\n'| '')
                # Enter key - select current
                if [ $selected -le $num_gens ]; then
                    return $selected
                elif [ $selected -eq $((num_gens + 1)) ]; then
                    return 0  # Default
                elif [ $selected -eq $((num_gens + 2)) ]; then
                    return 255  # Shell
                elif [ $selected -eq $((num_gens + 3)) ]; then
                    reboot
                else
                    poweroff
                fi
                ;;
        esac
    done
}

# Execute selected generation via kexec
boot_generation() {
    local gen_path="$1"
    
    echo ""
    echo "Booting: $(gen_name "$gen_path")"
    
    if [ ! -f "$gen_path/kernel" ]; then
        echo "${RED}Error: Kernel not found${NC}"
        sleep 2
        return 1
    fi
    
    if [ ! -f "$gen_path/initrd" ]; then
        echo "${RED}Error: Initrd not found${NC}"
        sleep 2
        return 1
    fi
    
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
    
    echo "Loading kernel..."
    if ! kexec --load "$gen_path/kernel" --initrd="$gen_path/initrd" --append="$full_params" 2>/dev/null; then
        echo "${RED}Error: kexec load failed${NC}"
        sleep 2
        return 1
    fi
    
    echo "Starting kernel..."
    kexec -e
    return 1  # Should not reach here
}

# Main entry point
main() {
    # Switch to VT2 for menu
    chvt 2 2>/dev/null
    
    # Clear VT
    clear > /dev/tty2 2>/dev/null
    exec > /dev/tty2 2>&1
    
    # Start buffyboard if available
    if command -v buffyboard >/dev/null 2>&1; then
        buffyboard &
        local buffy_pid=$!
    fi
    
    # Show menu and get selection
    show_menu
    local selection=$?
    
    # Kill buffyboard
    if [ -n "$buffy_pid" ]; then
        kill $buffy_pid 2>/dev/null
    fi
    
    # Execute selection
    if [ $selection -eq 255 ]; then
        # Drop to shell
        clear_screen
        echo "${GREEN}Dropping to shell. Type 'exit' to return to menu.${NC}"
        echo ""
        /bin/ash
        # Return to menu after shell exits
        main
        return $?
    elif [ $selection -eq 0 ]; then
        # Boot default
        local default_gen=$(readlink -f "$GENERATIONS_DIR/system")
        if [ -n "$default_gen" ]; then
            boot_generation "$default_gen"
        fi
    else
        # Boot selected generation
        local gens=$(get_generations)
        local selected_gen=$(echo "$gens" | sed -n "${selection}p")
        if [ -n "$selected_gen" ]; then
            boot_generation "$selected_gen"
        fi
    fi
    
    # If we get here, something failed - return to VT1 and continue boot
    chvt 1 2>/dev/null
    return 1
}

main
exit $?
