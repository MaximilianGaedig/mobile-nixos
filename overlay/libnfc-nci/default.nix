{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
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
  ];

  # Fix missing includes for modern compilers
  postPatch = ''
    # Add unistd.h to files that use read/write/close/sleep
    find src -name "*.c" -exec grep -l "\\b\(read\\|write\\|close\\|sleep\\)\\s*(" {} \; | while read f; do
      if ! grep -q "#include <unistd.h>" "$f"; then
        sed -i '1a\\#include <unistd.h>' "$f"
      fi
    done
  '';

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

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
