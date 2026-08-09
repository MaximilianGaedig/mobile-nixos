{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mapAttrs'
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    types
    ;

  cfg = config.services.hkdm;
in
{
  options.services.hkdm = {
    enable = mkEnableOption "hkdm hotkey daemon";

    configs = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "hkdm TOML config files under /etc/hkdm";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hkdm = {
      description = "Hotkey daemon";
      after = [ "systemd-logind.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.hkdm}/bin/hkdm -c /etc/hkdm";
        Restart = "always";
      };
    };

    environment.etc = mapAttrs' (name: text: nameValuePair "hkdm/${name}" { inherit text; }) cfg.configs;
  };
}
