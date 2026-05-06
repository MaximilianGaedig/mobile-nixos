{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  systemd,
  gawk,
  bluez,
  iproute2,
  util-linux,
  makeWrapper,
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

  buildInputs = [
    systemd
  ];

  postPatch = ''
    substituteInPlace bootmac-bluetooth.rules bootmac-wifi.rules systemd/bootmac@.service \
      --replace-quiet "/usr/bin/bootmac" "$out/bin/bootmac" \
      --replace-quiet "/bin/bootmac" "$out/bin/bootmac"
  '';

  # Wrap the executable after Meson installs it
  postFixup = ''
    wrapProgram $out/bin/bootmac \
      --prefix PATH : ${
        lib.makeBinPath [
          gawk
          bluez
          iproute2
          util-linux
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
