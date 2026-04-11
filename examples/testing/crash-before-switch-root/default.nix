# Testing configuration - crashes before switch root
{ ... }:

{
  imports = [
    ../../hello/configuration.nix
    ./configuration.nix
  ];
}
