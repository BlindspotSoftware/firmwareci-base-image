{ config, lib, pkgs, ... }:

let
  cfg = config.firmwareci.kernel;
in
{
  options.firmwareci.kernel = {
    version = lib.mkOption {
      type = lib.types.str;
      default = "6.12.58";
      description = "Linux kernel version to use.";
    };

    sha256 = lib.mkOption {
      type = lib.types.str;
      default = "sha256-XxxMVGZgpqgQRv36YZUwa60sjRfA1ph23BAKha1GE6w=";
      description = "SHA256 hash for the kernel tarball.";
    };

    extraKernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra kernel modules to load at boot.";
    };

    includeIntelModules = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Intel-specific kernel modules (rapl, pmc, lpss).";
    };

    kernelPatches = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "List of kernel patches to apply. Each patch should have 'name' and 'patch' attributes.";
      example = lib.literalExpression ''[
        {
          name = "my-patch";
          patch = ./my-patch.patch;
        }
      ]'';
    };
  };

  config = {
    boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        inherit (cfg) version;
        modDirVersion = version;
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
          sha256 = cfg.sha256;
        };
        kernelPatches = cfg.kernelPatches;
        ignoreConfigErrors = true;
        structuredExtraConfig = with lib.kernel; {
          # Disable /dev/mem restrictions for firmware testing
          STRICT_DEVMEM = no;
          IO_STRICT_DEVMEM = no;
        };
      };
    });

    boot.kernelModules = lib.mkMerge [
      [ "msr" ]
      (lib.mkIf cfg.includeIntelModules [
        "intel_rapl_common"
        "intel_pmc_core"
        "intel_lpss"
        "intel_lpss_pci"
        "intel_lpss_acpi"
      ])
      cfg.extraKernelModules
    ];
  };
}
