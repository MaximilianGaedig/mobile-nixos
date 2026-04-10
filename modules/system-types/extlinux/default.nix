{
  config,
  pkgs,
  lib,
  modules,
  baseModules,
  ...
}:

let
  enabled = config.mobile.system.type == "extlinux";

  inherit (config.mobile.outputs) recovery stage-0;
  inherit (pkgs) buildPackages runCommand;
  inherit (lib)
    mkBefore
    mkIf
    mkOption
    types
    ;
  cfg = config.mobile.quirks.extlinux;
  deviceName = config.mobile.device.name;
  kernel = stage-0.mobile.boot.stage-1.kernel.package;
  kernel_file = "${kernel}/${
    if kernel ? file then kernel.file else pkgs.stdenv.hostPlatform.linux-kernel.target
  }";
  boot-partition = config.mobile.generatedFilesystems.boot.output;

  bootcmd = pkgs.writeText "${deviceName}-boot.cmd" ''
    echo ****************
    echo * Mobile NixOS *
    echo ****************
    echo
    echo Built for ${deviceName}
    echo

    # Ensure we don't pick a stray bootargs
    env delete bootargs

    # Add every args one by one, or else it may be too big to fit in a single invocation.
    ${lib.concatMapStringsSep "\n" (
      arg: ''setenv bootargs "$bootargs ${arg}"''
    ) config.boot.kernelParams}

    ${cfg.additionalCommands}

    echo
    echo === debug information ===
    printenv bootargs
    echo
    printenv kernel_addr_r
    printenv fdt_addr_r
    printenv ramdisk_addr_r
    echo devtype = "$devtype"
    echo devnum = "$devnum"
    echo === end of the debug information ===
    echo

    bootpart=""
    echo part number $devtype $devnum boot bootpart
    part number $devtype $devnum boot bootpart
    echo $bootpart

    # To stay compatible with the previous scheme, and more importantly, the
    # default assumptions from extlinux, detect the bootable legacy flag.
    if test "$bootpart" = ""; then
      echo "Could not find a partition with the partlabel 'boot'."
      echo "(looking at partitions marked bootable)"
      part list ''${devtype} ''${devnum} -bootable bootpart
      # This may print out an error message when there is only one result.
      # Though it still is fine.
      setexpr bootpart gsub ' .*' "" "$bootpart"
    fi

    if test "$bootpart" = ""; then
      echo "!!! Could not find 'boot' partition on $devtype $devnum !!!"
      exit
    fi

    echo ":: Booting from partition $bootpart"

    if load ''${devtype} ''${devnum}:''${bootpart} ''${kernel_addr_r} /mobile-nixos/boot/kernel; then
      setenv boot_type boot
    else
      if load ''${devtype} ''${devnum}:''${bootpart} ''${kernel_addr_r} /mobile-nixos/recovery/kernel; then
        setenv boot_type recovery
        setenv bootargs "''${bootargs} is_recovery"
      else
        echo "!!! Failed to load either of the normal and recovery kernels !!!"
        exit
      fi
    fi

    if load ''${devtype} ''${devnum}:''${bootpart} ''${fdt_addr_r} /mobile-nixos/''${boot_type}/dtbs/''${fdtfile}; then
      fdt addr ''${fdt_addr_r}
      fdt resize
    fi

    load ''${devtype} ''${devnum}:''${bootpart} ''${ramdisk_addr_r} /mobile-nixos/''${boot_type}/stage-1
    setenv ramdisk_size ''${filesize}

    echo bootargs: ''${bootargs}
    echo booti ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};

    booti ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
  '';

  bootscr =
    runCommand "${deviceName}-boot.scr"
      {
        nativeBuildInputs = [
          buildPackages.ubootTools
        ];
      }
      ''
        mkimage -C none -A ${
          ubootPlatforms.${pkgs.stdenv.targetPlatform.system}
        } -T script -d ${bootcmd} $out
      '';
in
{
  options.mobile = {
    quirks.extlinux = {
      # Additional extlinux commands to run.
      additionalCommands = mkOption {
        type = types.lines;
        default = "";
      };
    };

    outputs = {
      extlinux = {
        # Boot partition for the system.
        boot-partition = mkOption {
          type = types.package;
          visible = false;
        };
        # disk-image = lib.mkOption {
        #   type = types.package;
        #   description = lib.mdDoc ''
        #     Full Mobile NixOS disk image for a extlinux-based system.
        #   '';
        #   visible = false;
        # };
        # extlinux = mkOption {
        #   type = types.package;
        #   description = lib.mdDoc ''
        #     extlinux build for the system.
        #   '';
        #   visible = false;
        # };
      };
    };
  };

  config = lib.mkMerge [
    { mobile.system.types = [ "extlinux" ]; }
    (mkIf enabled {
      mobile.generatedDiskImages.disk-image = {
        partitions = mkBefore [
          {
            name = "mn-boot";
            partitionLabel = "boot";
            partitionUUID = "CFB21B5C-A580-DE40-940F-B9644B4466E1";
            bootable = true;
            raw = boot-partition;
          }
        ];
      };
      # mobile.generatedFilesystems.boot = {
      #   filesystem = "ext4";
      #   # Let's give us a *bunch* of space to play around.
      #   # And let's not forget we have the kernel and stage-1 twice.
      #   size = pkgs.image-builder.helpers.size.MiB 128;
      #
      #   ext4.partitionID = "ED3902B6-920A-4971-BC07-966D4E021683";
      #   populateCommands = ''
      #     mkdir -vp mobile-nixos/{boot,recovery}
      #     (
      #     cd mobile-nixos/boot
      #     cp -v ${stage-0.mobile.outputs.initrd} stage-1
      #     cp -v ${kernel_file} kernel
      #     cp -vr ${kernel}/dtbs dtbs
      #     )
      #     (
      #     cd mobile-nixos/recovery
      #     cp -v ${recovery.mobile.outputs.initrd} stage-1
      #     cp -v ${kernel_file} kernel
      #     cp -vr ${kernel}/dtbs dtbs
      #     )
      #     cp -v ${bootscr} ./boot.scr
      #   '';
      # };

      mobile.outputs = {
        default = config.mobile.outputs.extlinux.disk-image;
        extlinux = {
          inherit boot-partition;
          disk-image = config.mobile.generatedDiskImages.disk-image.output;
        };
      };
    })
  ];
}
