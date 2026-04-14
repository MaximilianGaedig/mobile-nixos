{ stdenv, pkgs,lib }:

stdenv.mkDerivation {
  pname = "nixos-boot-cfg";
  version = "1.0";

  src = ./.;

  buildPhase = ''
    $CC -Wall -o nixos-boot-cfg nixos-boot-cfg.c
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp nixos-boot-cfg $out/bin/

    # Copy helper scripts
    cp mobile-nixos-menu.sh $out/bin/mobile-nixos-menu
    chmod +x $out/bin/mobile-nixos-menu
  '';

  doCheck = true;
  nativeBuildInputs = [ pkgs.which ];

  checkPhase = ''
    export PATH="$out/bin:$PATH"
    bash test.sh
  '';

  meta = {
    description = "Mobile NixOS boot configuration storage tool";
    license = lib.licenses.mit;
  };
}
