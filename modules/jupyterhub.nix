{ config, lib, pkgs, ... }:
{
  config = {
    services.jupyterhub = {
      enable = true;
      spawner = "systemdspawner.SystemdSpawner";
      authentication = "oauthenticator.github.GitHubOAuthenticator";
      host = "0.0.0.0";
      port = 8888;
      jupyterhubEnv = pkgs.python3.withPackages (p: with p; [
        jupyterhub
        jupyterhub-systemdspawner
        oauthenticator
      ]);
      extraConfig = ''
        c.SystemdSpawner.dynamic_users = True
        c.SystemdSpawner.cmd = "${pkgs.openvscode-server}/bin/openvscode-server"
        c.SystemdSpawner.args = ["--auth=none", '--disable-telemetry', '--bind-addr=127.0.0.1:{port}']
        c.SystemdSpawner.default_url = '/'
      '';
    };

    services.nginx.virtualHosts."jupyter.acelpb.com" = {
      forceSSL = true;
      enableACME = true;
      extraConfig = ''
        location / {
          proxy_pass http://localhost:8888;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header Host $host;
          proxy_http_version 1.1;
          proxy_redirect off;
          proxy_buffering off;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_read_timeout 86400;
        }
      '';
    };
  };
}
