{ pkgs, ... }:
let
  # The forced command for the NAS's SSH key (see distant-secret.nix): it only allows rsync downloads.
  rsyncSender = pkgs.writeShellScriptBin "nas-backup-rsync-sender" ''
    set -f
    case "''${SSH_ORIGINAL_COMMAND-}" in
      "rsync --server --sender "*) ;;
      *)
        echo "Only rsync downloads are allowed." >&2
        exit 1
        ;;
    esac
    # Split the command into its arguments on purpose. Globbing is off.
    # shellcheck disable=SC2086
    exec /run/wrappers/bin/nas-backup-rsync ''${SSH_ORIGINAL_COMMAND#rsync }
  '';
in
{
  config = {
    # Dump every database each night, before the NAS pulls the backup at 03:30
    # (scripts/nas-backup.sh).
    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
      compression = "zstd";
      location = "/var/backup/postgresql";
      startAt = "*-*-* 02:30:00";
    };

    # The NAS logs in as nas-backup. Its key is in distant-secret.nix.
    users.users.nas-backup = {
      isSystemUser = true;
      group = "nas-backup";
      shell = pkgs.bashInteractive;
    };
    users.groups.nas-backup = { };

    # rsync for nas-backup only. It can read every file, but it cannot write anywhere that
    # nas-backup itself cannot.
    security.wrappers.nas-backup-rsync = {
      source = "${pkgs.rsync}/bin/rsync";
      owner = "root";
      group = "nas-backup";
      permissions = "u+rx,g+x";
      capabilities = "cap_dac_read_search+ep";
    };

    environment.systemPackages = [ rsyncSender ];
  };
}
