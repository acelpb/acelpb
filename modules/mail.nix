{ config, ... }:
let
  release = "nixos-26.05";
in
{

  imports = [
    (builtins.fetchTarball {

      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/${release}/nixos-mailserver-${release}.tar.gz";
      sha256 = "0xp7ip4vafi6wx38ghwa191v4d84h2l9pczw2jzxysh5qdcv4akb";
    })
  ];

  config = {

    mailserver = {
      stateVersion = 5;
      enable = true;
      fqdn = "acelpb.com";
      domains = [ "acelpb.com" ];
      # Accounts are defined in distant-secret.nix.

      # Use the Let's Encrypt certificate of the acelpb.com virtual host (normandy.nix).
      x509.useACMEHost = config.mailserver.fqdn;

      # A new selector makes the server generate a new key (2048-bit by default).
      # Publish it in DNS as <selector>._domainkey.acelpb.com.
      dkim.defaults.selector = "mail2026";

      # Enable IMAP and POP3
      enableImap = true;
      enablePop3 = false;
      enableImapSsl = true;
      enablePop3Ssl = true;

      # Enable the ManageSieve protocol
      enableManageSieve = true;

      # whether to scan inbound emails for viruses (note that this requires at least
      # 1 Gb RAM for the server. Without virus scanning 256 MB RAM should be plenty)
      virusScanning = true;
    };

    # Ban addresses that keep failing mail logins, for longer each time they come back.
    # fail2ban itself is enabled in distant-secret.nix.
    services.fail2ban.bantime-increment.enable = true;
    services.fail2ban.jails = {
      postfix-sasl.settings = {
        enabled = true;
        filter = "postfix[mode=auth]";
        maxretry = 5;
      };
      dovecot.settings = {
        enabled = true;
        filter = "dovecot[mode=aggressive]";
        maxretry = 5;
      };
    };

  };

}
