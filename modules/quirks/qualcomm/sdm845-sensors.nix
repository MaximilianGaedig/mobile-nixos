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
    hexagonrpcFwDir = mkOption {
      type = types.str;
      default = "/usr/share/qcom/sdm845/OnePlus/oneplus6";
      description = "Root directory of sensor calibration firmware files served by hexagonrpcd";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.libssc
      pkgs.iio-sensor-proxy
    ];

    systemd.packages = [ pkgs.iio-sensor-proxy ];

    systemd.services.hexagonrpcd-sdsp = {
      description = "Hexagon DSP daemon for SDSP (Sensor DSP)";
      wantedBy = [ "multi-user.target" ];
      bindsTo = [ "dev-fastrpc\\x2dsdsp.device" ];
      after = [ "dev-fastrpc\\x2dsdsp.device" ];
      serviceConfig = {
        ExecStart = "${pkgs.hexagonrpc}/bin/hexagonrpcd -f /dev/fastrpc-sdsp -d sdsp -s -R ${cfg.hexagonrpcFwDir}";
        Restart = "always";
        RestartSec = "5";
      };
    };

    # iio-sensor-proxy needs hexagonrpcd-sdsp to be ready
    systemd.services.iio-sensor-proxy = {
      after = [ "hexagonrpcd-sdsp.service" ];
      requires = [ "hexagonrpcd-sdsp.service" ];
    };

    services.udev.extraHwdb = ''
      # Accelerometer mount matrix for ${cfg.deviceName}
      sensor:modalias:*:dmi:*svn*OnePlus*pn*${cfg.deviceName}*
      ACCEL_MATRIX=${lib.concatStringsSep "," cfg.accelerometerMountMatrix}
    '';
  };
}
