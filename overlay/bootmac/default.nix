{
  lib,
  stdenv,
  fetchFromGitLab,
}:

stdenv.mkDerivation rec {
  pname = "bootmac";
  version = "0.5.0";

  src = fetchFromGitLab {
    owner = "postmarketOS";
    repo = "bootmac";
    rev = "v${version}";
    sha256 = "sha256-zYXYVcX1XlRvRoPBepD1xIwCFUDcTzm3KMJSLx46z7g=";
  };

  installPhase = ''
    install -Dm755 bootmac $out/bin/bootmac
    install -Dm644 bootmac.rules $out/lib/udev/rules.d/90-bootmac.rules
  '';

  meta = with lib; {
    description = "Configure MAC addresses at boot";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/bootmac";
    license = licenses.gpl3;
    platforms = platforms.aarch64;
  };
}
