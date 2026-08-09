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
    mkOption
    types
    ;

  cfg = config.services.alertSlider;

  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);

  alertSliderWatcher = pkgs.writeText "alert-slider-watcher.py" ''
    #!${python}/bin/python
    import asyncio
    import glob
    import os
    import shlex
    import subprocess
    import tomllib

    from evdev import InputDevice, ecodes


    DEVICE_NAME = os.environ.get("DEVICE_NAME", "Alert slider")
    CONFIG_FILE = os.environ.get("CONFIG_FILE", "/etc/hkdm/fbcli.toml")


    def load_events():
        try:
            with open(CONFIG_FILE, "rb") as handle:
                data = tomllib.load(handle)
        except FileNotFoundError:
            print(f"config not found: {CONFIG_FILE}")
            return []

        events = []
        for event in data.get("events", []):
            keys = event.get("keys", [])
            if "ABS" not in keys and "SW" not in keys:
                continue
            key_state = str(event.get("key_state", ""))
            command = event.get("command", "")
            if not key_state or not command:
                continue
            events.append((key_state, command))
        return events


    def run_command(command):
        try:
            subprocess.run(shlex.split(command), check=False)
        except Exception as exc:
            print(f"failed to run {command!r}: {exc}")


    async def watch_device(path, events):
        try:
            device = InputDevice(path)
        except Exception:
            return

        try:
            if device.name != DEVICE_NAME:
                return

            last_value = None
            async for event in device.async_read_loop():
                if event.type not in (ecodes.EV_ABS, ecodes.EV_SW):
                    continue

                value = str(event.value)
                if value == last_value:
                    continue
                last_value = value

                for key_state, command in events:
                    if key_state == value:
                        print(f"{device.name}: state={value} -> {command}")
                        run_command(command)
        finally:
            device.close()


    async def main():
        events = load_events()
        if not events:
            return

        tasks = {}
        while True:
            for path in sorted(glob.glob("/dev/input/event*")):
                if path not in tasks or tasks[path].done():
                    tasks[path] = asyncio.create_task(watch_device(path, events))

            for path, task in list(tasks.items()):
                if task.done():
                    tasks.pop(path, None)

            await asyncio.sleep(5)


    if __name__ == "__main__":
        asyncio.run(main())
  '';
in
{
  options.services.alertSlider = {
    enable = mkEnableOption "alert slider support via feedbackd";

    deviceName = mkOption {
      type = types.str;
      default = "Alert slider";
      description = "Input device name used for the slider.";
    };

    configFile = mkOption {
      type = types.str;
      default = "/etc/hkdm/fbcli.toml";
      description = "TOML file describing slider state actions.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.alert-slider = {
      description = "Alert slider to feedbackd bridge";
      after = [ "systemd-logind.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.feedbackd ];

      serviceConfig = {
        ExecStart = "${python}/bin/python ${alertSliderWatcher}";
        Restart = "always";
        RestartSec = "2s";
      };

      environment = {
        CONFIG_FILE = cfg.configFile;
        DEVICE_NAME = cfg.deviceName;
      };
    };
  };
}
