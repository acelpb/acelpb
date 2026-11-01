{ config, lib, pkgs, ... }:
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
      packages = [ pkgs.stdenv pkgs.git pkgs.jdk11 config.programs.ssh.package pkgs.nix pkgs.podman ];
      # jobBuilder = {
      #   enable = true;
      #   yamlJobs = ''
      #     - job:
      #         name: jenkins-job-test-1
      #         builders:
      #           - shell: echo 'Hello world!'

      #   '';
      # };
    };



    services.nginx.virtualHosts = {
      "jenkins.acelpb.com" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            proxyPass = "http://localhost:${toString 2711}";
            # extraConfig = ''
            #   sendfile off;
            #   proxy_redirect     default;
            #   proxy_redirect     http://          https://;
            #   proxy_set_header   Host              $host;
            #   proxy_set_header   X-Real-IP         $remote_addr;
            #   proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
            #   proxy_set_header   X-Forwarded-Proto $scheme;
            #   proxy_set_header   Upgrade           $http_upgrade;
            #   proxy_set_header   Connection        "Upgrade";
            #   proxy_max_temp_file_size 0;
            #   #this is the maximum upload size
            #   client_max_body_size       10m;
            #   client_body_buffer_size    128k;
            #   proxy_connect_timeout      90;
            #   proxy_send_timeout         90;
            #   proxy_read_timeout         90;
            #   proxy_buffer_size          4k;
            #   proxy_buffers              4 32k;
            #   proxy_busy_buffers_size    64k;
            #   proxy_temp_file_write_size 64k;
            # '';
          };
        };
      };
    };
  };
}
