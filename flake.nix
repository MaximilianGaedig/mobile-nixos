{
  description = "Mobile NixOS - NixOS for mobile devices";

  # Revision extracted from npins/sources.json (nixpkgs.url)
  # URL: https://releases.nixos.org/nixos/unstable/nixos-26.05pre940249.00c21e4c93d9/nixexprs.tar.xz
  # inputs.nixpkgs.url = "github:NixOS/nixpkgs/00c21e4c93d9";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      overlay = import ./overlay/overlay.nix;

      # Get all devices from the devices/ directory
      all-devices = builtins.filter (d: builtins.pathExists (./. + "/devices/${d}/default.nix")) (
        builtins.attrNames (builtins.readDir ./devices)
      );

      # Get all examples from the examples/ directory
      all-examples = builtins.filter (e: builtins.pathExists (./. + "/examples/${e}/default.nix")) (
        builtins.attrNames (builtins.readDir ./examples)
      );

      # Helper to get pkgs with overlay applied
      makePkgs = system: nixpkgs.legacyPackages.${system}.appendOverlays [ overlay ];

      # Help text
      helpText = ''
        Mobile NixOS - Build system for mobile devices

        Usage:
          nix build .#packages.devices.<device>     Build device image
          nix build .#packages.examples.<example>.<device>  Build example system
          nix develop                              Enter development shell
          nix build .#packages.help                Show this help

        Available devices: ${builtins.concatStringsSep ", " all-devices}
        Available examples: ${builtins.concatStringsSep ", " all-examples}

        Example:
          nix build .#packages.devices.pine64-pinephone
      '';

      # Overlay packages - we need to evaluate for multiple systems
      overlayPkgsX86 = nixpkgs.legacyPackages.x86_64-linux.appendOverlays [ overlay ];
      overlayPkgsAarch64 = nixpkgs.legacyPackages.aarch64-linux.appendOverlays [ overlay ];
    in
    {
      # Expose overlay for external use
      overlays.default = overlay;

      # Default package shows help
      defaultPackage = nixpkgs.legacyPackages.x86_64-linux.writeText "mobile-nixos-help" helpText;

      packages =
        let
          pkgs = overlayPkgsX86;
        in
        pkgs
        // {
          help = nixpkgs.legacyPackages.x86_64-linux.writeText "mobile-nixos-help" helpText;

          devices = builtins.listToAttrs (
            builtins.map (device: {
              name = device;
              value =
                (import ./lib/eval-with-configuration.nix {
                  pkgs = makePkgs "aarch64-linux";
                  device = device;
                  configuration = [ ];
                }).outputs.default;
            }) all-devices
          );

          examples = builtins.listToAttrs (
            builtins.map (example: {
              name = example;
              value = builtins.listToAttrs (
                builtins.map (device: {
                  name = device;
                  value =
                    (import ./lib/eval-with-configuration.nix {
                      pkgs = makePkgs "aarch64-linux";
                      device = device;
                      configuration = [ (import ./examples/${example}) ];
                    }).outputs.toplevel;
                }) all-devices
              );
            }) all-examples
          );
        };

      # Dev shells for each system
      devShells = {
        x86_64-linux = import ./shell.nix {
          pkgs = makePkgs "x86_64-linux";
        };

        aarch64-linux = import ./shell.nix {
          pkgs = makePkgs "aarch64-linux";
        };

        armv7l-linux = import ./shell.nix {
          pkgs = makePkgs "armv7l-linux";
        };
      };
    };
}
