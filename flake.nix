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

      # The general base config for reuse
      baseConfig = { config, modulesPath, pkgs, ... }: {
        imports = [
          "${modulesPath}/profiles/base.nix"
          "${modulesPath}/profiles/minimal.nix"
          "${modulesPath}/profiles/all-hardware.nix"
          ./modules/kernel.nix
          ./modules/firmwareci.nix
        ];
        system.stateVersion = "25.05";
        time.timeZone = "Europe/Berlin";
        fileSystems."/" = {
          inherit fsType;
          device = "/dev/disk/by-label/nixos";
        };
        fileSystems."/boot/EFI" = {
          device = "/dev/disk/by-label/ESP";
        };
        firmwareciBase.allowUnfree = true;
        firmwareciBase.allowBroken = true;
      };

      # Example configuration for a test image
      testImageConfig = { config, modulesPath, pkgs, ... }: {
        imports = [
          baseConfig
          # Add your own modules here!
          # ./modules/my-hardware.nix
        ];
        # Example: override some options
        firmwareciBase = {
          extraPackages = [ pkgs.git pkgs.curl ];
          enableSSH = true;
          sshPermitRootLogin = "yes";
        };

        firmwareci.kernel = {
          version = "6.15.8";
          sha256 = "sha256-036SvBa5YqMCXfFWZHva2QsttP82x6YTeBf+ge8/KKY=";
          extraKernelModules = [ "dummy" ];
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
    flake-utils.lib.eachSystem (with flake-utils.lib.system; [ x86_64-linux ])
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          nixosConfigurations = {
            # The base config for users to extend
            firmwareci-base = nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [ baseConfig ];
            };
            # Example: a test image using the base config
            firmwareci-test-image = nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [ testImageConfig ];
            };
          };
        in
        {
          checks = {
            pre-commit-check = pre-commit-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                nixpkgs-fmt.enable = true;
                statix.enable = true;
              };
            };
          };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [ statix ];
            shellHook = ''
              ${self.checks.${system}.pre-commit-check.shellHook}
            '';
          };

          packages = {
            inherit (pkgs) statix nixpkgs-fmt;

            base = generateDiskImage {
              inherit fsType pkgs;
              inherit (nixosConfigurations.firmwareci-base) config;
            };

            test-image = generateDiskImage {
              inherit fsType pkgs;
              inherit (nixosConfigurations.firmwareci-test-image) config;
            };
          };

          defaultPackage = self.packages.${system}.base;
        });
}
