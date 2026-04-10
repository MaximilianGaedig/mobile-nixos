{ lib
, pkgs
, name

# mkbootimg specific values
, kernel
, initrd
, cmdline
, bootimg
, appendDTB
}:

let
  inherit (lib) optionalString;
  inherit (pkgs) buildPackages;
in
pkgs.runCommand name {
  nativeBuildInputs = with buildPackages; [
    e2fsprogs 
  ];
  inherit kernel;
} ''
  PS4=" $ "
  echo Using kernel: $kernel
  (
  set -x
  dd if=/dev/zero of=$out bs=1M count=30 conv=fdatasync status=progress

  mkdir -p img/extlinux
  cp -v $kernel img/vmlinuz
  cp -v ${initrd} img/initramfs
  ${optionalString (appendDTB != null) "cp -v $(dirname ${kernel})/${lib.escapeShellArgs appendDTB} img/dtb"}

  cat<<EOF > img/extlinux/extlinux.conf
  linux /vmlinuz
  initrd /initramfs
  fdt /dtb
  append ${cmdline} 
  EOF

  mkfs.ext2 $out -d img
  rm -rf img
  )
''
