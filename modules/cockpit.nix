{ config, lib, pkgs, stdenv, ... }:
let
  cockpit = with pkgs; stdenv.mkDerivation rec {
    name = "hello-2.8";
      src = fetchurl {
      url = "https://github.com/cockpit-project/cockpit/releases/cockpit-${version}.tar.xz";
      sha256 = "0wqd8sjmxfskrflaxywc7gqw7sfawrfvdxd9skxawzfgyy0pzdz6";
    };
  };
  cfg = config.services.cockpit;
in
with lib; {
  meta.maintainers = with maintainers; [ aborsu ];

  options.services.cockpit = {
    enable = mkEnableOption "Cockpit";

    ip = mkOption {
      type = types.str;
      default = "localhost";
      description = ''
        IP address Cockpit will be listening on.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 8888;
      description = ''
        Port number Cockpit will be listening on.
      '';
    };
  };

    config = mkMerge [
        (mkIf cfg.enable  {
          systemd.services.cockpit = {
            description = "Cockpit server";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];

            path = [
              cockpit
            ];


            # TODO: need to manage upgrades to remove --no-db
            script = ''${cockpit}/bin/cockpit'';

            serviceConfig = {
              PermissionsStartOnly = true;
              Restart = "always";
              WorkingDirectory = "~";
            };
          };
        })
    ];
}
