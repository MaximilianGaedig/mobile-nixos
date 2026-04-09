{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mobile.quirks.qualcomm.sdm845-sensors;
  inherit (lib) mkIf mkOption types;
in
{
  options.mobile.quirks.qualcomm.sdm845-sensors = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable sensor support for SDM845 devices
        Uses iio-sensor-proxy with libssc for FastRPC-based sensors
      '';
    };
    accelerometerMountMatrix = mkOption {
      type = types.listOf types.str;
      default = [
        "1"
        "0"
        "0"
        "0"
        "1"
        "0"
        "0"
        "0"
        "1"
      ];
      description = "3x3 mount matrix for accelerometer orientation";
    };
    deviceName = mkOption {
      type = types.str;
      default = "oneplus6";
      description = "Device name for sensor configuration";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.libssc
      pkgs.iio-sensor-proxy
    ];

    systemd.services.iio-sensor-proxy = {
      description = "IIO sensor proxy daemon";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.iio-sensor-proxy}/bin/iio-sensor-proxy";
        Restart = "always";
        RestartSec = "5";
      };
    };

    services.udev.extraHwdb = ''
      # Accelerometer mount matrix for ${cfg.deviceName}
      sensor:modalias:*:dmi:*svn*OnePlus*pn*${cfg.deviceName}*
      ACCEL_MATRIX=${lib.concatStringsSep "," cfg.accelerometerMountMatrix}
    '';
  };
}
