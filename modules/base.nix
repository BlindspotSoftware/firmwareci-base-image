{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.firmwareci.base;
  amdDebugCfg = config.firmwareci.amdDebug;

  chipsec = pkgs.callPackage ../pkgs/chipsec/default.nix {
    kernel = config.boot.kernelPackages.kernel;
    withDriver = true;
  };

  amd-debug-tools = pkgs.python3Packages.callPackage ../pkgs/amd-debug-tools/default.nix { };

  s0ix-selftest-tool = pkgs.callPackage ../pkgs/s0ix-selftest-tool/default.nix {
    linuxPackages = config.boot.kernelPackages;
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
      description = "Include chipsec with kernel module (uses the system kernel)";
    };
    includeDefaultTools = mkOption {
      type = types.bool;
      default = true;
      description = "Include the default tools package in the image.";
    };
  };

  options.firmwareci.amdDebug = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable AMD debug tools (amd-s2idle, amd-bios, amd-pstate, amd-ttm) with ethtool and edid-decode.";
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
      config.boot.kernelPackages.turbostat
      stress-ng
      sysbench
      bc
      powertop
    ]
    ++ [ s0ix-selftest-tool ]
    ++ lib.optional cfg.includeChipSec chipsec
    ++ lib.optional cfg.includeDefaultTools (pkgs.callPackage ../pkgs/default-tools/default.nix { })
    ++ lib.optionals amdDebugCfg.enable [
      amd-debug-tools
      ethtool
      edid-decode
    ];

    hardware.enableAllFirmware = cfg.enableAllFirmware;

    services = {
      openssh = mkIf (cfg.sshAccess.user != "" && cfg.sshAccess.key != "") {
        enable = true;
        settings.PermitRootLogin = if cfg.sshAccess.user == "root" then "yes" else "no";
      };

      fwupd = mkIf cfg.enableFwupd {
        enable = true;
        daemonSettings = lib.mkForce {
          EspLocation = "/boot/EFI";
        };
      };

      # Enable D-Bus system daemon for AMD debug tools
      dbus.enable = mkIf amdDebugCfg.enable true;
    };

    users.users.${cfg.sshAccess.user} = mkIf (cfg.sshAccess.user != "" && cfg.sshAccess.key != "") {
      openssh.authorizedKeys.keys = [ cfg.sshAccess.key ];
    };
  };
}
