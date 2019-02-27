{ config, lib, pkgs, ... }:
{
  config = {  
    services.nextcloud = {
      enable = true;
      hostName = "cloud.acelpb.com";
      home = "/var/www/nextcloud";
      https = true;
      nginx.enable = false;

      config = {
        dbtype = "pgsql";
        dbname = "nextcloud";
        dbhost = "localhost";
        dbport = 5432;
        dbuser = "nextcloud";
        dbpassFile = "/etc/nixos/secrets/nextcloud_db";
        dbtableprefix = "oc_";
        adminuser = "aborsu";
        adminpassFile = "/etc/nixos/secrets/nextcloud_adminpass";
        extraTrustedDomains = [
          "owncloud.acelpb.com"
        ];
      };
    };

    services.nginx.virtualHosts = {  
      "cloud.acelpb.com" = {
        forceSSL = true;
        enableACME = true;

        root = pkgs.nextcloud;
        serverAliases = [
          "owncloud.acelpb.com"
        ];

        locations = {
          "= /robots.txt" = {
            priority = 100;
            extraConfig = ''
              allow all;
              log_not_found off;
              access_log off;
            '';
          };
          "/" = {
            priority = 200;
            extraConfig = "rewrite ^ /index.php$uri;";
          };
          "~ ^/store-apps" = {
            priority = 201;
              extraConfig = "root /var/www/nextcloud;";
          };
          "= /.well-known/carddav" = {
            priority = 210;
            extraConfig = "return 301 $scheme://$host/remote.php/dav;";
          };
          "= /.well-known/caldav" = {
            priority = 210;
            extraConfig = "return 301 $scheme://$host/remote.php/dav;";
          };
          "~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/" = {
            priority = 300;
            extraConfig = "deny all;";
          };
          "~ ^/(?:\\.|autotest|occ|issue|indie|db_|console)" = {
            priority = 300;
            extraConfig = "deny all;";
          };
          "~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+)\\.php(?:$|/)" = {
            priority = 500;
            extraConfig = ''
              include ${pkgs.nginxMainline}/conf/fastcgi.conf;
              fastcgi_split_path_info ^(.+\.php)(/.*)$;
              fastcgi_param PATH_INFO $fastcgi_path_info;
              fastcgi_param HTTPS on;
              fastcgi_param modHeadersAvailable true;
              fastcgi_param front_controller_active true;
              fastcgi_pass unix:/run/phpfpm/nextcloud;
              fastcgi_intercept_errors on;
              fastcgi_request_buffering off;
              fastcgi_read_timeout 120s;
            '';
          };
          "~ ^/(?:updater|ocs-provider)(?:$|/)".extraConfig = ''
            try_files $uri/ =404;
            index index.php;
          '';
          "~ \\.(?:css|js|woff|svg|gif)$".extraConfig = ''
            try_files $uri /index.php$uri$is_args$args;
            add_header Cache-Control "public, max-age=15778463";
            add_header X-Content-Type-Options nosniff;
            add_header X-XSS-Protection "1; mode=block";
            add_header X-Robots-Tag none;
            add_header X-Download-Options noopen;
            add_header X-Permitted-Cross-Domain-Policies none;
            access_log off;
          '';
          "~ \\.(?:png|html|ttf|ico|jpg|jpeg)$".extraConfig = ''
            try_files $uri /index.php$uri$is_args$args;
            access_log off;
          '';
        };
        extraConfig = ''
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          add_header X-Robots-Tag none;
          add_header X-Download-Options noopen;
          add_header X-Permitted-Cross-Domain-Policies none;
          error_page 403 /core/templates/403.php;
          error_page 404 /core/templates/404.php;
          client_max_body_size 512M;
          fastcgi_buffers 64 4K;
          gzip on;
          gzip_vary on;
          gzip_comp_level 4;
          gzip_min_length 256;
          gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
          gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
        '';
      };
    };
  };
}
