{
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "watchdog-kick";
  version = "0.1";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
        mkdir -p $out/bin
        cat > $out/bin/watchdog-kick << 'EOF'
    #!/bin/sh

    watchdog_kick() {
    	while true; do
    		for wd in /dev/watchdog*; do
    			[ -c $wd ] && echo X > $wd
    		done
    		[ -z "$1" ] && sleep 10s || exit
    	done
    }

    if [ -z "$1" ]; then
    	watchdog_kick
    else
    	if [ "$1" != "-1" ]; then
    		echo "Invalid argument"
    		exit 1
    	fi
    	watchdog_kick $1
    fi
    EOF
        chmod +x $out/bin/watchdog-kick
  '';

  meta = with lib; {
    description = "Periodically kick hardware watchdogs to prevent system reset";
    homepage = "https://postmarketos.org";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
