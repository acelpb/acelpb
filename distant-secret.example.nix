# Copy this file to distant-secret.nix and fill in your own values. distant-secret.nix is
# ignored by git, so it can hold what should not be public: users, SSH keys and password hashes.
#
# Generate a password hash with: openssl passwd -6
{
  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = false;

  # Jenkins builds and runs containers without root.
  users.users.jenkins = {
    autoSubUidGidRange = true;
    extraGroups = [ "podman" ];
    linger = true;
  };

  services.fail2ban.enable = true;

  # The administrator account. Deploying needs SSH access and sudo.
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "podman"
    ];
    description = "Your Name";
    hashedPassword = "<password hash>";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA<your public key> you@example.com"
    ];
  };

  # The NAS that pulls the nightly backup (modules/backup.nix). The forced command only allows
  # rsync downloads.
  users.users.nas-backup.openssh.authorizedKeys.keys = [
    ''restrict,command="/run/current-system/sw/bin/nas-backup-rsync-sender" ssh-ed25519 AAAA<the NAS public key> nas-backup''
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.nextcloud = {
    hostName = "cloud.acelpb.com";
    home = "/var/www/nextcloud";
  };

  # Mail accounts. The server configuration is in modules/mail.nix.
  mailserver.accounts = {
    "you@acelpb.com" = {
      # hashedPassword ends up in the world-readable Nix store. A file does not.
      hashedPasswordFile = "/etc/nixos/secrets/mail_you.hash";
      aliases = [
        "postmaster@acelpb.com"
        "info@acelpb.com"
      ];
    };
  };
}
