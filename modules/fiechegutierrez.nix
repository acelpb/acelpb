
{ config, lib, pkgs, ... }:
{
  config = {  

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "djangowedding.service" &&
              subject.user == "jenkins") {
              return polkit.Result.YES;
          }
      });
    '';

    systemd.services.djangowedding = let
      djangoEnv = let
        photologue = let
          sortedm2m = pkgs.python3.pkgs.buildPythonPackage rec {
            pname = "django-sortedm2m";
            version = "1.5.0";
    
            src = pkgs.python3.pkgs.fetchPypi {
              inherit pname version;
              sha256 = "0528xzdx1wnrz4dhyv9fkpazbnb50gkqpxdzdcmjbkzgjm92p52j";
            };
    
            doCheck = false;
          };
        in
          pkgs.python3.pkgs.buildPythonPackage rec {
          pname = "django-photologue";
          version = "3.8.1";
    
          src = pkgs.fetchFromGitHub {
            owner = "jdriscoll";
            repo = "django-photologue";
            rev = "84e2fc997de902c906d758459e7a2df3a1ed3e31";
            sha256 = "09907dbs7lz6mc9df1srbmcsh32zgzc94bqaqcg82166f33cdgpf";
          };
          buildInputs = [ pkgs.python3.pkgs.django_2_1 ];

          propagatedBuildInputs = [ pkgs.python3.pkgs.pillow pkgs.python3.pkgs.exifread sortedm2m ];
    
          doCheck = false;
        };
      in
        (pkgs.python3.withPackages (ps: with ps; [ gunicorn django_2_1 ipython photologue ]));
    in {
      description = "Django wedding server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.gettext ];
      preStart = ''
        ${djangoEnv}/bin/python manage.py migrate;
        ${djangoEnv}/bin/python manage.py compilemessages;
        ${djangoEnv}/bin/python manage.py collectstatic --no-input;
      '';
      serviceConfig = {
        WorkingDirectory = "/var/www/django-wedding-website/";
        ExecStart = ''${djangoEnv}/bin/gunicorn \
          --access-logfile \
          - --workers 3 \
          --bind unix:/var/www/django-wedding-website/wedding.sock \
          bigday.wsgi:application
        '';
        Restart = "always";
        RestartSec = "10s";
        StartLimitInterval = "1min";
        User = "jenkins";
      };
    };

    services.nginx.virtualHosts = {  
      "fiechegutierrez.com" = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ "www.fiechegutierrez.com" ];
          extraConfig = ''
          client_max_body_size       2048m;
          
          location = /favicon.ico { access_log off; log_not_found off; }
          location /static/ {
              root /var/www/django-wedding-website/;
          }
          location /media/ {
              root /var/www/django-wedding-website/;
          }

          location / {
              proxy_pass http://unix:/var/www/django-wedding-website/wedding.sock;
          }
        '';
      };
    };
  };
}
