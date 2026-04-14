{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mobile.boot.generation-menu;

  # Import the C binary package
  nixosBootCfgPkg = pkgs.callPackage ../pkgs/nixos-boot-cfg { };

  # Menu script
  mobileNixosMenu = pkgs.writeShellScriptBin "mobile-nixos-menu" (
    builtins.readFile ../pkgs/nixos-boot-cfg/mobile-nixos-menu.sh
  );

  # Boot orchestrator script
  mobileNixosBoot = pkgs.writeScriptBin "ash" ''
    # Mobile NixOS Boot Orchestrator

    MISC_PART="${cfg.miscPartition}"
    GENERATIONS_DIR="/mnt/nix/var/nix/profiles"
    DEFAULT_TIMEOUT="${toString cfg.autobootSeconds}"

    # Check if any button is pressed
    check_any_button() {
      for event_dev in /dev/input/event*; do
        if [ -e "$event_dev" ]; then
          if evtest --query "$event_dev" EV_KEY KEY_VOLUMEUP 2>/dev/null || \
             evtest --query "$event_dev" EV_KEY KEY_VOLUMEDOWN 2>/dev/null || \
             evtest --query "$event_dev" EV_KEY KEY_POWER 2>/dev/null; then
            return 0
          fi
        fi
      done
      return 1
    }

    # Check recovery mode
    check_recovery_mode() {
      if grep -q "recovery" /proc/cmdline 2>/dev/null; then
        return 0
      fi
      return 1
    }

    echo "NixOS boot menu"

    # Read config from misc partition
    BOOT_CFG=$(/bin/nixos-boot-cfg read "$MISC_PART" 2>/dev/null) || BOOT_CFG=""

    CFG_VALID=0
    CFG_FLAGS=0
    CFG_PATH=""

    if [ -n "$BOOT_CFG" ]; then
      read -r CFG_VERSION CFG_FLAGS CFG_PATH CFG_BLOCK <<< "$BOOT_CFG"
      CFG_VALID=1
      echo "Config loaded from block $CFG_BLOCK: flags=$CFG_FLAGS"
    fi

    # Determine if we should show menu
    SHOW_MENU=0

    if check_recovery_mode; then
      echo "Recovery mode detected"
      SHOW_MENU=1
    elif check_any_button; then
      echo "Button pressed"
      SHOW_MENU=1
    elif [ $CFG_VALID -eq 1 ] && [ $((CFG_FLAGS & 1)) -ne 0 ]; then
      echo "Menu flag set"
      SHOW_MENU=1
    fi

    if [ $SHOW_MENU -eq 1 ]; then
      # Show interactive menu
      if [ -x /bin/mobile-nixos-menu ]; then
        export MISC_PART
        export TIMEOUT="$DEFAULT_TIMEOUT"
        /bin/mobile-nixos-menu "$DEFAULT_TIMEOUT"
        # Menu handles kexec internally or returns
      fi
    elif [ $CFG_VALID -eq 1 ] && [ -n "$CFG_PATH" ]; then
      # Auto-boot configured generation
      echo "Booting configured: $CFG_PATH"
      
      FULL_PATH=""
      if [ -d "/mnt$CFG_PATH" ]; then
        FULL_PATH="/mnt$CFG_PATH"
      elif [ -d "$CFG_PATH" ]; then
        FULL_PATH="$CFG_PATH"
      fi
      
      if [ -n "$FULL_PATH" ] && [ -f "$FULL_PATH/kernel" ]; then
        # Clear boot_once flag if set
        if [ $((CFG_FLAGS & 2)) -ne 0 ]; then
          /bin/nixos-boot-cfg clear "$MISC_PART" 2>/dev/null
        fi
        
        # kexec
        INIT_PATH=$(readlink -f "$FULL_PATH/init" 2>/dev/null || echo "$FULL_PATH/init")
        PARAMS=$(cat "$FULL_PATH/kernel-params" 2>/dev/null)
        
        if kexec --load "$FULL_PATH/kernel" --initrd="$FULL_PATH/initrd" \
           --append="init=$INIT_PATH $PARAMS" 2>/dev/null; then
          echo "Starting..."
          kexec -e
        fi
      fi
      
      echo "kexec failed, continuing with normal boot"
      sleep 10
    fi

    echo "Continuing with default generation..."
    return 0
  '';
in
{
  options.mobile.boot.generation-menu = {
    enable = lib.mkEnableOption "generation selection menu in initrd" // {
      default = true;
    };

    autobootSeconds = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = ''
        Number of seconds to wait before auto-booting default.
        Set to 0 to disable autoboot (always show menu).
      '';
    };

    miscPartition = lib.mkOption {
      type = lib.types.str;
      default = "/dev/disk/by-partlabel/misc";
      description = ''
        Path to the misc partition for storing boot configuration.
      '';
    };

    enableBuffyboard = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable buffyboard on-screen keyboard in the menu.
      '';
    };

    showInRecovery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Always show menu when booting in recovery mode.
      '';
    };

    updateOnShutdown = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Update boot configuration on shutdown to remember last booted generation.
        This ensures that after nixos-rebuild, the new generation will be booted by default.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Add tools to initrd
    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.kexec-tools}/bin/kexec
      copy_bin_and_libs ${nixosBootCfgPkg}/bin/nixos-boot-cfg
      copy_bin_and_libs ${mobileNixosMenu}/bin/mobile-nixos-menu
      ${lib.optionalString cfg.enableBuffyboard ''
        copy_bin_and_libs ${pkgs.buffyboard}/bin/buffyboard
      ''}
    '';

    # Add kernel modules needed for input
    boot.initrd.kernelModules = lib.optionals cfg.enable [
      "uinput"
    ];

    # Run the boot orchestrator after mounting root filesystem
    boot.initrd.postMountCommands = ''
      echo MOBILE_NIXOS_BOOT!!!!!!!!!!!!!
      sleep 5
      ${mobileNixosBoot}
    '';

    # Systemd service to update boot cfg on shutdown
    systemd.services.nixos-boot-cfg-update = lib.mkIf cfg.updateOnShutdown {
      description = "Update boot configuration with current generation";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = pkgs.writeShellScript "update-boot-cfg" ''
          MISC_PART="${cfg.miscPartition}"

          # Get current generation
          CURRENT_GEN=$(readlink -f /nix/var/nix/profiles/system)
          if [ -n "$CURRENT_GEN" ]; then
            GEN_PATH="/nix/var/nix/profiles/$(basename "$CURRENT_GEN")"
            FLAGS=0  # Normal boot, no special flags
            
            ${nixosBootCfgPkg}/bin/nixos-boot-cfg write "$FLAGS" "$GEN_PATH" "$MISC_PART" || true
          fi
        '';
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
