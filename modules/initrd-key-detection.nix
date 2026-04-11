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
  cfg = config.mobile.boot.stage-1.key-detection;
in
{
  options.mobile.boot.stage-1.key-detection = {
    enable = mkEnableOption "key detection for debug shell triggers" // {
      default = false;
    };

    debug-shell-key = lib.mkOption {
      type = lib.types.str;
      default = "volume_down";
      description = ''
        Key that triggers debug shell when held during boot.
        Common values: volume_down, volume_up, left_ctrl, left_shift
      '';
    };
  };

  config = mkIf (config.mobile.boot.stage-1.enable && cfg.enable) {
    mobile.boot.stage-1 = {
      extraUtils = [
        { package = pkgs.iskey; }
      ];

      tasks = [
        (pkgs.writeText "key-detection-task.rb" ''
          class Tasks::KeyDetection < SingletonTask
            def initialize()
              add_dependency(:Target, :Graphics)
              add_dependency(:Mount, "/dev")
              # Run early to catch key presses
            end

            def run()
              check_keys()
            end

            def check_keys()
              debug_key = "${cfg.debug-shell-key}"
              
              # Check for debug shell trigger
              if iskey_pressed?(debug_key) || iskey_pressed?("left_ctrl")
                $logger.info "Debug key detected (${cfg.debug-shell-key} or left_ctrl), spawning debug shell"
                spawn_debug_shell()
              end

              # Check for log dump trigger (volume_up or left_shift)
              if iskey_pressed?("volume_up") || iskey_pressed?("left_shift")
                $logger.info "Log dump key detected, exporting logs"
                export_logs()
              end
            end

            def iskey_pressed?(key)
              result = System.run("iskey", key)
              return result == 0
            rescue => e
              $logger.warn "Failed to check key #{key}: #{e}"
              return false
            end

            def spawn_debug_shell()
              # Signal the shell task to spawn
              FileUtils.touch("/run/.mobile-nixos-debug-shell")
            end

            def export_logs()
              # Create a log dump on USB mass storage
              FileUtils.touch("/run/.mobile-nixos-export-logs")
            end
          end
        '')
      ];
    };
  };
}
