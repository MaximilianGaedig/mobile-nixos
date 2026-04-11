{
  lib,
  stdenv,
  fetchgit,
  hkdm,
  buffyboard,
  terminus_font,
  kbd,
}:

stdenv.mkDerivation rec {
  pname = "ttyescape";
  version = "1.0.1";

  src = fetchgit {
    url = "https://gitlab.postmarketos.org/postmarketOS/ttyescape.git";
    rev = version;
    sha256 = "sha256-RvMemYgAAlDGiGcnX00V8xWhxauS0C/omeLEWzJ6UhE=";
  };

  buildInputs = [ ];

  installPhase = ''
    install -Dm755 togglevt.sh $out/bin/ttyescape
    install -Dm644 ttyescape-hkdm.toml $out/share/ttyescape/ttyescape-hkdm.toml
  '';

  propagatedBuildInputs = [
    hkdm
    buffyboard
    terminus_font
    kbd
  ];

  meta = with lib; {
    description = "Daemon to escape to TTY using hotkeys";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/ttyescape";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
