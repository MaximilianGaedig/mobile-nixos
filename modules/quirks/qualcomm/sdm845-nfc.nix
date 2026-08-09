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

        This loads the NXP NCI I2C kernel driver and enables the neard
        NFC daemon for tag reading and card emulation.
      '';
    };
  };

  config = mkIf cfg.enable {
    # NXP NCI I2C driver for the PN553 NFC controller
    boot.kernelModules = [
      "nxp-nci"
      "nxp-nci_i2c"
    ];

    # Linux NFC daemon (neard) for standard kernel NFC subsystem support
    services.neard.enable = true;

    # libnfc-nci with gpiod support for direct userspace I2C/GPIO access
    environment.systemPackages = [ pkgs.libnfc-nci ];

    # Install libnfc-nci configuration files
    environment.etc."libnfc-nci.conf".source = "${pkgs.libnfc-nci}/etc/libnfc-nci.conf";
    environment.etc."libnfc-nxp-init.conf".source = "${pkgs.libnfc-nci}/etc/libnfc-nxp-init.conf";
    environment.etc."libnfc-nxp-pn547.conf".source = "${pkgs.libnfc-nci}/etc/libnfc-nxp-pn547.conf";
    environment.etc."libnfc-nxp-pn548.conf".source = "${pkgs.libnfc-nci}/etc/libnfc-nxp-pn548.conf";
  };
}
