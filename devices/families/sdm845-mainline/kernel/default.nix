{
  mobile-nixos,
  fetchFromGitLab,
  ...
}:

mobile-nixos.kernel-builder {
  version = "6.16.7";
  configfile = ./config.aarch64;

  src = fetchFromGitLab {
    owner = "sdm845-mainline";
    repo = "linux";
    rev = "sdm845-6.16.7-r0";
    hash = "sha256-XYlXuzapuesiTpvquuz0b6yPyAqEdK9lMdglST+EZhk=";
  };

  isModular = false;
  isCompressed = "gz";

  # NFC patch for OnePlus 6/6T - enables SPI and GPIOs for NXP NFC controller
  # This is safe for other SDM845 devices as it only affects specific DT nodes
  patches = [ ./0001-oneplus-enchilada-enable-nfc.patch ];
}
