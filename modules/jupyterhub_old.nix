{ config, lib, pkgs, ... }:
let

  dockerspawner = pkgs.python3.pkgs.buildPythonPackage rec {
    pname = "dockerspawner";
    version = "0.10.0";

    src = pkgs.python3.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "9ac7a8275dd33a73e31da9d3d13849da579f0f248377d5fa558d1ceb793190a6";
    };

    propagatedBuildInputs = [ pkgs.python3.pkgs.escapism pkgs.python3.pkgs.jupyterhub pkgs.python3.pkgs.docker ];

    doCheck = false;
  };

  sudospawner = pkgs.python3.pkgs.buildPythonPackage rec {
    pname = "sudospawner";
    version = "0.5.2";

    src = pkgs.python3.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "5dbddd8164e05e4bb3a31eeb1a5baf5a5c6268f1cd14b3f063cde609b8bfbbe1";
    };

    propagatedBuildInputs = [ pkgs.python3.pkgs.escapism pkgs.python3.pkgs.jupyterhub pkgs.python3.pkgs.docker ];

    doCheck = false;
  };

  cfg = config.services.myjupyterhub;
  jupyterhub = pkgs.python3.withPackages(ps: with ps; [
    jupyterhub
    oauthenticator  ## I use this for Gitub Authentication
  ]
  ++ lib.optional (cfg.spawner == "sudospawner") sudospawner  # TODO: Broken for now.
  ++ lib.optional (cfg.spawner == "dockerspawner") dockerspawner
  );
  # kernels = (pkgs.jupyterKernels cfg.kernels);

  config_file = pkgs.writeText "jupyter_config.py" ''

    ${if cfg.spawner == "sudospawner"
      # c.Spawner.environment = {'JUPYTER_PATH': '${kernels}'"
      then  ''
        c.JupyterHub.spawner_class='sudospawner.SudoSpawner'
          ''
      else ""}

    ${if cfg.spawner == "dockerspawner"
      then  ''

      ''
      else ""}

    ${cfg.extraConfig}
  '';

in
with lib; {

  options.services.myjupyterhub = {

    user = mkOption {
      type = types.str;
      default = "rhea";
      description = ''
        Name of the user used to run the jupyter service.
        For security reason, jupyterhub should really not be run as root.
        If not set (rhea), the service will create a rhea user with appropriate settings.
      '';
      example = "tom";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = ''
        Used to set the group of the jupyterhub service.
        If using the sudospawner class, the hub will only start a notebook
        for users who are part of this group.
      '';
      example = "rhea";
    };
  };

  config = {
    services.jupyterhub = {
      enable = true;

      spawner = "dockerspawner.DockerSpawner";
      authentication = "oauthenticator.github.GitHubOAuthenticator";
      host = "0.0.0.0";
      port = 8888;

      jupyterhubEnv = let
        dockerspawner = pkgs.python3.pkgs.buildPythonPackage rec {
            pname = "dockerspawner";
            version = "12.0.0";

            src = pkgs.python3.pkgs.fetchPypi {
              inherit pname version;
              sha256 = "b2cf2f4284b71f0bf34bc79c622f54805275167c83b446dfc05d8ee27294d60b";
            };

            propagatedBuildInputs = [ pkgs.python3.pkgs.escapism pkgs.python3.pkgs.jupyterhub pkgs.python3.pkgs.docker ];

            doCheck = false;
          };
        in (
          pkgs.python3.withPackages (p: with p; [
            dockerspawner
            oauthenticator
            jupyterhub
            jupyterlab
        ]));
      extraConfig = ''
        c.JupyterHub.spawner_class='dockerspawner.DockerSpawner'

        # TODO REMOVE ALL BELLOW UNTIL extraConfig
        import socket
        import fcntl
        import struct

        def get_ip_address(ifname):
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            return socket.inet_ntoa(fcntl.ioctl(
                s.fileno(),
                0x8915,  # SIOCGIFADDR
                struct.pack(b'256s', ifname[:15].encode('ascii'))
            )[20:24])

        c.JupyterHub.hub_ip = get_ip_address('docker0')

        # c.DockerSpawner.image = 'jupyter/all-spark-notebook:latest'

        from pathlib import Path
        def create_dir_hook(spawner):
            user_home = Path('/var/lib/jupyterhub/user_data/') / spawner.user.name
            if not user_home.exists():
                user_home.mkdir()


        c.Spawner.pre_spawn_hook = create_dir_hook

        c.DockerSpawner.volumes = {
          '/var/lib/jupyterhub/user_data/{username}': '/home/jovyan',
          '/var/lib/jupyterhub/shared_envs': '/opt/conda/envs',
          '/var/lib/jupyterhub/shared_config': '/usr/local/share/jupyter',
          '/var/lib/jupyterhub/shared_data': '/home/jovyan/shared_data',
        }
      '';
    };

    services.nginx.virtualHosts."jupyter.acelpb.com" = {
      forceSSL = true;
      enableACME = true;
      extraConfig = ''
        location / {
          proxy_pass http://localhost:8888;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header Host $host;
          proxy_http_version 1.1;
          proxy_redirect off;
          proxy_buffering off;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_read_timeout 86400;
        }
      '';
    };

    systemd.services.jupyterhub = {
      preStart = ''
        mkdir -p /var/lib/jupyterhub/
        chown ${cfg.user}:${cfg.group} /var/lib/jupyterhub/

        # Remove old images (so they are updated)
        ${pkgs.docker}/bin/docker rm $(${pkgs.docker}/bin/docker ps --filter status=exited --filter name=jupyter -q) || true

        # Mounted directories need to have sticky group permission compatible with docker image users. (100)
        mkdir -p /var/lib/jupyterhub/{user_data,shared_envs,shared_config,shared_data}
        chown -R :100 /var/lib/jupyterhub/{user_data,shared_envs,shared_config,shared_data}
        chmod g+rws /var/lib/jupyterhub/{user_data,shared_envs,shared_config,shared_data}
        ${pkgs.acl}/bin/setfacl -d -m g::rwx /var/lib/jupyterhub/{user_data,shared_envs,shared_config,shared_data}
      '';
    };

    users.groups.rhea = {};
    users.extraUsers.rhea = {
      isSystemUser = true;
      group = "rhea";
      extraGroups = [ cfg.group "docker" ];
      home = "/var/lib/jupyterhub";
      createHome = true;
    };


    # security.sudo.extraConfig = ''
    #   Cmnd_Alias JUPYTER_CMD = ${jupyterhub}/bin/sudospawner
    #   ${cfg.user} ALL=(%users) NOPASSWD:JUPYTER_CMD
    # '';

    assertions = [
      {
        assertion = config.virtualisation.docker.enable;
        message = "JupyterHub with dockerspawner requires docker to be enabled";
      }
    ];

    networking.firewall.interfaces = {
      docker0.allowedTCPPorts = [ 8081 ];
    };
  };
}
