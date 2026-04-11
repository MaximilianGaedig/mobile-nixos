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
  cfg = config.mobile.boot.stage-1.leds;
in
{
  options.mobile.boot.stage-1.leds = {
    enable = mkEnableOption "LED feedback for boot errors" // {
      default = false;
    };
  };

  config = mkIf (config.mobile.boot.stage-1.enable && cfg.enable) {
    mobile.boot.stage-1 = {
      # Add LED control library
      contents = [
        {
          object = pkgs.writeText "leds.rb" ''
            class LEDs
              LED_PATH = "/sys/class/leds"

              def self.available_leds
                return [] unless File.directory?(LED_PATH)
                Dir.entries(LED_PATH).reject { |e| e.start_with?(".") }
              end

              def self.blink_pattern(pattern:, duration: 5000)
                leds = available_leds
                return if leds.empty?

                leds.each do |led|
                  set_led_blink(led, pattern, duration)
                end
              end

              def self.set_led_blink(led, pattern, duration)
                led_path = File.join(LED_PATH, led)
                return unless File.directory?(led_path)

                # Set brightness
                brightness_file = File.join(led_path, "brightness")
                max_brightness_file = File.join(led_path, "max_brightness")

                return unless File.exist?(brightness_file)

                max_brightness = 255
                if File.exist?(max_brightness_file)
                  max_brightness = File.read(max_brightness_file).to_i
                end

                # Pattern: on_ms, off_ms
                pattern.each do |on_ms, off_ms|
                  File.write(brightness_file, max_brightness.to_s)
                  sleep(on_ms / 1000.0)
                  File.write(brightness_file, "0")
                  sleep(off_ms / 1000.0)
                end
              rescue => e
                $logger.debug "LED control failed for #{led}: #{e}" if defined?($logger)
              end

              # Predefined patterns
              def self.error_mount_failure
                # Yellow screen equivalent - slow blink
                blink_pattern(pattern: [[500, 500], [500, 500]], duration: 5000)
              end

              def self.error_no_generation
                # Fuchsia screen equivalent - fast blink
                blink_pattern(pattern: [[200, 200], [200, 200], [200, 200]], duration: 5000)
              end

              def self.error_exec_failure
                # Red screen equivalent - rapid blink
                blink_pattern(pattern: [[100, 100], [100, 100], [100, 100], [100, 100]], duration: 5000)
              end

              def self.error_dependency_hung
                # Black screen equivalent - single long blink
                blink_pattern(pattern: [[2000, 500]], duration: 5000)
              end

              def self.error_uncontrolled_abort
                # Brown screen equivalent - double blink
                blink_pattern(pattern: [[300, 300], [300, 300]], duration: 5000)
              end
            end
          '';
          symlink = "/lib/leds.rb";
        }
      ];
    };
  };
}
