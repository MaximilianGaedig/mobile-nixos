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

        Note: Userspace tools (libnfc-nci) are not yet packaged due to upstream
        code quality issues. NFC hardware will work but userspace applications
        will need to be installed manually.
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

    # Note: libnfc-nci userspace tools are not yet packaged
    # See: https://github.com/NXPNFCLinux/linux_libnfc-nci
    # environment.systemPackages = [ pkgs.libnfc-nci ];
  };
}
