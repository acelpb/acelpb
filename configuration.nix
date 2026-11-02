{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./distant-secret.nix
    ./hardware-configuration.nix
    ./modules/normandy.nix
    ./modules/annechristinefunk.nix
    ./modules/jenkins.nix
    ./modules/dyn_signup.nix
    ./modules/mail.nix
    ./modules/nextcloud.nix
    # ./modules/minecraft.nix
    ./modules/postgres.nix
  ];

  networking.firewall.allowPing = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22 # SSH
    25 # smtp
    80 # HTTP
    143 # mail recieve
    443 # HTTPS
    587 # mail send
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "vps-0ce22064";
  networking.domain = "vps.ovh.net";
  services.openssh.enable = true;
  system.stateVersion = "23.11";

  i18n = {
    defaultLocale = "fr_BE.UTF-8";
  };
  time.timeZone = "Europe/Brussels";

  environment.systemPackages = with pkgs; [
    sudo
    git
    vim
    (
      let
        # XXX specify the postgresql package you'd like to upgrade to.
        # Do not forget to list the extensions you need.
        newPostgres = pkgs.postgresql_16.withPackages (_pp: [
          # pp.plv8
        ]);
        cfg = config.services.postgresql;
      in
      pkgs.writeScriptBin "upgrade-pg-cluster" ''
        set -eux
        # XXX it's perhaps advisable to stop all services that depend on postgresql
        systemctl stop postgresql

        export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"
        export NEWBIN="${newPostgres}/bin"

        export OLDDATA="${cfg.dataDir}"
        export OLDBIN="${cfg.finalPackage}/bin"

        install -d -m 0700 -o postgres -g postgres "$NEWDATA"
        cd "$NEWDATA"
        sudo -u postgres "$NEWBIN/initdb" -D "$NEWDATA" ${lib.escapeShellArgs cfg.initdbArgs}

        sudo -u postgres "$NEWBIN/pg_upgrade" \
          --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
          --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
          "$@"
      ''
    )
  ];

  security.acme.defaults.email = "a.borsu@gmail.com";
  security.acme.acceptTerms = true;

  services.nginx = {
    enable = true;
    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  security.polkit.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
    };
  };

}
