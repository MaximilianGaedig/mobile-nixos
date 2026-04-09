{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  glib,
  libqmi,
  libqrtr-glib,
  protobufc,
  modemmanager,
  qrtr,
}:

stdenv.mkDerivation rec {
  pname = "81voltd";
  version = "1.0.0";

  src = fetchFromGitLab {
    owner = "flamingradian";
    repo = "81voltd";
    rev = "v${version}";
    sha256 = "sha256-w1HxF1tUiD44Rqox6mr3A+Bd0Uv6a/K53f17QxZu0fo=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    glib
    libqmi
    libqrtr-glib
    protobufc
    modemmanager
    qrtr
  ];

  mesonBuildFlags = [
    "-Dqrtr_aidn=new"
  ];

  installPhase = ''
    install -Dm755 81voltd $out/bin/81voltd
  '';

  meta = with lib; {
    description = "Server-side implementation of the QMI IMS Data service";
    homepage = "https://gitlab.com/flamingradian/81voltd";
    license = licenses.gpl2;
    platforms = platforms.aarch64;
  };
}
