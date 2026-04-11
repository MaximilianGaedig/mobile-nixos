{
  lib,
  stdenv,
  fetchgit,
  meson,
  ninja,
  pkg-config,
  libevdev,
  linuxHeaders,
}:

stdenv.mkDerivation rec {
  pname = "iskey";
  version = "3.2.0";

  src = fetchgit {
    url = "https://gitlab.postmarketos.org/postmarketOS/buffybox.git";
    rev = version;
    sha256 = "sha256-nZX7mSY9IBIhVNmOD6mXI1IF2TgyKLc00a8ADAvVLB0=";
  };

  sourceRoot = "${src.name}/iskey";

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    libevdev
    linuxHeaders
  ];

  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 iskey $out/bin/iskey
  '';

  meta = with lib; {
    description = "Tiny tool to check if specific keys are pressed";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/buffybox";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
