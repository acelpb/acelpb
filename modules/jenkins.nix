{ config, pkgs, ... }:
{
  config = {

    services.dockerRegistry.enable = true;
    services.dockerRegistry.enableDelete = true;
    services.dockerRegistry.listenAddress = "localhost";
    services.dockerRegistry.port = 5000;
    services.dockerRegistry.openFirewall = false;

    virtualisation.containers.registries.insecure = [ "localhost:5000" ];

    virtualisation.podman.enable = true;
    virtualisation.podman.dockerSocket.enable = true;

    users.users.jenkins.extraGroups = [ "podman" ];

    systemd.services.jenkins.environment.CONTAINER_HOST = "unix:///run/podman/podman.sock";

    services.jenkins = {
      enable = true;
      port = 2711;
      listenAddress = "localhost";
      packages = [
        pkgs.stdenv
        pkgs.git
        pkgs.jdk11
        config.programs.ssh.package
        pkgs.nix
        pkgs.podman
      ];

    };

    services.nginx.virtualHosts = {
      "jenkins.acelpb.com" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            proxyPass = "http://localhost:${toString 2711}";
          };
        };
      };
    };
  };
}
