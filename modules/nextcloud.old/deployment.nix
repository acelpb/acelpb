# Owncloud deployment
#
# Only use with nixops.
# This module contains scripts to deploy secrets and configure nextcloud.
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.nextcloud;
in
{
  options.services.nextcloud = {
    adminUser = mkOption {
      default = "nextcloud";
      description = "The admin user name for accessing owncloud.";
    };

    adminPassword = mkOption {
      description = "The admin password for accessing owncloud.";
    };

    dbType = mkOption {
      default = "pgsql";
      description = "Type of database. Currently the user creation only works for postgresql.";
    };

    dbName = mkOption {
      default = "nextcloud";
      description = "Name of the database that holds the owncloud data.";
    };

    dbPrefix = mkOption {
      default = "oc_";
      description = "Name of the database that holds the owncloud data.";
    };

    dbHost = mkOption {
      default = "localhost";
      description = ''
        The location of the database server.
      '';
    };

    dbPort = mkOption {
      default = "5432";
      description = ''
        The port of the database server.
      '';
    };

    dbUser = mkOption {
      default = "nextcloud";
      description = "The user name for accessing the database.";
    };

    dbPassword = mkOption {
      example = "foobar";
      description = ''
        The password of the database user.  Warning: this is stored in
        cleartext in the Nix store!
      '';
    };
  };

  config = mkIf (cfg.enable) {
    deployment.keys."secret.config.php" = {
      destDir = "${config.services.nextcloud.installPrefix}/config";
      group = config.services.nextcloud.phpfpm.group;
      permissions = "0600";
      text = ''
        <?php
        $CONFIG = array (
          "dbtype" => "${cfg.dbType}",
          "dbname" => "${cfg.dbName}",
          "dbuser" => "${cfg.dbUser}",
          "dbpassword" => "${cfg.dbPassword}",
          "dbhost" => "${cfg.dbHost}:${cfg.dbPort}",
          "dbtableprefix" => "${cfg.dbPrefix}",
        );
      '';
      user = config.services.nextcloud.phpfpm.user;
    };

    systemd.services.deploy-nextcloud = {
      after = [ "secret.config.php-key.service" "postgresql.service"];
      wants = [ "secret.config.php-key.service" ];
      enable = cfg.enable;
      script = ''
        if [ -f ${cfg.installPrefix}/config/config.php ]; then
          echo "Don't know what to do!"
        else
          ${pkgs.postgresql}/bin/createuser --no-superuser --no-createdb --no-createrole "${cfg.dbUser}" || true
          ${pkgs.postgresql}/bin/createdb "${cfg.dbName}" -O "${cfg.dbUser}" || true
          ${pkgs.postgresql}/bin/psql -d postgres -c "alter user ${cfg.dbUser} with password '${cfg.dbPassword}';"
          ${pkgs.sudo}/bin/sudo -u nextcloud ${pkgs.php}/bin/php ${cfg.modifiedPackage}/occ maintenance:install \
            --database="${cfg.dbType}" \
            --database-name="${cfg.dbName}" \
            --database-host="${cfg.dbHost}" \
            --database-port="${cfg.dbPort}" \
            --database-user="${cfg.dbUser}" \
            --database-pass="${cfg.dbPassword}" \
            --database-table-prefix="${cfg.dbPrefix}" \
            --admin-user="${cfg.adminUser}" \
            --admin-pass="${cfg.adminPassword}" \
            --data-dir="${cfg.installPrefix}/data"
        fi
      '';
    };
  };
}
