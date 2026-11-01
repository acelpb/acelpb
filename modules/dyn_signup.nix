{ config, lib, pkgs, ... }:
{
  config = let
      name = "dyn_signup";
      domain_name = "inscriptions.dynamobile.net";
      tag = "latest";
      port = "7778";
  in {
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "podman-${name}.service" &&
              subject.user == "jenkins") {
              return polkit.Result.YES;
          }
      });
    '';

    virtualisation.oci-containers.containers."${name}" = {
      image = "localhost:5000/dynasignup:${tag}";
      pull = "always";
      ports = [ "127.0.0.1:${port}:${port}" ];
        volumes = [
          "/var/www/${name}/data:/app/data"
          "/var/www/${name}/uploads:/app/uploads"
          "/var/www/${name}/static:/app/static"
          "/var/www/${name}/.env:/app/.env"
        ];
        cmd = [
          "uv"
          "run"
          "gunicorn"
          "--access-logfile" "-"
          "--workers" "3"
          "--bind" "0.0.0.0:${port}"
          "dynasignup.wsgi:application"
        ];
    };

    systemd.services."podman-${name}".postStart = ''
      podman exec ${name} uv run python manage.py migrate
    '';

    services.nginx.virtualHosts = {
      "${domain_name}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://localhost:${port}";
            recommendedProxySettings = true;
          };
          "/uploads/" = {
            alias = "/var/www/${name}/uploads/";
            extraConfig = ''
              expires 365d;
              add_header Cache-Control "public, immutable";
            '';
          };
          "/static/" = {
            alias = "/var/www/${name}/static/";
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
