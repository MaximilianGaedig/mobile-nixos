{
  lib,
  stdenv,
  fetchgit,
  zig,
}:

stdenv.mkDerivation rec {
  pname = "fbp";
  version = "0.4";

  src = fetchgit {
    url = "https://git.sr.ht/~mil/fbp";
    rev = version;
    sha256 = "sha256-Dn/ym76+w2/4XgeVaCWUzrgP6nu1xEKhYGD9w18fnzU=";
  };

  nativeBuildInputs = [ zig ];

  buildPhase = ''
    zig build -Drelease-safe
  '';

  installPhase = ''
    install -Dm755 zig-out/bin/framebufferphone $out/bin/framebufferphone
    install -Dm644 zig-out/share/applications/framebufferphone.desktop $out/share/applications/framebufferphone.desktop
  '';

  meta = with lib; {
    description = "Minimalist framebuffer menu/keyboard UI for mobile devices";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/framebufferphone";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
