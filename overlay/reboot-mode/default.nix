{
  lib,
  stdenv,
  fetchgit,
}:

stdenv.mkDerivation rec {
  pname = "reboot-mode";
  version = "1.0.0";

  src = fetchgit {
    url = "https://gitlab.com/postmarketos/reboot-mode.git";
    rev = version;
    sha256 = "sha256-+W40tbVFo6/3gw3lD58YP+phfbTnaqHpnwK+Uign22E=";
  };

  nativeBuildInputs = [ ];

  buildInputs = [ ];

  buildPhase = ''
    gcc reboot-mode.c -o reboot-mode.o -c
    gcc reboot-mode.o -o reboot-mode
  '';

  installPhase = ''
    install -Dm755 reboot-mode $out/bin/reboot-mode
  '';

  meta = with lib; {
    description = "Tool to reboot a device into a specific mode";
    homepage = "https://gitlab.com/postmarketos/reboot-mode";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
