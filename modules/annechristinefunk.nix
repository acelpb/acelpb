{ config, lib, pkgs, ... }:
{
  config = {

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "acfunk.service" &&
              subject.user == "jenkins") {
              return polkit.Result.YES;
          }
      });
    '';

    systemd.services.acfunk = let
      djangoEnv = let
        bootstrap4 = pkgs.python3.pkgs.buildPythonPackage rec {
          pname = "django-bootstrap4";
          version = "22.1";
          pyproject = true;
          build-system = [ pkgs.python3.pkgs.setuptools ];
          src = pkgs.python3.pkgs.fetchPypi {
            inherit pname version;
            sha256 = "fc9984f7238fbcd330ec5111bf0435083caa7192b022eedd53bfa4128bee318f";
          };

          doCheck = false;

          propagatedBuildInputs = [ pkgs.python3.pkgs.beautifulsoup4 pkgs.python3.pkgs.django ];
        };
        orderedModel = pkgs.python3.pkgs.buildPythonPackage rec {
          pname = "django-ordered-model";
          version = "3.5";
          pyproject = true;
          build-system = [ pkgs.python3.pkgs.setuptools ];

          src = pkgs.python3.pkgs.fetchPypi {
            inherit pname version;
            sha256 = "26c6b5a87a6e51323c53e0233d999dd1a9f40d43b0f17e478de951bc1f999c73";
          };

          doCheck = false;
        };

        imagekit = pkgs.python3.pkgs.buildPythonPackage rec {
          pname = "django-imagekit";
          version = "4.1.0";
          pyproject = true;
          build-system = [ pkgs.python3.pkgs.setuptools ];

          src = pkgs.python3.pkgs.fetchPypi {
            inherit pname version;
            sha256 = "e559aeaae43a33b34f87631a9fa5696455e4451ffa738a42635fde442fedac5c";
          };

          doCheck = false;

          propagatedBuildInputs = [ pkgs.python3.pkgs.six pkgs.python3.pkgs.pilkit pkgs.python3.pkgs.django-appconf  ];
        };
      in
        (pkgs.python3.withPackages (ps: with ps; [
          gunicorn
          django
          pillow
          whitenoise
          brotlipy
          bootstrap4
          imagekit
          psycopg2
          orderedModel
          setuptools
          ]));
    in {
      description = "Anne-Christine Funk virtual art gallery";

      wantedBy = [ "multi-user.target" ];
      wants = [ "network.target" "nginx.service" "postgresql.service" ];
      after = [ "postgresql.service" ];

      preStart = ''
        ${djangoEnv}/bin/python manage.py migrate;
        ${djangoEnv}/bin/python manage.py collectstatic --no-input;
      '';
      startLimitIntervalSec = 60;
      serviceConfig = {
        WorkingDirectory = "/var/www/acfunk/";
        ExecStart = ''${djangoEnv}/bin/gunicorn \
          --access-logfile \
          - --workers 3 \
          --bind unix:/var/www/acfunk/acfunk.sock \
          acfunk.wsgi:application
        '';
        Restart = "always";
        RestartSec = "10s";
        User = "jenkins";
      };
    };

    services.nginx.virtualHosts = {
      "annechristinefunk.com" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://unix:/var/www/acfunk/acfunk.sock";
          };
          "/media/" = {

            root = "/var/www/acfunk";
            extraConfig = ''
              expires 365d;
              add_header Cache-Control "public, immutable";
            '';
          };
        };
      };
      "www.annechristinefunk.com" = {
        enableACME = true;
        forceSSL = true;
        globalRedirect = "annechristinefunk.com";
      };
    };
  };
}
