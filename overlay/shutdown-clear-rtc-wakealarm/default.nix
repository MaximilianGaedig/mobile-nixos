{
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "shutdown-clear-rtc-wakealarm";
  version = "1.0.0";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
        mkdir -p $out/libexec
        cat > $out/libexec/shutdown-clear-rtc-wakealarm << 'EOF'
    #!/bin/sh
    echo 0 > /sys/class/rtc/rtc0/wakealarm
    EOF
        chmod +x $out/libexec/shutdown-clear-rtc-wakealarm
  '';

  meta = with lib; {
    description = "Clear RTC wake alarm before shutdown to prevent unintended wakeups";
    homepage = "https://wiki.postmarketos.org/wiki/Shutdown-clear-rtc-wakealarm";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
