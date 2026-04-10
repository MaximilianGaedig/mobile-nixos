{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  automake,
  autoconf,
  libtool,
  dbus,
  glib,
  openssl,
  libxml2,
  systemd,
}:

stdenv.mkDerivation rec {
  pname = "libnfc-nci";
  version = "2.4.1";

  src = fetchFromGitHub {
    owner = "NXPNFCLinux";
    repo = "linux_libnfc-nci";
    rev = "R${version}";
    sha256 = "sha256-jgzwNLvDxROvuNpSXvr5CLlMMt5g0QuTujDcrSJeE5Y=";
  };

  patches = [
    ./PrintNDEFContent.patch
    ./fix-nfa-dm-p2p.patch
  ];

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    automake
    autoconf
    libtool
  ];

  # Run bootstrap to generate configure script
  preConfigure = ''
    ./bootstrap
  '';

  # Fix missing includes for modern compilers
  NIX_CFLAGS_COMPILE = "-include unistd.h -include string.h -include sys/times.h -include pthread.h -D_GNU_SOURCE";

  buildInputs = [
    dbus
    glib
    openssl
    libxml2
    systemd
  ];

  configureFlags = [
    "--enable-pn54x"
    "--enable-pn7150"
    "--enable-pn7160"
    "--enable-pn76xx"
    "--enable-pn7430"
    "--enable-i2c"
  ];

  meta = with lib; {
    description = "Linux NFC stack for NCI based NXP NFC Controllers";
    homepage = "https://github.com/NXPNFCLinux/linux_libnfc-nci";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
