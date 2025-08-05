# FirmwareCI job dependencies
{ config, lib, pkgs, ... }:

let
  defaultTools = pkgs.callPackage ../pkgs/default-tools/default.nix { };
in
{
  environment.systemPackages = [ defaultTools ];

  system.activationScripts.copyDefaultTools = {
    deps = [ ];
    text = ''
      mkdir -p /root

      cp -r ${defaultTools}/default-tools /root/
    '';
  };
}
