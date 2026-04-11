{
  lib,
  stdenv,
  fetchFromGitHub,
  freetype,
  fontconfig,
  pkg-config,
}:

stdenv.mkDerivation rec {
  pname = "fbkeyboard";
  version = "0.4";

  src = fetchFromGitHub {
    owner = "bakonyiferenc";
    repo = "fbkeyboard";
    rev = version;
    sha256 = "sha256-MQBydJIPaQydooWk9qyciG94kO9eV9g7SzxjBRJoSVI=";
  };

  buildInputs = [
    freetype
    fontconfig
    pkg-config
  ];

  nativeBuildInputs = [ pkg-config ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 fbkeyboard $out/bin/fbkeyboard
  '';

  meta = with lib; {
    description = "Framebuffer softkeyboard for touchscreen devices";
    homepage = "https://github.com/bakonyiferenc/fbkeyboard";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
