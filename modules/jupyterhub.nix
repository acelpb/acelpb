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

  cfg = config.services.jupyterhub;
  jupyterhub = pkgs.python3.withPackages(ps: with ps; [
    jupyterhub
    oauthenticator  ## I use this for Gitub Authentication
  ]
  ++ lib.optional (cfg.spawner == "sudospawner") sudospawner  # TODO: Broken for now.
  ++ lib.optional (cfg.spawner == "dockerspawner") dockerspawner
  );
  # kernels = (pkgs.jupyterKernels cfg.kernels);

  config_file = pkgs.writeText "jupyter_config.py" ''

    # c.JupyterHub.proxy_auth_token = 'PoneyIs_aTOTO'

    ${if cfg.spawner == "sudospawner"
      # c.Spawner.environment = {'JUPYTER_PATH': '${kernels}'"
      then  ''
        c.JupyterHub.spawner_class='sudospawner.SudoSpawner'
          ''
      else ""}

    ${if cfg.spawner == "dockerspawner"
      then  ''
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
      ''
      else ""}

    ${cfg.extraConfig}
  '';

in
with lib; {
  meta.maintainers = with maintainers; [ aborsu ];

  options.services.jupyterhub = {
    enable = mkEnableOption "Jupyterhub server";

    ip = mkOption {
      type = types.str;
      default = "localhost";
      description = ''
        IP address Jupyter will be listening on.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 8888;
      description = ''
        Port number Jupyter will be listening on.
      '';
    };

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

    spawner = mkOption {
      type = types.enum [ "sudospawner" "dockerspawner" ];
      default = "dockerspawner"; # TODO switch back to sudospawner
      description = ''
        Spawner class to use to create singleuser notebooks.
      '';
      example = [
        "sudospawner"
        "dockerspawner"
      ];
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Configuration appended to the jupyterhub_config.py configuration.
      '';
    };

    # kernels = mkOption {
    #   type = types.nullOr (types.attrsOf(types.submodule (import ./kernel-options.nix {
    #     inherit lib;
    #   })));

    #   default = null;
    #   example = literalExample ''
    #     {
    #       python3 = let
    #         env = (python3.withPackages (pythonPackages: with pythonPackages; [
    #                 ipykernel
    #                 pandas
    #                 scikitlearn
    #               ]));
    #       in {
    #         displayName = "Python 3";
    #         argv = [
    #           "$${env}/bin/python"
    #           "-m"
    #           "ipykernel_launcher"
    #           "-f"
    #           "{connection_file}"
    #         ];
    #         language = "python";
    #         logo32 = "$${env.sitePackages}/ipykernel/resources/logo-32x32.png";
    #         logo64 = "$${env.sitePackages}/ipykernel/resources/logo-64x64.png";
    #       };
    #     };
    #   '';
    #   description = "Declarative kernel config

    #   Kernels do not have to be python kernels, but the executable
    #   should have access to any dependencies needed to communicate
    #   with the jupyter server.
    #   In python's case, it means that ipykernel must always be included
    #   in the list of packages of the kernel.
    #   ";
    # };
  };

  config = mkMerge [
    (mkIf cfg.enable  {
      systemd.services.jupyterhub = {
        description = "Jupyterhub server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        path = [
          jupyterhub
          pkgs.sudo # TODO remove or wrap arround optional if sudospawner
        ];

        preStart = ''
          mkdir -p /var/lib/jupyterhub/
          chown ${cfg.user}:${cfg.group} /var/lib/jupyterhub/

          ${if cfg.spawner == "dockerspawner"
          then ''
            # Remove old images (so they are updated)
            ${pkgs.docker}/bin/docker rm $(${pkgs.docker}/bin/docker ps --filter status=exited --filter name=jupyter -q) || true

            # Mounted directories need to have sticky group permission compatible with docker image users. (100)
            mkdir -p /var/lib/jupyterhub/{user_data,shared_envs,shared_config,shared_data}
            chown -R :100 /var/lib/jupyterhub/{user_data,shared_envs,shared_config,shared_data}
            chmod g+rws /var/lib/jupyterhub/{user_data,shared_envs,shared_config,shared_data}
            ${pkgs.acl}/bin/setfacl -d -m g::rwx /var/lib/jupyterhub/{user_data,shared_envs,shared_config,shared_data}
          ''
          else ""}
        '';

        # TODO: need to manage upgrades to remove --no-db
        script = ''${jupyterhub}/bin/jupyterhub \
          --ip=${cfg.ip} \
          --port=${toString cfg.port} \
          --config=${config_file} \
          --no-db
        '';

        serviceConfig = {
          PermissionsStartOnly = true;
          Restart = "always";

          # ExecStart = ''${jupyterhub}/bin/python -m jupyterhub \
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = "~";
        };
      };
    })
    (mkIf (cfg.enable && (cfg.group == "rhea")) {
      users.groups.rhea = {};
    })
    (mkIf (cfg.enable && (cfg.user == "rhea")) {
      users.extraUsers.rhea = {
        extraGroups = [ cfg.group ] ++ lib.optional (cfg.spawner == "dockerspawner") "docker";
        home = "/var/lib/jupyterhub";
        createHome = true;
      };
    })
    (mkIf (cfg.enable && (cfg.spawner == "sudospawner")) {
      security.sudo.extraConfig = ''
        Cmnd_Alias JUPYTER_CMD = ${jupyterhub}/bin/sudospawner
        ${cfg.user} ALL=(%users) NOPASSWD:JUPYTER_CMD
      '';
    })
    (mkIf (cfg.enable && (cfg.spawner == "dockerspawner")) {
      assertions = [
        {
          assertion = config.virtualisation.docker.enable;
          message = "JupyterHub with dockerspawner requires docker tp be enabled";
        }
      ];

      networking.firewall.interfaces = {
        docker0.allowedTCPPorts = [ 8081 ];
      };
    })
  ];
}
