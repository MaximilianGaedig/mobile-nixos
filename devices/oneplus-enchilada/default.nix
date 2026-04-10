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

  # q6voiced disabled - dbus build compatibility issue with nixpkgs
  # hexagonrpc works via nixpkgs package
  mobile.quirks.qualcomm.sdm845-audio = {
    enable = true;
    # q6voiced = {
    #   card = 0;
    #   device = 6;
    # };
    hexagonrpc-fw-dir = "/usr/share/qcom/sdm845/OnePlus/oneplus6";
  };

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
}
