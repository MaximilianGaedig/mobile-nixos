{
  lib,
  stdenv,
  fetchFromGitLab,
}:

stdenv.mkDerivation rec {
  pname = "swclock-offset";
  version = "0.2.4";

  src = fetchFromGitLab {
    owner = "postmarketOS";
    repo = "swclock-offset";
    rev = version;
    sha256 = "sha256-Qqvu4GH016pz8+iMDECE2zXCPKhDPHo3CPzPPgJhITw=";
  };

  makeFlags = [
    "DESTDIR=$(out)"
    "PREFIX="
  ];

  installTargets = "install";

  meta = with lib; {
    description = "Keep system time at an offset to a non-writable RTC";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/swclock-offset";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
