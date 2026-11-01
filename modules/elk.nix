{ config, lib, pkgs, ... }:
{
  config = {

    services = {
      nginx.virtualHosts = {
        "kibana.${config.networking.hostName}" = {
          enableACME = true;
          forceSSL = true;
          locations = {
            "/" = {
              proxyPass = "http://localhost:5601";
              extraConfig = ''
                auth_basic "Restricted";
                auth_basic_user_file /var/www/kibana/.htpasswd;
              '';
            };
          };
        };
      };

      logstash = {
        enable = true;
        package = pkgs.logstash6-oss;
        inputConfig = ''
          tcp {
            port => 5959
            codec => json
          }
        '';
        outputConfig = ''
          elasticsearch {
            hosts => [ "localhost:9200" ]
          }
        '';
      };

      elasticsearch = {
        enable = true;
        package = pkgs.elasticsearch-oss;
      };

      kibana = {
        enable = true;
        package = pkgs.kibana-oss;
      };
    };
  };
}
