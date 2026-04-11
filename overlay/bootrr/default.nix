{
  lib,
  stdenv,
  fetchgit,
}:

stdenv.mkDerivation rec {
  pname = "bootrr";
  version = "0.1_git20230827";

  src = fetchgit {
    url = "https://github.com/andersson/bootrr.git";
    rev = "cac8008d8ba6ba6e7361e87022d7ac1940b8c8b8";
    sha256 = "sha256-3tvAs/Y+7OefVh8FifI3CciCBkcQuBWNEqCbGXhPB6g=";
  };

  nativeBuildInputs = [ ];

  buildPhase = ''
    make prefix=/usr all
  '';

  installPhase = ''
    make prefix=/usr DESTDIR=$out install
  '';

  meta = with lib; {
    description = "Board sanity checker for automated testing";
    homepage = "https://github.com/andersson/bootrr";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
