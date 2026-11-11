{
  description = "FirmwareCI Test Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
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

        # profiles/base.nix enables ZFS, but the image root is ext4.
        boot.supportedFilesystems.zfs = false;

        # Keep the nixpkgs flake source ("source") out of the system closure.
        nixpkgs.flake = {
          setFlakeRegistry = false;
          setNixPath = false;
        };

        fileSystems = {
          "/" = {
            inherit fsType;
            device = "/dev/disk/by-label/nixos";
          };
          "/boot/EFI" = {
            device = "/dev/disk/by-label/ESP";
            fsType = "vfat";
          };
        };

        firmwareci = {
          base.sshAccess = {
            user = "root";
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcSD9iHnCrJXkSt7aGSnfL0tVHUm+x6/EDr/FchmBfu";
          };
          amdDebug.enable = pkgs.stdenv.hostPlatform.isx86_64;
        };
      };

      generateDiskImage = { config, fsType, pkgs }:
        import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit config fsType pkgs;
          inherit (nixpkgs) lib;
          partitionTableType = "efi";
          additionalSpace = "0";
          copyChannel = false;
        };
    in
    {
      nixosModules = {
        base = import ./modules/base.nix;
        kernel = import ./modules/kernel.nix;
      };

      inherit baseConfig;
    } // flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        nixosConfigurations = {
          base = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [ baseConfig ];
          };
          base-aarch64 = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
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
        } // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          # Image tooling stays aarch64; the VM runs the host's QEMU (TCG), and vmTools sets -m and -smp (from nix --cores).
          base-aarch64 = generateDiskImage {
            inherit fsType;
            pkgs = nixpkgs.legacyPackages.aarch64-linux.extend (_final: prev: {
              vmTools = prev.vmTools.override {
                customQemu = "${pkgs.qemu}/bin/qemu-system-aarch64 -machine virt -cpu cortex-a53 --accel tcg,thread=multi";
              };
            });
            inherit (nixosConfigurations.base-aarch64) config;
          };
        };
      });
}
