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

        This applies a device tree patch to enable the SPI controller and 
        GPIO pins required for the NXP NFC controller.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Apply the NFC DTB patch to the kernel
    mobile.boot.stage-1.kernel.patches = [
      ./oneplus-enchilada-nfc.patch
    ];

    # NFC kernel modules
    boot.kernelModules = [
      "nfcsim"
      "nci"
      "nci_spi"
    ];

    # Install userspace tools
    environment.systemPackages = [ pkgs.libnfc-nci ];
  };
}
