# Testing configuration - qemu with cryptsetup
{ ... }:

{
  imports = [
    ../../hello/configuration.nix
    ./configuration.nix
  ];
}
