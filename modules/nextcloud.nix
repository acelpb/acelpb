{ config, lib, pkgs, ... }:
{
  config = {
    services.nextcloud = {
      enable = true;
      hostName = "cloud.acelpb.com";
      home = "/var/www/nextcloud";
      https = true;
      nginx.enable = true;
      autoUpdateApps.enable = true;

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
      };
    };
  };
}
