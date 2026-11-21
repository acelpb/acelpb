{
  config,
  pkgs,
  ...
}:
{
  config = {
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud35;

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
          cospend
          deck
          forms
          groupfolders
          guests
          news
          polls
          previewgenerator
          quota_warning
          richdocuments
          spreed
          tables
          twofactor_webauthn
          ;
        # Not packaged in nixpkgs. A new release needs a new url, hash and appVersion.
        shopping_list = pkgs.fetchNextcloudApp {
          url = "https://github.com/otherworld-dev/Shopping-List/releases/download/v1.13.1/shopping_list.tar.gz";
          hash = "sha256-yMLJXPkT4pDtIqWrSJ1XngaQyujXuKQLg/9ttOVp/JE=";
          license = "agpl3Plus";
          appName = "shopping_list";
          appVersion = "1.13.1";
        };
        # nixpkgs only packages Memories for Nextcloud 34 and older. Once the channel packages it
        # for 35, use that instead.
        memories = pkgs.fetchNextcloudApp {
          url = "https://github.com/pulsejet/memories/releases/download/v11.1.4/memories.tar.gz";
          hash = "sha256-ObXsa/F1M0Qy6MQJoEhNqGb/+QPGNJQsyzxBgJ+QY1M=";
          license = "agpl3Plus";
          appName = "memories";
          appVersion = "11.1.4";
        };
      };

      # Desktop and phone clients hear about changes at once instead of polling.
      notify_push.enable = true;

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
        # Only one PHP server, so any fixed ID will do.
        serverid = 0;
        # Notifications and shares go out through the local mail server (mail.nix), which signs
        # them with DKIM. It accepts mail from localhost without a login.
        mail_from_address = "cloud";
        mail_domain = "acelpb.com";
        # The mail server's certificate is for acelpb.com, not 127.0.0.1.
        mail_smtpstreamoptions.ssl.peer_name = "acelpb.com";

        # notify_push checks that requests from the server itself come through a trusted proxy.
        trusted_proxies = [
          "127.0.0.1"
          "::1"
          "149.202.40.75"
          "2001:41d0:404:300::8f1"
        ];

        # Thumbnails for photos, iPhone HEIC pictures and videos. Previews are capped at 2048
        # pixels to save disk space.
        enabledPreviewProviders = [
          "OC\\Preview\\PNG"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\GIF"
          "OC\\Preview\\BMP"
          "OC\\Preview\\XBitmap"
          "OC\\Preview\\Krita"
          "OC\\Preview\\WebP"
          "OC\\Preview\\HEIC"
          "OC\\Preview\\Movie"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\TXT"
          "OC\\Preview\\OpenDocument"
        ];
        preview_max_x = 2048;
        preview_max_y = 2048;
        preview_ffmpeg_path = "${pkgs.ffmpeg-headless}/bin/ffmpeg";

        # Memories uses the Nix tools, not the ones it ships. Video transcoding is off: it is too
        # heavy for this server, and browsers play phone videos directly.
        "memories.exiftool" = "${pkgs.exiftool}/bin/exiftool";
        "memories.exiftool_no_local" = true;
        "memories.vod.disable" = true;
        "memories.vod.ffmpeg" = "${pkgs.ffmpeg-headless}/bin/ffmpeg";
        "memories.vod.ffprobe" = "${pkgs.ffmpeg-headless}/bin/ffprobe";

        # Deleted files and old versions go after 30 and 90 days, or sooner if space runs out.
        trashbin_retention_obligation = "auto, 30";
        versions_retention_obligation = "auto, 90";
      };

      # The default of 8 MB is nearly full.
      phpOptions."opcache.interned_strings_buffer" = "16";
    };

    # Make thumbnails for new files ahead of time, so galleries load fast (previewgenerator).
    systemd.services.nextcloud-preview-generate = {
      description = "Generate Nextcloud previews for new files";
      after = [ "nextcloud-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "nextcloud";
        ExecStart = "${config.services.nextcloud.occ}/bin/nextcloud-occ preview:pre-generate";
      };
    };
    systemd.timers.nextcloud-preview-generate = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "*:0/15";
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

            # Document conversion: only the server itself, for Nextcloud previews.
            location ^~ /cool/convert-to {
              allow 127.0.0.1;
              allow ::1;
              allow 149.202.40.75;
              allow 2001:41d0:404:300::8f1;
              deny all;
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
      pull = "newer";
    };
  };
}
