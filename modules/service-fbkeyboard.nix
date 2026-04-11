{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.services.fbkeyboard = {
    enable = lib.mkEnableOption "fbkeyboard on-screen keyboard for TTY";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fbkeyboard;
      description = "The fbkeyboard package to use";
    };

    tty = lib.mkOption {
      type = lib.types.str;
      default = "tty1";
      description = "Which TTY to run fbkeyboard on";
    };
  };

  config = lib.mkIf config.services.fbkeyboard.enable {
    environment.systemPackages = [ config.services.fbkeyboard.package ];

    systemd.services.fbkeyboard = {
      description = "Framebuffer Keyboard";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${config.services.fbkeyboard.package}/bin/fbkeyboard";
        Restart = "always";
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
    };
  };
}
