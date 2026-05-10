{
  mobile-nixos,
  fetchFromGitLab,
  pkgs,
  ...
}:

mobile-nixos.kernel-builder {
  version = "6.19.0-rc6-next-20260119";
  configfile = ./config.aarch64;

  src = fetchFromGitLab {
    owner = "sdm845";
    repo = "sdm845-next";
    rev = "sdm845-next";
    hash = "sha256-BTRI491/qgc8hw1IG/N7QB2fTDq6KIYuDOSpx9eKrL0=";
  };

  patches = [
    ./0003-qseecom-enable-oneplus6.patch
  ];

  isModular = true;
  isCompressed = "gz";
  nativeBuildInputs = [ pkgs.zstd ];
}
