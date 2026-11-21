{ pkgs, ... }:
{
  imports = [
    ./distant-secret.nix
    ./hardware-configuration.nix
    ./modules/backup.nix
    ./modules/normandy.nix
    ./modules/annechristinefunk.nix
    ./modules/jenkins.nix
    ./modules/dyn_signup.nix
    ./modules/mail.nix
    ./modules/nextcloud.nix
    # ./modules/minecraft.nix
    ./modules/postgres.nix
  ];

  networking.firewall.allowPing = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22 # SSH
    25 # smtp
    80 # HTTP
    143 # mail recieve
    443 # HTTPS
    587 # mail send
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "vps-0ce22064";
  networking.domain = "vps.ovh.net";
  services.openssh.enable = true;
  system.stateVersion = "23.11";

  i18n = {
    defaultLocale = "fr_BE.UTF-8";
  };
  time.timeZone = "Europe/Brussels";

  environment.systemPackages = with pkgs; [
    sudo
    git
    vim
  ];

  security.acme.defaults.email = "a.borsu@gmail.com";
  security.acme.acceptTerms = true;

  services.nginx = {
    enable = true;
    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  security.polkit.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
    };
  };
}
