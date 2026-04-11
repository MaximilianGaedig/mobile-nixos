{
  lib,
  rustPlatform,
  fetchgit,
  pkg-config,
  libevdev,
}:

rustPlatform.buildRustPackage rec {
  pname = "hkdm";
  version = "0.2.0";

  src = fetchgit {
    url = "https://gitlab.postmarketos.org/postmarketOS/hkdm.git";
    rev = version;
    sha256 = "sha256-YOChDgE2QFkguhwgvsN3gYzHgB9PGFHC8EIxxjMXn4Y=";
  };

  cargoHash = "sha256-F4euAdzLaxdDG4jcLoSD76bW3dxjWCoSCb6Zb41moC0=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libevdev
  ];

  meta = with lib; {
    description = "Hotkey daemon that reacts to input events";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/hkdm";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
