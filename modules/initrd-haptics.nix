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
  cfg = config.mobile.boot.stage-1.haptics;
in
{
  options.mobile.boot.stage-1.haptics = {
    enable = mkEnableOption "haptic feedback for boot errors" // {
      default = false;
    };
  };

  config = mkIf (config.mobile.boot.stage-1.enable && cfg.enable) {
    mobile.boot.stage-1 = {
      kernel.modules = [
        "qcom_spmi_haptics"
      ];

      # Add haptic control library
      contents = [
        {
          object = pkgs.writeText "haptics.rb" ''
            class Haptics
              VIBRATOR_PATH = "/sys/class/timed_output/vibrator"

              def self.available?
                File.directory?(VIBRATOR_PATH)
              end

              def self.vibrate(duration_ms: 500)
                return unless available?

                enable_file = File.join(VIBRATOR_PATH, "enable")
                return unless File.exist?(enable_file)

                File.write(enable_file, duration_ms.to_s)
              rescue => e
                $logger.debug "Haptic feedback failed: #{e}" if defined?($logger)
              end

              def self.pattern(pattern)
                return unless available?

                pattern.each do |duration_ms, delay_ms|
                  vibrate(duration_ms: duration_ms)
                  sleep(delay_ms / 1000.0) if delay_ms > 0
                end
              end

              # Predefined patterns matching error colors
              def self.error_mount_failure
                # Match yellow screen - two medium vibrations
                pattern([[500, 200], [500, 0]])
              end

              def self.error_no_generation
                # Match fuchsia screen - three short vibrations
                pattern([[200, 100], [200, 100], [200, 0]])
              end

              def self.error_exec_failure
                # Match red screen - rapid vibrations
                pattern([[100, 50], [100, 50], [100, 50], [100, 50], [100, 0]])
              end

              def self.error_dependency_hung
                # Match black screen - one long vibration
                vibrate(duration_ms: 2000)
              end

              def self.error_uncontrolled_abort
                # Match brown screen - double vibration
                pattern([[300, 100], [300, 0]])
              end
            end
          '';
          symlink = "/lib/haptics.rb";
        }
      ];
    };
  };
}
