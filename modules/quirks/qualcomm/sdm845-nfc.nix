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

        This enables the SPI controller and GPIO pins required for the NXP 
        NFC controller via a kernel DTB patch.

        Note: Userspace tools (libnfc-nci) are not yet packaged. NFC hardware
        will be enabled but you'll need to manually install userspace tools.
      '';
    };
  };

  config = mkIf cfg.enable {
    # NFC kernel modules
    boot.kernelModules = [
      "nfcsim"
      "nci"
      "nci_spi"
    ];

    # Note: libnfc-nci userspace tools are not yet packaged
    # environment.systemPackages = [ pkgs.libnfc-nci ];
  };
}
