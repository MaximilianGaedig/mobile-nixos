{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.hkdm.buttonControls;

  buttonControlsScript = pkgs.writeShellScript "hkdm-button-controls" ''
    set -eu

    action="$1"

    screen_is_off() {
      path=
      found=0
      brightness=
      for path in ${concatStringsSep " " cfg.screenBrightnessGlobs}; do
        [ -e "$path" ] || continue
        found=1
        brightness="$(${pkgs.coreutils}/bin/cat "$path")"
        if [ -n "$brightness" ] && [ "$brightness" -gt 0 ] 2>/dev/null; then
          return 1
        fi
      done

      [ "$found" -eq 1 ]
    }

    toggle_torch() {
      path=
      max_path=
      current=
      maximum=
      for path in ${concatStringsSep " " cfg.torchBrightnessGlobs}; do
        [ -e "$path" ] || continue
        max_path="$(${pkgs.coreutils}/bin/dirname "$path")/max_brightness"
        current="$(${pkgs.coreutils}/bin/cat "$path")"
        if [ -e "$max_path" ]; then
          maximum="$(${pkgs.coreutils}/bin/cat "$max_path")"
        else
          maximum=1
        fi

        if [ -n "$current" ] && [ "$current" -gt 0 ] 2>/dev/null; then
          printf '0\n' > "$path"
        else
          printf '%s\n' "$maximum" > "$path"
        fi
        return 0
      done

      return 1
    }

    screen_is_off || exit 0

    case "$action" in
      next)
        exec ${pkgs.playerctl}/bin/playerctl next
        ;;
      previous)
        exec ${pkgs.playerctl}/bin/playerctl previous
        ;;
      torch)
        toggle_torch
        ;;
      *)
        exit 1
        ;;
    esac
  '';
in
{
  options.services.hkdm.buttonControls = {
    enable = mkEnableOption "screen-off button controls via hkdm";

    screenBrightnessGlobs = mkOption {
      type = types.listOf types.str;
      default = [
        "/sys/class/backlight/*/brightness"
        "/sys/class/leds/*backlight*/brightness"
      ];
      description = "Brightness file globs used to decide whether the screen is off.";
    };

    torchBrightnessGlobs = mkOption {
      type = types.listOf types.str;
      default = [
        "/sys/class/leds/*torch*/brightness"
        "/sys/class/leds/*flash*/brightness"
        "/sys/class/leds/*camera*flash*/brightness"
      ];
      description = "Brightness file globs for a torch or flash LED.";
    };
  };

  config = mkIf cfg.enable {
    services.hkdm.enable = true;
    services.hkdm.configs."button-controls.toml" = ''
      [[events]]
      name = "media-next-when-screen-off"
      event_type = "EV_KEY"
      key_state = "held"
      keys = ["KEY_VOLUMEUP"]
      command = "${buttonControlsScript} next"

      [[events]]
      name = "media-previous-when-screen-off"
      event_type = "EV_KEY"
      key_state = "held"
      keys = ["KEY_VOLUMEDOWN"]
      command = "${buttonControlsScript} previous"

      [[events]]
      name = "torch-toggle-when-screen-off"
      event_type = "EV_KEY"
      key_state = "held"
      keys = ["KEY_POWER"]
      command = "${buttonControlsScript} torch"
    '';
  };
}
