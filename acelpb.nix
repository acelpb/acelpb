# Configuration file for acelpb.nix
{ config, pkgs, lib, ... }:
{
  system.nixos.version = "unstable";

  imports =
    [
      <nixpkgs/nixos/modules/profiles/headless.nix>
      (builtins.fetchTarball {
        url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/v2.2.0/nixos-mailserver-v2.2.0.tar.gz";
        sha256 = "0gqzgy50hgb5zmdjiffaqp277a68564vflfpjvk1gv6079zahksc";
      })

      ./modules/annechristinefunk.nix
      ./modules/fiechegutierrez.nix
      ./modules/jupyterhub.nix
      ./modules/mail-secret.nix
      ./modules/nextcloud.nix
      ./modules/normandy.nix
      ./modules/postgres.nix
    ];

  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [
    22 # SSH
    25 # smtp
    80 # HTTP
    143 # mail recieve
    443 # HTTPS
    587 # mail send
  ];

  nix.gc.automatic = true;
  nix.gc.dates = "03:15";

  programs.bash.enableCompletion = true;
  environment.systemPackages = with pkgs; [
    (vim_configurable.customize {
      name = "vim";
      # add custom .vimrc lines like this:
      vimrcConfig.customRC = ''
        set hidden
        " enable syntax highlighting
        syntax enable

        " show line numbers
        set number

        " set tabs to have 4 spaces
        set ts=2

        " indent when moving to the next line while writing code
        set autoindent

        " expand tabs into spaces
        set expandtab

        " when using the >> or << commands, shift lines by 4 spaces
        set shiftwidth=2

        " show a visual line under the cursor's current line
        set cursorline

        " show the matching part of the pair for [] {} and ()
        set showmatch

        " enable all Python syntax highlighting features
        let python_highlight_all = 1

        " Enable folding
        set foldmethod=indent
        set foldlevel=99

        au BufNewFile,BufRead *.py
            \ set tabstop=4
            \ set softtabstop=4
            \ set shiftwidth=4
            \ set textwidth=79
            \ set expandtab
            \ set autoindent
            \ set fileformat=unix

        set encoding=utf-8

      '';
      # plugins can also be managed by VAM
      vimrcConfig.vam.knownPlugins = pkgs.vimPlugins; # optional
      vimrcConfig.vam.pluginDictionaries = [
        # load always
        { names = [
          "youcompleteme"
          "Syntastic"
          "ctrlp-z"
          "The_NERD_tree"
        ]; }
        # vim-nix handles indentation better but does not perform sanity
        { names = [ "vim-addon-nix" ]; ft_regex = "^nix\$"; }
        { names = [ "flake8-vim" ]; ft_regex = "^py\$"; }
      ];
    })
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts = {
      "jupyter.${config.networking.hostName}" = {
        forceSSL = true;
        enableACME = true;
        extraConfig = ''
          location / {

            proxy_pass http://localhost:8888;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Host $http_host;
            proxy_http_version 1.1;
            proxy_redirect off;
            proxy_buffering off;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400;
          }
        '';
      };
      
      "jenkins.acelpb.com" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            proxyPass = "http://localhost:${toString 2711}";
            extraConfig = ''
              sendfile off;
              proxy_redirect     default;
              proxy_redirect     http://          https://;
              proxy_set_header   Host              $host;
              proxy_set_header   X-Real-IP         $remote_addr;
              proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
              proxy_set_header   X-Forwarded-Proto $scheme;
              proxy_set_header   Upgrade           $http_upgrade;
              proxy_set_header   Connection        "Upgrade";
              proxy_max_temp_file_size 0;
              #this is the maximum upload size
              client_max_body_size       10m;
              client_body_buffer_size    128k;
              proxy_connect_timeout      90;
              proxy_send_timeout         90;
              proxy_read_timeout         90;
              proxy_buffer_size          4k;
              proxy_buffers              4 32k;
              proxy_busy_buffers_size    64k;
              proxy_temp_file_write_size 64k;
            '';
          };
        };
      };
    };
  };


  services.jupyterhub = {
    enable = true;
    spawner = "dockerspawner";
    ip = "0.0.0.0";
    # user = "root";  # TODO: Currently pam login only work as root!!
    # group = "root";
  };

  virtualisation.docker.enable = true;

  services.jenkins = {
    enable = true;
    port = 2711;
    listenAddress = "localhost";
  };
}
