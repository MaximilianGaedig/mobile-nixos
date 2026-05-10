{
  lib,
  stdenv,
  fetchgit,
  buffyboard,
  terminus_font,
  kbd,
  procps,
  psmisc,
  coreutils,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "ttyescape";
  version = "1.0.1";

  src = fetchgit {
    url = "https://gitlab.postmarketos.org/postmarketOS/ttyescape.git";
    rev = version;
    sha256 = "sha256-RvMemYgAAlDGiGcnX00V8xWhxauS0C/omeLEWzJ6UhE=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace togglevt.sh \
      --replace-quiet "/usr/share/consolefonts/ter-128n.psf.gz" "${terminus_font}/share/consolefonts/ter-v32n.psf.gz"
  '';

  installPhase = ''
    install -Dm755 togglevt.sh $out/bin/ttyescape
    install -Dm644 ttyescape-hkdm.toml $out/share/ttyescape/ttyescape-hkdm.toml
  '';

  postFixup = ''
    wrapProgram $out/bin/ttyescape \
      --prefix PATH : ${
        lib.makeBinPath [
          kbd
          procps
          psmisc
          coreutils
          buffyboard
        ]
      }
  '';

  meta = with lib; {
    description = "Daemon to escape to TTY using hotkeys";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/ttyescape";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
