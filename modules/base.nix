{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.firmwareci.base;

  chipsecKernelVersion = "6.12.36";
  kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_12.override {
    argsOverride = rec {
      kernelPatches = [ ];
      version = chipsecKernelVersion;
      modDirVersion = chipsecKernelVersion;
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
        sha256 = "sha256-ShaK7S3lqBqt2QuisVOGCpjZm/w0ZRk24X8Y5U8Buow=";
      };
    };
  });

  chipsec = pkgs.callPackage ../pkgs/chipsec/default.nix {
    kernel = kernelPackages.kernel;
    withDriver = true;
  };

in
{
  options.firmwareci.base = {
    sshAccess = {
      user = mkOption {
        type = types.str;
        default = "";
        description = "SSH user for access.";
      };
      key = mkOption {
        type = types.str;
        default = "";
        description = "SSH public key for access.";
      };
    };
    enableFwupd = mkOption {
      type = types.bool;
      default = true;
      description = "Enable fwupd service.";
    };
    enableAllFirmware = mkOption {
      type = types.bool;
      default = true;
      description = "Enable all firmware blobs.";
    };
    allowBroken = mkOption {
      type = types.bool;
      default = true;
      description = "Allow installation of broken packages.";
    };
    allowUnfree = mkOption {
      type = types.bool;
      default = true;
      description = "Allow installation of unfree packages.";
    };
    includeChipSec = mkOption {
      type = types.bool;
      default = false;
      description = "Include chipsec with kernel module (only works with kernel <= 6.12)";
    };
    includeDefaultTools = mkOption {
      type = types.bool;
      default = true;
      description = "Include the default tools package in the image.";
    };

  };

  config = {
    boot.loader = {
      efi = {
        canTouchEfiVariables = false;
      };
      grub.enable = false;
      systemd-boot.enable = true;
    };

    nixpkgs.config = {
      allowBroken = mkDefault cfg.allowBroken;
      allowUnfree = mkDefault cfg.allowUnfree;
    };


    environment.systemPackages = with pkgs; [
      # FirmwareCI tools
      acpica-tools
      dmidecode
      fwts
      sbctl
      s0ix-selftest-tool
      config.boot.kernelPackages.turbostat
      stress-ng
      sysbench
      bc
      powertop
    ]
    ++ lib.optional cfg.includeChipSec chipsec
    ++ lib.optional cfg.includeDefaultTools (pkgs.callPackage ../pkgs/default-tools/default.nix { });

    hardware.enableAllFirmware = cfg.enableAllFirmware;

    services.openssh = mkIf (cfg.sshAccess.user != "" && cfg.sshAccess.key != "") {
      enable = true;
      settings.PermitRootLogin = if cfg.sshAccess.user == "root" then "yes" else "no";
    };

    users.users.${cfg.sshAccess.user} = mkIf (cfg.sshAccess.user != "" && cfg.sshAccess.key != "") {
      openssh.authorizedKeys.keys = [ cfg.sshAccess.key ];
    };

    services.fwupd = mkIf cfg.enableFwupd {
      enable = true;
      daemonSettings = lib.mkForce {
        EspLocation = "/boot/EFI";
      };
    };
  };
}
