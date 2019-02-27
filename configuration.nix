{ config, lib, pkgs, ... }:
{
  imports =
    [
      <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
      ./acelpb.nix
      ./distant-secret.nix
      ./distant-hardware.nix
    ];

  networking.hostName = "acelpb.com";
  networking.hostId = "385cabe4";
}
