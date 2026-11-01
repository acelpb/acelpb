{ config, lib, pkgs, ... }:
{
  config = {

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "dynaform.service" &&
              subject.user == "jenkins") {
              return polkit.Result.YES;
          }
      });
    '';

    systemd.services.dynaform = let
      djangoEnv = let
        django-crispy-forms = pkgs.python3.pkgs.buildPythonPackage rec {
          pname = "django-crispy-forms";
          version = "1.8.0";

          src = pkgs.python3.pkgs.fetchPypi {
            inherit pname version;
            sha256 = "0320b303420fec9ce94e045321dfd180ca0e31e0336211c5d30ad0bda5ebbb5d";
          };

          doCheck = false;
        };
      in
        (pkgs.python3.withPackages (ps: with ps; [
          gunicorn
          django
          whitenoise
          django-crispy-forms
          pillow
          psycopg2
          sorl_thumbnail
          setuptools
          ]));
    in {
      description = "25 ans de dynamobile";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      preStart = ''
        ${djangoEnv}/bin/python manage.py migrate;
        ${djangoEnv}/bin/python manage.py collectstatic --no-input;
      '';
      startLimitIntervalSec = 60;

      serviceConfig = {
        WorkingDirectory = "/var/www/dynaform/";
        ExecStart = ''${djangoEnv}/bin/gunicorn \
          --access-logfile \
          - --workers 3 \
          --bind unix:/var/www/dynaform/dynaform.sock \
          dynamobile.wsgi:application
        '';
        Restart = "always";
        RestartSec = "10s";
        User = "jenkins";
      };
    };

    services.nginx.virtualHosts = {
      "25ans.dynamobile.net" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://unix:/var/www/dynaform/dynaform.sock";
          };
          "/uploads/" = {
            alias = "/var/www/dynaform/uploads/";
            extraConfig = ''
              expires 365d;
              add_header Cache-Control "public, immutable";
            '';
          };
        };
      };
    };
  };
}
