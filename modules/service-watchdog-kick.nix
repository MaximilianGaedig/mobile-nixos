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
  cfg = config.services.watchdog-kick;
in
{
  options.services.watchdog-kick = {
    enable = mkEnableOption "watchdog-kick service to prevent hardware watchdog resets";
  };

  config = mkIf cfg.enable {
    systemd.services.watchdog-kick = {
      description = "Periodically kick hardware watchdogs";
      after = [ "systemd-modules-load.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.watchdog-kick}/bin/watchdog-kick";
        ExecStop = "${pkgs.watchdog-kick}/bin/watchdog-kick -1";
        Restart = "always";
        RestartSec = 5;
        KillSignal = "SIGTERM";
        TimeoutStopSec = 5;
      };
    };
  };
}
