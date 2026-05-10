{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mobile.quirks.qualcomm.sdm845-audio;
  inherit (lib) mkIf mkOption types;

  callAudioWorkaround = pkgs.writeScriptBin "call-audio-idle-suspend-workaround" ''
    #!${pkgs.runtimeShell}

    # dbus-monitor is run as a child process to this script. Kill child process too when the script terminates.
    trap '${pkgs.procps}/bin/pkill -9 -P $$ && exit 0' INT TERM

    interface=org.freedesktop.ModemManager1.Call
    member=StateChanged

    ${pkgs.dbus}/bin/dbus-monitor --system "type='signal',interface='$interface',member='$member'" |
      while read -r line; do
        state=$(echo "$line" | ${pkgs.gawk}/bin/awk '/\<int32\>/ {print $2}')
        if [ -n "$state" ]; then
          # Call State is based on https://www.freedesktop.org/software/ModemManager/doc/latest/ModemManager/ModemManager-Flags-and-Enumerations.html#MMCallState
          if [ "$state" -eq '0' ] || [ "$state" -eq '3' ]; then
            echo "Call Started"

            # Unload module-suspend-on-idle when call begins
            ${pkgs.procps}/bin/pidof pulseaudio && ${pkgs.pulseaudio}/bin/pactl unload-module module-suspend-on-idle

            # With Wireplumber audio, the Pulseaudio
            # compatibility layer doesn't support
            # loading/unloading the suspend module. Add
            # loopback sinks and sources instead.
            sleep 1
            ${pkgs.pipewire}/bin/pw-loopback -m '[FL FR]' --capture-props='media.class=Audio/Sink' &
            ${pkgs.pipewire}/bin/pw-loopback -m '[FL FR]' --playback-props='media.class=Audio/Source' &
          fi

          if [ "$state" -eq '7' ]; then
            echo "Call Ended"
            ${pkgs.psmisc}/bin/killall -9 pw-loopback &

            # Reload module-suspend-on-idle after call ends
            ${pkgs.procps}/bin/pidof pulseaudio && ${pkgs.pulseaudio}/bin/pactl load-module module-suspend-on-idle
          fi
        fi
      done &

    wait
  '';
in
{
  options.mobile.quirks.qualcomm.sdm845-audio = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable audio quirks for SDM845 devices
        Includes q6voiced for modem audio and hexagonrpc for DSP
      '';
    };
    q6voiced = {
      card = mkOption {
        type = types.int;
        default = 0;
        description = "ALSA card number for q6voiced";
      };
      device = mkOption {
        type = types.int;
        default = 6;
        description = "ALSA device number for q6voiced";
      };
    };
    hexagonrpc-fw-dir = mkOption {
      type = types.path;
      default = "/usr/share/qcom/sdm845/OnePlus/oneplus6";
      description = "Firmware directory for hexagonrpcd";
    };
    enableCallAudioWorkaround = mkOption {
      type = types.bool;
      default = true;
      description = "Enable workaround to prevent audio suspension during calls";
    };
  };

  config = mkIf cfg.enable {
    systemd.services = {
      hexagonrpcd-adsp = {
        description = "Hexagon DSP daemon for ADSP (Audio DSP)";
        wantedBy = [ "multi-user.target" ];
        bindsTo = [ "dev-fastrpc\\x2dadsp.device" ];
        after = [
          "dev-fastrpc\\x2dadsp.device"
          "remote-fs.target"
        ];
        serviceConfig = {
          ExecStart = "${pkgs.hexagonrpc}/bin/hexagonrpcd -f /dev/fastrpc-adsp -s -R ${cfg.hexagonrpc-fw-dir}";
          Restart = "always";
          RestartSec = "5";
        };
      };

      q6voiced = mkIf (pkgs ? q6voiced) {
        description = "Enable q6voice audio when call is performed with ModemManager";
        wantedBy = [ "multi-user.target" ];
        after = [
          "ModemManager.service"
          "dbus.service"
        ];
        requires = [ "dbus.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.q6voiced}/bin/q6voiced hw:${toString cfg.q6voiced.card},${toString cfg.q6voiced.device}";
          Restart = "always";
        };
      };

    };

    systemd.user.services = {
      call-audio-idle-suspend-workaround = mkIf cfg.enableCallAudioWorkaround {
        description = "Prevent audio suspension during phone calls";
        wantedBy = [ "default.target" ];
        after = [
          "ModemManager.service"
          "pipewire.service"
          "wireplumber.service"
        ];
        serviceConfig = {
          ExecStart = "${callAudioWorkaround}/bin/call-audio-idle-suspend-workaround";
          Restart = "always";
          RestartSec = "5";
        };
      };
    };

    environment.etc."wireplumber/wireplumber.conf.d/51-qcom-sdm845.conf".text = ''
      monitor.alsa.rules = [
        {
          matches = [
            {
              # Matches all sources
              node.name = "~alsa_input.*"
            },
            {
              # Matches all sinks
              node.name = "~alsa_output.*"
            }
          ]
          actions = {
            update-props = {
              audio.format           = "S16LE"
              audio.rate             = 48000
              api.alsa.period-size   = 4096
              api.alsa.period-num    = 6
              api.alsa.headroom      = 512,
             # session.suspend-timeout-seconds = 0
             # dither.method = "wannamaker3", # add dither of desired shape
             # dither.noise = 2, # add additional bits of noise
            }
          }
        }
      ]
    '';
  };
}
