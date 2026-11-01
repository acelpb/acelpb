{ config, lib, pkgs, ... }:
let release = "nixos-25.11";
in
{
  imports = [
    (builtins.fetchTarball {
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/${release}/nixos-mailserver-${release}.tar.gz";
      sha256 = "sd";
    })
  ];

  config = {

    mailserver = {
      enable = true;
      fqdn = "mail.acelpb.com";
      domains = [ "acelpb.com" ];
      loginAccounts = {
          "a.borsu@acelpb.com" = {
              hashedPasswordFile = "/etc/nixos/secrets/mail_a.borsu.hash";

              aliases = [
                  "info@acelpb.com"
                  "postmaster@acelpb.com"
              ];
          };
          "cloud@acelpb.com" = {
            hashedPasswordFile = "/etc/nixos/secrets/mail_cloud.hash";
          };
      };

      # Use Let's Encrypt certificates. Note that this needs to set up a stripped
      # down nginx and opens port 80.
      certificateScheme = 3;

      # Enable IMAP and POP3
      enableImap = true;
      enablePop3 = true;
      enableImapSsl = true;
      enablePop3Ssl = true;

      # Enable the ManageSieve protocol
      enableManageSieve = true;

      # whether to scan inbound emails for viruses (note that this requires at least
      # 1 Gb RAM for the server. Without virus scanning 256 MB RAM should be plenty)
      virusScanning = true;
    };

  };
}
