{
  lib,
  fetchFromGitLab,
  alsa-lib,
  dbus,
  stdenv,
  pkg-config,
  meson,
  ninja,
}:

stdenv.mkDerivation rec {
  pname = "q6voiced";
  version = "0.2.1";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "q6voiced";
    rev = version;
    sha256 = "0130s2iqywrbxgi3mmxxpic7l5kfhb7mvwpykzjyxx2icn065hvz";
  };

  buildInputs = [
    alsa-lib
    dbus
  ];

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
  ];

  meta = with lib; {
    description = "Userspace QDSP6 voice driver daemon listening on oFono/ModemManager";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/q6voiced/";
    license = licenses.mit;
    platforms = platforms.aarch64;
  };
}
