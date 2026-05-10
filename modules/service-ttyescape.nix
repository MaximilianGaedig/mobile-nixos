{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  cfg = config.services.ttyescape;
in
{
  options.services.ttyescape = {
    enable = mkEnableOption "ttyescape for emergency TTY access via hotkeys";
  };

  config = mkIf cfg.enable {
    systemd.services.ttyescape = {
      description = "TTY escape daemon";
      after = [
        "systemd-logind.service"
        "graphical-session.target"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.ttyescape}/bin/ttyescape";
        RemainAfterExit = true;
      };
    };

    # Enable hkdm hotkey daemon
    systemd.services.hkdm = {
      description = "Hotkey daemon";
      after = [ "systemd-logind.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.hkdm}/bin/hkdm -c /etc/hkdm";
        Restart = "always";
      };
    };

    # Create hkdm configuration
    environment.etc."hkdm/ttyescape.toml".source = pkgs.writeText "ttyescape.toml" ''
      [[events]]
      name = "ttyescape"
      event_type = "EV_KEY"
      key_state = "pressed"
      keys = ["KEY_POWER", "KEY_VOLUMEUP"]
      command = "${pkgs.ttyescape}/bin/ttyescape"
    '';
  };
}
