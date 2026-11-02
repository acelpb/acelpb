_: {
  config = {
    services.nginx.virtualHosts = {
      "acelpb.com" = {
        default = true;
        enableACME = true;
        forceSSL = true;
        root = "/var/www/root";
        serverAliases = [
          "www.acelpb.com"
          "mail.acelpb.com"
        ];

        extraConfig = ''
          add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
        '';
      };
    };
  };
}
