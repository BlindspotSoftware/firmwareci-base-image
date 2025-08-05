{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.firmwareciBase;
in
{
  options.firmwareciBase = {
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages to install in the image.";
    };
    enableSSH = mkOption {
      type = types.bool;
      default = false;
      description = "Enable SSH service.";
    };
    sshPermitRootLogin = mkOption {
      type = types.str;
      default = "no";
      description = "PermitRootLogin setting for SSH.";
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
      default = false;
      description = "Allow installation of broken packages.";
    };
    allowUnfree = mkOption {
      type = types.bool;
      default = false;
      description = "Allow installation of unfree packages.";
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
    ] ++ cfg.extraPackages;

    hardware.enableAllFirmware = cfg.enableAllFirmware;

    services.openssh = mkIf cfg.enableSSH {
      enable = true;
      settings.PermitRootLogin = cfg.sshPermitRootLogin;
    };

    services.fwupd = mkIf cfg.enableFwupd {
      enable = true;
      daemonSettings = lib.mkForce {
        EspLocation = "/boot/EFI";
      };
    };
  };
}
