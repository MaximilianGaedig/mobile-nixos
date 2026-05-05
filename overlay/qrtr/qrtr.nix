{ stdenv, lib, fetchFromGitHub, meson, ninja, linuxHeaders }:

stdenv.mkDerivation rec {
  pname = "qrtr";
  version = "1.2";

  src = fetchFromGitHub {
    owner = "linux-msm";
    repo = "qrtr";
    rev = "v${version}";
    hash = "sha256-plVPR3BKtMLSVgTK8TPFbt5vuo9ZovEGz6qJzUZ33G4=";
  };

  nativeBuildInputs = [ meson ninja ];
  buildInputs = [ linuxHeaders ];

  mesonFlags = [
    "-Dsystemd-service=disabled"
  ];

  meta = with lib; {
    description = "Userspace reference for net/qrtr in the Linux kernel";
    homepage = "https://github.com/linux-msm/qrtr";
    license = licenses.bsd3;
    platforms = platforms.aarch64;
  };
}
