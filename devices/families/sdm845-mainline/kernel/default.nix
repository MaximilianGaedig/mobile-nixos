{
  pkgs,
  ...
}:

let
  kernel = pkgs.buildLinux {
    version = "6.16.7";
    modDirVersion = "6.16.7";
    configfile = ./config.aarch64;

    src = pkgs.fetchFromGitLab {
      owner = "sdm845-mainline";
      repo = "linux";
      rev = "sdm845-6.16.7-r0";
      hash = "sha256-XYlXuzapuesiTpvquuz0b6yPyAqEdK9lMdglST+EZhk=";
    };

    extraNativeBuildInputs = [ pkgs.zstd ];
    kernelPatches = [ ];
    ignoreConfigErrors = true;
  };
in
kernel.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    if [ -f "$buildRoot/arch/arm64/boot/Image.gz" ]; then
      cp -v "$buildRoot/arch/arm64/boot/Image.gz" "$out/"
    fi
  '';
  passthru = (oldAttrs.passthru or { }) // {
    file = "Image.gz";
    isQcdt = false;
    isExynosDT = false;
  };
})
