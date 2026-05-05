{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "qmic";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "andersson";
    repo = "qmic";
    rev = "v${version}";
    sha256 = "1k0p48kx5wd0nb642x5g49z8vnr0k6lyh42vd6cswdr9vy1qiyfk";
  };

  installFlags = [ "prefix=$(out)" ];

  meta = with lib; {
    description = "QMI IDL compiler";
    homepage = "https://github.com/andersson/qmic";
    license = licenses.bsd3;
    platforms = platforms.aarch64;
  };
}
