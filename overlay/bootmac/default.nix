{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  gawk,
  bluez,
  iproute2,
  util-linux,
  makeWrapper,
  coreutils,
  gnugrep,
  gnused,
}:
stdenv.mkDerivation rec {
  pname = "bootmac";
  version = "0.7.1";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "bootmac";
    rev = "v${version}";
    sha256 = "sha256-GWvZUC8LKPpOWt1oCr93JHg5+W+0CCiYT63VhpSH1ko=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    makeWrapper
  ];

  mesonFlags = [
    "-Dsystemd_units=true"
  ];

  postPatch = ''
    substituteInPlace bootmac-bluetooth.rules bootmac-wifi.rules systemd/bootmac@.service \
      --replace-quiet "/usr/bin/bootmac" "$out/bin/bootmac"
  '';

  postFixup = ''
    wrapProgram $out/bin/bootmac \
      --prefix PATH : ${
        lib.makeBinPath [
          gawk
          bluez
          iproute2
          util-linux
          coreutils
          gnugrep
          gnused
        ]
      }
  '';

  meta = with lib; {
    description = "Configure MAC addresses at boot";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/bootmac";
    license = licenses.gpl3;
    platforms = platforms.aarch64;
  };
}
