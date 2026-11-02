{
  config,
  pkgs,
  ...
}:
{
  config = {
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud33;

      # Let NixOS install and configure Redis caching automatically.
      configureRedis = true;

      # Increase the maximum file upload size to avoid problems uploading videos.
      maxUploadSize = "5G";

      ##
      # Security
      ########################
      https = true;

      ##
      # Applications
      ########################
      # Apps come from Nix only. Enabling the app store as well makes "occ upgrade"
      # update packaged apps from the store, which crashes with a redeclared class.
      extraAppsEnable = true;
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          calendar
          collectives
          contacts
          groupfolders
          news
          richdocuments
          ;
      };

      ##
      # Database
      ########################
      # Let NixOS install and configure the database automatically.
      database.createLocally = true;
      config = {
        dbtype = "pgsql";
        dbname = "nextcloud";
        dbuser = "nextcloud";
        adminuser = "aborsu";
        adminpassFile = "/etc/nixos/secrets/nextcloud_adminpass";
      };

      ##
      # Settings
      ########################
      settings = {
        log_type = "file";
        default_phone_region = "BE";
      };
    };

    services.nginx.virtualHosts = {
      "cloud.acelpb.com" = {
        enableACME = true;
        forceSSL = true;
      };
      "collabora.acelpb.com" = {
        enableACME = true;
        forceSSL = true;

        extraConfig = ''
            # static files
            location ^~ /browser {
              proxy_pass http://127.0.0.1:9980;
              proxy_set_header Host $host;
            }

            # WOPI discovery URL
            location ^~ /hosting/discovery {
              proxy_pass http://127.0.0.1:9980;
              proxy_set_header Host $host;
            }

            # Capabilities
            location ^~ /hosting/capabilities {
              proxy_pass http://127.0.0.1:9980;
              proxy_set_header Host $host;
          }

          # main websocket
          location ~ ^/cool/(.*)/ws$ {
            proxy_pass http://127.0.0.1:9980;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 36000s;
          }

          # download, presentation and image upload
          location ~ ^/(c|l)ool {
            proxy_pass http://127.0.0.1:9980;
            proxy_set_header Host $host;
          }

          # Admin Console websocket
          # Not exposed publicly: use an SSH tunnel to 127.0.0.1:9980 instead.
          location ^~ /cool/adminws {
            return 403;
          }
        '';
      };

    };

    #Collabora Containers
    virtualisation.oci-containers.containers.collabora = {
      image = "docker.io/collabora/code:latest";
      ports = [ "127.0.0.1:9980:9980/tcp" ];
      environment = {
        server_name = "collabora.acelpb.com";
        aliasgroup1 = "https://cloud.acelpb.com:443";
        dictionaries = "en_US";
        extra_params = "--o:ssl.enable=false --o:ssl.termination=true";
      };
      environmentFiles = [ "/etc/nixos/secrets/collabora.env" ];
      extraOptions = [
        "--pull=missing"
      ];
    };
  };
}
