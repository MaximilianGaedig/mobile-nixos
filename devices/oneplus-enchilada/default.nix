{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../families/sdm845-mainline
  ];

  mobile.device.name = "oneplus-enchilada";
  mobile.device.identity = {
    name = "OnePlus 6";
    manufacturer = "OnePlus";
  };
  mobile.device.supportLevel = "supported";

  mobile.hardware = {
    ram = 1024 * 8;
    screen = {
      width = 1080;
      height = 2280;
    };
  };

  mobile.device.firmware = pkgs.callPackage ./firmware { };

  mobile.system.android.device_name = "OnePlus6";

  # Audio configuration with q6voiced enabled for call audio
  mobile.quirks.qualcomm.sdm845-audio = {
    enable = true;
    q6voiced = {
      card = 0;
      device = 6;
    };
    hexagonrpc-fw-dir = "/usr/share/qcom/sdm845/OnePlus/oneplus6";
  };

  systemd.services.swclock-offset.enable = lib.mkDefault true;

  # Sensors using nixpkgs packages (libssc 0.2.2, iio-sensor-proxy 3.8)
  mobile.quirks.qualcomm.sdm845-sensors = {
    enable = true;
    accelerometerMountMatrix = [
      "0"
      "1"
      "0"
      "-1"
      "0"
      "0"
      "0"
      "0"
      "1"
    ];
    deviceName = "oneplus6";
  };

  # NFC support
  mobile.quirks.qualcomm.sdm845-nfc.enable = true;

  mobile.boot.stage-1 = {
    # currrently not working because still on ruby
    # # Enable key detection for debug shell triggers (Volume Down → debug shell)
    # key-detection = {
    #   enable = lib.mkDefault true;
    #   debug-shell-key = "volume_down";
    # };

    # same here
    # # Enable LED feedback for boot errors
    # leds.enable = lib.mkDefault true;

    # same here
    # # Enable haptic feedback for boot errors (uses qcom_spmi_haptics)
    # haptics.enable = lib.mkDefault true;
  };

  # Stage-2 services
  services.shutdown-clear-rtc-wakealarm.enable = lib.mkDefault true;

  # # Enable ttyescape for emergency TTY access
  # services.ttyescape.enable = lib.mkDefault true;

  # Add reboot-mode utility to system packages
  environment.systemPackages = [ pkgs.reboot-mode ];

  # Camera tuning files for libcamera simple IPA
  # OnePlus 6 uses Sony IMX371 (front) and IMX376 (rear secondary) sensors
  environment.etc."libcamera/ipa/simple/imx371.yaml".text = ''
    # SPDX-License-Identifier: CC0-1.0
    %YAML 1.1
    ---
    version: 1
    algorithms:
      - BlackLevel:
          blackLevel: 4096
      - Awb:
      - Adjust:
      - Agc:
  '';

  environment.etc."libcamera/ipa/simple/imx376.yaml".text = ''
    # SPDX-License-Identifier: CC0-1.0
    %YAML 1.1
    ---
    version: 1
    algorithms:
      - BlackLevel:
          blackLevel: 4096
      - Awb:
      - Adjust:
      - Agc:
  '';

}
