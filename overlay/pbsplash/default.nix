{
  lib,
  stdenv,
  fetchgit,
  meson,
  ninja,
  pkg-config,
  cairo,
  libpng,
  libdrm,
  tfblib,
}:

stdenv.mkDerivation rec {
  pname = "pbsplash";
  version = "0.3.1";

  src = fetchgit {
    url = "https://git.sr.ht/~calebccff/pbsplash";
    rev = version;
    sha256 = "sha256-hZzroKxh1omybkd2Tn+GupLYBR1EkLCDD+4lTaWPnEw=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    cairo
    libpng
    libdrm
    tfblib
  ];

  meta = with lib; {
    description = "Plymouth-like boot splash for postmarketOS";
    homepage = "https://git.sr.ht/~calebccff/pbsplash";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
