{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      msm8916-alsa-ucm = self.callPackage (
        { runCommand, fetchFromGitHub }:

        runCommand "msm8916-alsa-ucm" {
          src = fetchFromGitHub {
            name = "msm8916-alsa-ucm";
            owner = "msm8916-mainline";
            repo = "alsa-ucm-conf";
            rev = "3deea2860ab680c3e790442dbdf578fef152e639"; # master, captured 22 Apr 2024
            sha256 = "sha256-SRShCqcF2COE6FWdlz1znkUAeRtoFqcOcW8t7N5Wwrc=";
          };
        } ''
          mkdir -p $out/share/
          ln -s $src $out/share/alsa
        ''
      ) {};
    })
  ];

  # Alsa UCM profiles
  # mobile.quirks.audio.alsa-ucm-meld = true; # REVIEW: Needed?
  environment.systemPackages = [
    pkgs.msm8916-alsa-ucm
  ];
}

