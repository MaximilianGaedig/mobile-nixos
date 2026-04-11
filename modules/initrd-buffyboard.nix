{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  cfg = config.mobile.boot.stage-1.buffyboard;
in
{
  options.mobile.boot.stage-1.buffyboard = {
    enable = mkEnableOption "buffyboard on-screen keyboard in initramfs" // {
      default = false;
    };
  };

  config = mkIf (config.mobile.boot.stage-1.enable && cfg.enable) {
    mobile.boot.stage-1 = {
      extraUtils = [
        { package = pkgs.buffyboard; }
      ];

      tasks = [
        (pkgs.writeText "buffyboard-task.rb" ''
          class Tasks::Buffyboard < SingletonTask
            def initialize()
              add_dependency(:Target, :Graphics)
              add_dependency(:Mount, "/dev")
              add_dependency(:Mount, "/run")
            end

            def run()
              # Spawn buffyboard if no physical keyboard detected
              # or if explicitly requested
              if should_spawn_buffyboard?
                System.spawn("buffyboard")
                $logger.info "Spawned buffyboard on-screen keyboard"
              end
            end

            def should_spawn_buffyboard?()
              # Check if we have a handset/tablet/convertible chassis
              # or if no physical keyboard is present
              chassis = nil
              begin
                chassis = File.read("/sys/class/dmi/id/chassis_type").strip
              rescue
                # If we can't read chassis, assume we need buffyboard
                return true
              end

              # Chassis types that typically don't have physical keyboards:
              # 8 = portable, 9 = laptop, 10 = notebook, 14 = handheld
              # All others probably need on-screen keyboard
              case chassis
              when "3", "4", "5", "6", "7", "8", "9", "10"
                # Desktop, low-profile desktop, pizza box, mini tower, 
                # tower, portable, laptop, notebook - probably have keyboard
                return false
              else
                return true
              end
            end
          end
        '')
      ];

      kernel.modules = [
        "uinput"
      ];
    };
  };
}
