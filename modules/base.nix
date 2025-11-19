{ config, lib, pkgs, ... }:

let
  cfg = config.firmwareci.base;
  amdDebugCfg = config.firmwareci.amdDebug;
  hasSshAccess = cfg.sshAccess.user != "" && cfg.sshAccess.key != "";
in
{
  options.firmwareci.base = {
    sshAccess = {
      user = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SSH user for access.";
      };
      key = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SSH public key for access.";
      };
    };

    enableFwupd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable fwupd service.";
    };
    enableAllFirmware = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable all firmware blobs.";
    };
    allowBroken = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow installation of broken packages.";
    };
    allowUnfree = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow installation of unfree packages.";
    };
    includeChipSec = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include chipsec with kernel module (uses the system kernel).";
    };
    includeDefaultTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the default tools package in the image.";
    };
  };

  options.firmwareci.amdDebug = {
    enable = lib.mkEnableOption "AMD debug tools (amd-s2idle, amd-bios, amd-pstate, amd-ttm) with ethtool and edid-decode";
  };

  config = lib.mkMerge [
    {
      boot.loader = {
        efi.canTouchEfiVariables = false;
        grub.enable = false;
        systemd-boot.enable = true;
      };

      nixpkgs.config = {
        allowBroken = lib.mkDefault cfg.allowBroken;
        allowUnfree = lib.mkDefault cfg.allowUnfree;
      };

      environment.systemPackages = with pkgs; [
        acpica-tools
        dmidecode
        fwts
        sbctl
        config.boot.kernelPackages.turbostat
        stress-ng
        sysbench
        bc
        powertop
        (callPackage ../pkgs/s0ix-selftest-tool/default.nix {
          linuxPackages = config.boot.kernelPackages;
        })
      ];

      hardware.enableAllFirmware = cfg.enableAllFirmware;
    }

    # SSH access configuration
    (lib.mkIf hasSshAccess {
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = if cfg.sshAccess.user == "root" then "yes" else "no";
      };
      users.users.${cfg.sshAccess.user}.openssh.authorizedKeys.keys = [ cfg.sshAccess.key ];
    })

    # fwupd service
    (lib.mkIf cfg.enableFwupd {
      services.fwupd = {
        enable = true;
        daemonSettings = lib.mkForce {
          EspLocation = "/boot/EFI";
        };
      };
    })

    # ChipSec tools
    (lib.mkIf cfg.includeChipSec {
      environment.systemPackages = [
        (pkgs.callPackage ../pkgs/chipsec/default.nix {
          kernel = config.boot.kernelPackages.kernel;
          withDriver = true;
        })
      ];
    })

    # Default tools
    (lib.mkIf cfg.includeDefaultTools (
      let
        defaultTools = pkgs.callPackage ../pkgs/default-tools/default.nix { };
      in
      {
        environment.systemPackages = [ defaultTools ];
        system.activationScripts.copyDefaultTools.text = ''
          mkdir -p /root
          cp -r ${defaultTools}/default-tools /root/
        '';
      }
    ))

    # AMD debug tools
    (lib.mkIf amdDebugCfg.enable {
      environment.systemPackages = [
        (pkgs.python3Packages.callPackage ../pkgs/amd-debug-tools/default.nix { })
        pkgs.ethtool
        pkgs.edid-decode
      ];
    })
  ];
}
