{
  lib,
  stdenv,
  fetchgit,
  makeWrapper,
  # Script dependencies
  alsa-utils,
  dmenu,
  fzf,
  gawk,
  gnugrep,
  gnused,
  jq,
  libnotify,
  mpc,
  mpv,
  ncurses,
  networkmanager,
  procps,
  pulseaudio,
  sqlite,
  w3m,
  wcalc,
  wget,
  wirelesstools,
}:

let
  # List of f_scripts to install
  scripts = [
    "f_audio"
    "f_files"
    "f_game"
    "f_maps"
    "f_networks"
    "f_phone"
    "f_rss"
    "f_theme"
    "f_timer"
    "f_web"
    "f_youtube"
  ];
in
stdenv.mkDerivation rec {
  pname = "f-scripts";
  version = "0.4";

  src = fetchgit {
    url = "https://git.sr.ht/~mil/f_scripts";
    rev = version;
    sha256 = "sha256-qBYLLM+8PAbp/1DuzuaY1VvDtpLNMZpmPqEVUqOKoa8=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/f-scripts

    # Install each script
    for script in ${lib.concatStringsSep " " scripts}; do
      if [ -f "$script" ]; then
        install -Dm755 "$script" "$out/bin/$script"

        # Wrap with dependencies
        wrapProgram "$out/bin/$script" \
          --prefix PATH : ${
            lib.makeBinPath [
              alsa-utils
              dmenu
              fzf
              gawk
              gnugrep
              gnused
              jq
              libnotify
              mpc
              mpv
              ncurses
              networkmanager
              procps
              pulseaudio
              sqlite
              w3m
              wcalc
              wget
              wirelesstools
            ]
          }
      fi
    done

    # Install documentation
    if [ -d "docs" ]; then
      cp -r docs $out/share/f-scripts/
    fi
  '';

  meta = with lib; {
    description = "Utility scripts for framebufferphone UI";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/f_scripts";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
