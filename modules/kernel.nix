{ config, lib, pkgs, ... }:

# FirmwareCI kernel configuration

with lib;

let
  cfg = config.firmwareci.kernel;
in
{
  options.firmwareci.kernel = {
    version = mkOption {
      type = types.str;
      default = "6.15.8";
      description = "Linux kernel version to use";
    };
    sha256 = mkOption {
      type = types.str;
      default = "sha256-036SvBa5YqMCXfFWZHva2QsttP82x6YTeBf+ge8/KKY=";
      description = "sha256 for the kernel tarball";
    };
    extraKernelModules = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra kernel modules to load at boot.";
    };
  };

  config = {
    boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = rec {
        inherit (cfg) version sha256;
        modDirVersion = version;
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
          inherit sha256;
        };
      };
    });

    boot.kernelModules = [
      "msr"
      "intel_rapl_common"
      "intel_pmc_core"
      "intel_lpss"
      "intel_lpss_pci"
      "intel_lpss_acpi"
    ] ++ cfg.extraKernelModules;
  };
}
