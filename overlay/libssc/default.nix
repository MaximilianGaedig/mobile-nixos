{
  lib,
  stdenv,
  fetchFromCodeberg,
  meson,
  ninja,
  glib,
  pkg-config,
  libqmi,
  protobufc,
  protobuf,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libssc";
  version = "0.4.0";

  src = fetchFromCodeberg {
    owner = "DylanVanAssche";
    repo = "libssc";
    rev = "v${finalAttrs.version}";
    hash = "sha256-2MVsgSS1GKmErla9w6DFVY8tDvpwK7Rjl+ikBuCM4rc=";
  };

  buildInputs = [
    glib
    protobufc
  ];

  propagatedBuildInputs = [
    libqmi
  ];

  nativeBuildInputs = [
    protobuf
    protobufc
    pkg-config
    meson
    ninja
  ];

  strictDeps = true;

  mesonBuildFlags = [
    "-Dlibqmi=enabled"
    "-Ddocs=disabled"
  ];

  installPhase = ''
    meson install --no-rebuild -C build
  '';

  meta = with lib; {
    description = "Library for exposing Qualcomm Sensor Core sensors to Linux";
    homepage = "https://codeberg.org/DylanVanAssche/libssc";
    license = licenses.gpl3Only;
    platforms = platforms.aarch64;
  };
})
