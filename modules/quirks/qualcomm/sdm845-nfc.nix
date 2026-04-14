{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mobile.quirks.qualcomm.sdm845-nfc;
  inherit (lib) mkIf mkOption types;
in
{
  options.mobile.quirks.qualcomm.sdm845-nfc = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable NFC support for SDM845 devices (OnePlus 6/6T).

        This enables the I2C and GPIO configuration for the NXP NFC controller.
        NFC hardware is already enabled in the sdm845-mainline kernel.

        This also installs the libnfc-nci userspace tools.
      '';
    };
  };

  config = mkIf cfg.enable {
    # NFC kernel modules
    boot.kernelModules = [
      "nfcsim"
      "nci"
      "nci_i2c"
    ];

    environment.systemPackages = [ pkgs.libnfc-nci ];
  };
}
