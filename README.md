# acelpb

NixOS configuration for one OVH VPS (`vps-0ce22064`) that hosts acelpb.com and a few other
sites. `configuration.nix` is the entry point, and each service has its own file in `modules/`.

The server runs the `nixos-26.05` channel. There are no flakes, so the channel on the server
decides package versions.

## What runs here

| Service | Address | Module | Notes |
| --- | --- | --- | --- |
| Static site | acelpb.com, www, mail | `normandy.nix` | Files in `/var/www/root` |
| Art gallery | annechristinefunk.com | `annechristinefunk.nix` | Django app from [acelpb/acfunk](https://github.com/acelpb/acfunk), in `/var/www/acfunk` |
| Dynamobile sign-up | inscriptions.dynamobile.net | `dyn_signup.nix` | Container on port 7778, image tag `latest` |
| Dynamobile sign-up (test) | inscriptions.acelpb.com | `dyn_signup.nix` | Container on port 7777, image tag `test` |
| Nextcloud 35 | cloud.acelpb.com | `nextcloud.nix` | Data in `/var/www/nextcloud` |
| Collabora | collabora.acelpb.com | `nextcloud.nix` | Container on `127.0.0.1:9980`; the admin console needs an SSH tunnel |
| Jenkins | jenkins.acelpb.com | `jenkins.nix` | Also runs the image registry on `localhost:5000` |
| Mail | acelpb.com | `mail.nix` | NixOS mailserver; IMAP on 993, SMTP on 587; accounts in `distant-secret.nix` |
| PostgreSQL 16 | local only | `postgres.nix` | Used by Nextcloud and the gallery |

`modules/minecraft.nix` is a Bedrock server that is switched off. To use it, uncomment its import.

Disks: `/` is 158 GB and `/var/www` is 196 GB. Both are over 90% full.

## Files that are not in git

The repo is public, so credentials stay in ignored files. These only exist on the machine you
deploy from and on the server, so **losing both means losing them**.

| File | Contents |
| --- | --- |
| `distant-secret.nix` | Admin user, SSH keys, sudo and SSH settings, fail2ban, Nextcloud `hostName` and `home`, mail accounts |
| `secrets/nextcloud_adminpass` | Nextcloud admin password |
| `secrets/collabora.env` | Collabora admin login, as `username=...` and `password=...` lines |
| `secrets/mail_*.hash` | Password hashes for mail accounts that use `hashedPasswordFile` |

To set up from scratch, copy `distant-secret.example.nix` to `distant-secret.nix` and fill it in,
then create the files in `secrets/`.

## Working on it

Install [Podman](https://podman.io) and [prek](https://github.com/j178/prek), then:

```sh
make build-tools   # build the image with nixfmt, statix and deadnix
prek install       # run those checks on every commit
```

To check that the whole configuration evaluates, without Nix on your machine:

```sh
podman run --rm -v "$PWD":/src:ro,z -e NIX_PATH=nixpkgs=https://nixos.org/channels/nixos-26.05/nixexprs.tar.xz \
  docker.io/nixos/nix nix-instantiate '<nixpkgs/nixos>' -A system -I nixos-config=/src/configuration.nix
```

## Deploying

The SSH host `ac` must point at the server.

| Command | What it does |
| --- | --- |
| `make deploy` | Copies this folder to `/etc/nixos`, then runs `nixos-rebuild switch --upgrade` |
| `make cleanup` | Deletes old system generations, which also removes your rollback options |

- A deploy ships your working folder, including uncommitted changes.
- `--upgrade` also updates the channel, so any deploy can change package versions.
- Files you delete locally stay in `/etc/nixos`, because the copy does not delete anything.

## Upgrading NixOS

1. Read the [NixOS release notes](https://nixos.org/manual/nixos/stable/release-notes) and the
   [mailserver release notes](https://nixos-mailserver.readthedocs.io/en/latest/release-notes.html).
2. In `modules/mail.nix`, change `release` to the new version and update `sha256`.
3. Check that the Nextcloud version in `nextcloud.nix` is still supported. Nextcloud can only move
   up one major version at a time, and its database upgrade cannot be rolled back, so back up first.
4. Check that the configuration evaluates (see above).
5. Run `ssh ac 'sudo nix-channel --add https://nixos.org/channels/nixos-XX.YY nixos'`, then
   `make deploy`.
6. If glibc changed, PostgreSQL warns about a collation mismatch. Run `reindexdb --all` and
   `ALTER DATABASE <name> REFRESH COLLATION VERSION` for each database.

## Upgrading Nextcloud

Nextcloud can only move up one major version per deploy, and a NixOS rollback does not undo its
database upgrade, so the dump below is your only way back.

1. Change `package` in `modules/nextcloud.nix` and check that the configuration evaluates.
2. Back up the database and config:

   ```sh
   ssh ac 'sudo -u postgres pg_dump -Fc -f /tmp/nextcloud.dump nextcloud && sudo mv /tmp/nextcloud.dump /root/ && sudo tar czf /root/nextcloud-config.tgz -C /var/www/nextcloud config'
   ```

3. Run `make deploy`. If the channel has moved, this also updates everything else.

   The move to 35 ended with `nextcloud-setup` failing on `Could not resolve
   OCP\AppFramework\Services\IAppConfig`, after `Update successful` in its log. The upgrade had
   finished, and a check that runs after it had crashed. Do not roll back or deploy again. Run
   `ssh ac 'sudo systemctl restart nextcloud-setup && sudo systemctl start nextcloud-update-db'`.
4. Check that `https://cloud.acelpb.com/status.php` shows the new version with
   `needsDbUpgrade: false`, that `nextcloud-occ app:list` still shows your apps as enabled, and
   that a document opens in Collabora.

To go back, stop `phpfpm-nextcloud` and `nextcloud-cron.timer`, recreate the `nextcloud` database
owned by the `nextcloud` role, restore the dump with `pg_restore -d nextcloud`, unpack the config
archive, then run `nixos-rebuild switch --rollback`.

## Known gaps

- **No backups are configured.**
- PostgreSQL trusts all local connections.
- `files_trashbin` is disabled in Nextcloud, so deleted files are gone immediately.

## Useful tests

- [SSL Labs](https://www.ssllabs.com/ssltest/analyze.html?d=acelpb.com&latest)
- [Mail Tester](https://www.mail-tester.com/)
- [Email Security Grader](http://emailsecuritygrader.com/)
