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

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail '$(DESTDIR)/usr/bin' '$(DESTDIR)$(PREFIX)/bin' \
      --replace-fail '$(DESTDIR)/usr/lib/systemd' '$(DESTDIR)$(PREFIX)/lib/systemd' \
      --replace-fail '$(DESTDIR)/etc/init.d' '$(DESTDIR)$(PREFIX)/etc/init.d'
  '';

  makeFlags = [
    "PREFIX=$(out)"
  ];

  installTargets = "install";

  meta = with lib; {
    description = "Keep system time at an offset to a non-writable RTC";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/swclock-offset";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
