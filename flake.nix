{
  description = "FirmwareCI Test Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = { self, flake-utils, nixpkgs, pre-commit-hooks, ... }:
    let
      fsType = "ext4";

      baseConfig = { config, modulesPath, pkgs, ... }: {
        imports = [
          "${modulesPath}/profiles/base.nix"
          "${modulesPath}/profiles/minimal.nix"
          "${modulesPath}/profiles/all-hardware.nix"
          ./modules/base.nix
          ./modules/kernel.nix
        ];

        system.stateVersion = "25.05";
        time.timeZone = "Europe/Berlin";

        fileSystems = {
          "/" = {
            inherit fsType;
            device = "/dev/disk/by-label/nixos";
          };
          "/boot/EFI".device = "/dev/disk/by-label/ESP";
        };

        firmwareci = {
          base.sshAccess = {
            user = "root";
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcSD9iHnCrJXkSt7aGSnfL0tVHUm+x6/EDr/FchmBfu";
          };
          amdDebug.enable = true;
        };
      };

      generateDiskImage = { config, fsType, pkgs }:
        import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit config fsType pkgs;
          inherit (nixpkgs) lib;
          partitionTableType = "efi";
          additionalSpace = "0";
        };
    in
    {
      nixosModules = {
        base = import ./modules/base.nix;
        kernel = import ./modules/kernel.nix;
      };

      inherit baseConfig;
    } // flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        nixosConfigurations = {
          base = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [ baseConfig ];
          };
        };
      in
      {
        checks.pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            statix.enable = true;
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [ pkgs.statix ];
          shellHook = self.checks.${system}.pre-commit-check.shellHook;
        };

        packages = {
          inherit (pkgs) statix nixpkgs-fmt;

          base = generateDiskImage {
            inherit fsType pkgs;
            inherit (nixosConfigurations.base) config;
          };

          default = self.packages.${system}.base;
        };
      });
}
