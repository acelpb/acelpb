{ config, lib, pkgs, ... }:
{
  # IP settings
  networking.interfaces.enp3s0 = {
    ipv4.addresses = [
      {
        address = "91.121.89.48";
        prefixLength = 24;
      }
    ];
    ipv6.addresses = [
      {
        address = "2001:41D0:1:8E30::";
        prefixLength = 64;
      }
    ];
  };

  networking.defaultGateway = "91.121.89.254";
  networking.defaultGateway6 = "2001:41D0:1:8Eff:ff:ff:ff:ff";
  networking.nameservers = [ "213.186.33.99" ];

  boot.extraModulePackages = [ ];
  boot.initrd.availableKernelModules = [ "xhci_hcd" "ahci" ];
  boot.kernelModules = [ "kvm-intel" ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda";

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/a5a09dc5-4c9d-4f60-9af5-5741ccd10a81";
      fsType = "ext4";
    };

  fileSystems."/var" =
    { device = "/dev/disk/by-uuid/0f9776ab-15c9-4f8f-8176-e63eef8bef77";
      fsType = "ext4";
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/e6653178-294b-4601-b4a0-7903724b54b8";
      fsType = "ext4";
    };

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 8;
  powerManagement.cpuFreqGovernor = "powersave";
}
