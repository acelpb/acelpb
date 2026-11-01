{ config, lib, pkgs, ... }:
{
  config = {
    services.immich = {
      enable = true;
    };

    services.nginx.virtualHosts."immich.acelpb.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://[::1]:${toString config.services.immich.port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        extraConfig = ''
          client_max_body_size 50000M;
          proxy_read_timeout   600s;
          proxy_send_timeout   600s;
          send_timeout         600s;
        '';
      };
    };

  users.users.immich.extraGroups = [ "video" "render" ];
  };
}
