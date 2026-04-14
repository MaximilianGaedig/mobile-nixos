{ stdenv, pkgs }:

stdenv.mkDerivation {
  pname = "nixos-boot-cfg-tests";
  version = "1.0";

  src = ./.;

  buildInputs = [
    pkgs.gawk
    pkgs.coreutils
  ];

  doCheck = true;

  checkPhase = ''
    # Create test directory
    mkdir -p $out/tests

    # Copy test script
    cp ${./test.sh} $out/tests/test.sh
    chmod +x $out/tests/test.sh

    # Copy the script under test
    cp ${./nixos-boot-cfg.sh} $out/tests/nixos-boot-cfg.sh

    # Run tests
    cd $out/tests
    ./test.sh || exit 1
  '';

  installPhase = ''
    # Tests already copied in checkPhase
    # This phase just ensures the derivation succeeds
    :
  '';
}
