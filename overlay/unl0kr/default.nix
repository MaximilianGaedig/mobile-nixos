{
  lib,
  stdenv,
  fetchgit,
  meson,
  ninja,
  pkg-config,
  scdoc,
  libinput,
  libevdev,
  libxkbcommon,
  libdrm,
  udev,
  cairo,
  fontconfig,
  freetype,
  inih,
}:

stdenv.mkDerivation rec {
  pname = "unl0kr";
  version = "3.2.0";

  # unl0kr lives in the same "buffybox" monorepo as buffyboard (see ../buffyboard),
  # each as its own independent meson project in its own subdirectory.
  src = fetchgit {
    url = "https://gitlab.postmarketos.org/postmarketOS/buffybox.git";
    rev = version;
    sha256 = "sha256-nZX7mSY9IBIhVNmOD6mXI1IF2TgyKLc00a8ADAvVLB0=";
    # Fetch LVGL submodule (required for build)
    fetchSubmodules = true;
  };

  patches = [
    # Idle backlight dimming, similar to iOS's idle screen dimming: fades the
    # backlight out after a period of no touch/key input, and back in on new
    # input. See the patch for the configurable [backlight] options.
    ../../../patches/unl0kr-idle-backlight-dim.patch
    # Battery status indicator (icon + percentage, with a charging glyph) shown
    # in the header when a battery power supply is present. Applied on top of
    # the backlight patch above (adds a "battery" module alongside it, and a
    # couple of adjoining lines in main.c/config.c/config.h/meson.build).
    ../../../patches/unl0kr-battery-indicator.patch
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    scdoc
  ];

  buildInputs = [
    libinput
    libevdev
    libxkbcommon
    libdrm
    udev
    cairo
    fontconfig
    freetype
    inih
  ];

  # Build from the unl0kr subdirectory (similar to unl0kr APKBUILD's builddir)
  # This ensures include paths like "../shared/log.h" resolve correctly.
  # Mirrors ../buffyboard/default.nix, which does the same for the buffyboard
  # subdirectory of this same source tree.
  preConfigure = ''
    cd unl0kr
  '';

  meta = with lib; {
    description = "Graphical, mobile-friendly disk unlock (LUKS) tool";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/buffybox";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
