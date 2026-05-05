{ stdenv, lib, fetchFromGitHub, qrtr, meson, ninja, pkg-config, zstd }:

stdenv.mkDerivation rec {
  pname = "tqftpserv";
  version = "1.1.1";

  buildInputs = [ qrtr zstd ];
  nativeBuildInputs = [ meson ninja pkg-config ];

  src = fetchFromGitHub {
    owner = "linux-msm";
    repo = "tqftpserv";
    rev = "v${version}";
    hash = "sha256-cwoAinvO2bQ6Ylx1zzh5ycE7om2vgk9uqyDJhpy6jP4=";
  };

  patches = [
    ./tqftpserv-firmware-path.diff
  ];

  mesonFlags = [
    "-Dsystemd-unit-prefix=${placeholder "out"}/lib/systemd/system/"
  ];

  meta = with lib; {
    description = "Trivial File Transfer Protocol server over AF_QIPCRTR";
    homepage = "https://github.com/linux-msm/tqftpserv";
    license = licenses.bsd3;
    platforms = platforms.aarch64;
  };
}
