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
  cfg = config.services.shutdown-clear-rtc-wakealarm;
in
{
  options.services.shutdown-clear-rtc-wakealarm = {
    enable = mkEnableOption "clear RTC wake alarm before shutdown";
  };

  config = mkIf cfg.enable {
    systemd.services.shutdown-clear-rtc-wakealarm = {
      description = "Clear RTC wake alarm before shutdown";
      before = [
        "shutdown.target"
        "reboot.target"
        "halt.target"
      ];
      wantedBy = [ "shutdown.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = "${pkgs.bash}/bin/sh -c 'echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null || true'";
      };
    };
  };
}
