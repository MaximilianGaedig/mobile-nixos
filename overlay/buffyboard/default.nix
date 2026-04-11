{
  lib,
  stdenv,
  fetchgit,
  meson,
  ninja,
  pkg-config,
  libinput,
  libevdev,
  libxkbcommon,
  cairo,
  fontconfig,
  freetype,
  inih,
}:

stdenv.mkDerivation rec {
  pname = "buffyboard";
  version = "3.2.0";

  src = fetchgit {
    url = "https://gitlab.postmarketos.org/postmarketOS/buffybox.git";
    rev = version;
    sha256 = "sha256-nZX7mSY9IBIhVNmOD6mXI1IF2TgyKLc00a8ADAvVLB0=";
    # Fetch LVGL submodule (required for build)
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    libinput
    libevdev
    libxkbcommon
    cairo
    fontconfig
    freetype
    inih
  ];

  # Build from the buffyboard subdirectory (similar to unl0kr APKBUILD's builddir)
  # This ensures include paths like "../sq2lv_layouts.h" resolve correctly
  preConfigure = ''
    cd buffyboard
  '';

  meta = with lib; {
    description = "On-screen keyboard for TTY/framebuffer";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/buffybox";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
