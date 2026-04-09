{
  lib,
  fetchFromGitLab,
  tinyalsa,
  dbus,
  stdenv,
}:

let
  dbusLib = dbus.lib or dbus.out or dbus;
  dbusDev = dbus.dev or dbus;
in

stdenv.mkDerivation rec {
  pname = "q6voiced";
  version = "0_git20210408";
  _commit = "a75518e1ddf44971b1181e12c328dd250b62962a";

  src = fetchFromGitLab {
    owner = "postmarketOS";
    repo = "q6voiced";
    rev = _commit;
    sha256 = "sha256-IZOWjOGDUwyBbIxSTIi27UvwKLB6dLvwvcaQn7Jkv4Y=";
  };

  buildInputs = [
    tinyalsa
    dbusLib
    dbusDev
  ];

  buildPhase = ''
    gcc -o q6voiced q6voiced.c \
      -I${dbusDev}/include/dbus-1.0 \
      -I${dbusDev}/include \
      -I${dbusLib}/include/dbus-1.0 \
      -L${dbusLib}/lib -ldbus-1 \
      -L${tinyalsa}/lib -ltinyalsa
  '';

  installPhase = ''
    install -Dm755 q6voiced $out/bin/q6voiced
  '';

  meta = with lib; {
    description = "Enable q6voice audio when call is performed with oFono/ModemManager";
    homepage = "https://github.com/msm8916-mainline/linux";
    license = licenses.mit;
    platforms = platforms.aarch64;
  };
}
