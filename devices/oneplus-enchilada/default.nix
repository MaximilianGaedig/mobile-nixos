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

  # Disable services not needed for enchilada
  systemd.services.bootmac.enable = lib.mkDefault false; # MAC already set by kernel
  systemd.services.swclock-offset.enable = lib.mkDefault false; # Has writable RTC

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

  # PostmarketOS feature parity
  # Initramfs enhancements
  mobile.boot.stage-1 = {
    # Enable on-screen keyboard for TTY in initramfs
    buffyboard.enable = lib.mkDefault true;

    # Enable key detection for debug shell triggers (Volume Down → debug shell)
    key-detection = {
      enable = lib.mkDefault true;
      debug-shell-key = "volume_down";
    };

    # Enable LED feedback for boot errors
    leds.enable = lib.mkDefault true;

    # Enable haptic feedback for boot errors (uses qcom_spmi_haptics)
    haptics.enable = lib.mkDefault true;
  };

  # Stage-2 services
  # watchdog-kick disabled - causes "watchdog did not stop" errors on enchilada
  # services.watchdog-kick.enable = lib.mkDefault true;
  services.shutdown-clear-rtc-wakealarm.enable = lib.mkDefault true;

  # Enable ttyescape for emergency TTY access
  services.ttyescape.enable = lib.mkDefault true;

  # Add reboot-mode utility to system packages
  environment.systemPackages = [ pkgs.reboot-mode ];
}
