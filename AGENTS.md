# AGENTS.md

NixOS configuration for one production OVH VPS. Changes here affect live services, including
mail and personal data. See `README.md` for what runs where and how to deploy.

## Stack

- NixOS on the `nixos-26.05` channel, with no flakes and no `flake.lock`. The channel on the
  server decides package versions. The mail server pin in `modules/mail.nix` must match
  the channel.
- `system.stateVersion = "23.11"`. Do not change it.
- nginx with ACME in front of every web service, PostgreSQL 16, Nextcloud 34.
- Podman is the `oci-containers` backend. Jenkins builds app images and pushes them to the
  local registry at `localhost:5000`.

## Layout

`configuration.nix` is the entry point. Its `imports` list decides what is live. Everything in
`modules/` is imported except `minecraft.nix`, which is switched off. `distant-secret.nix` is
ignored by git and holds users, SSH keys and mail accounts. When you add a setting to it, add a
placeholder to `distant-secret.example.nix` too.

## Module conventions

Each service gets one file with this shape:

```nix
{ pkgs, ... }:
{
  config = {
    # service definition, then its nginx virtual host
  };
}
```

When adding a module:

- Add it to `imports` in `configuration.nix`.
- Give public services a virtual host with `enableACME = true;` and `forceSSL = true;`.
- Bind upstreams to loopback (`127.0.0.1`, `localhost` or `[::1]`) and let nginx proxy to them.
- For containers, publish ports as `"127.0.0.1:<port>:<port>"`. Do not rely on the firewall to
  protect a published port.
- Only add to `networking.firewall` when the service cannot go through nginx.
- Check that a new port is free. Ports already taken include 2711 (Jenkins), 5000 (registry),
  5432 (PostgreSQL), 7777 and 7778 (dyn_signup test and prod) and 9980 (Collabora).

Apps that Jenkins deploys, such as `dyn_signup`, also need:

- a polkit `manage-units` rule limited to that one unit and `subject.user == "jenkins"`
- an image from `localhost:5000`
- state and `.env` kept under `/var/www/<name>/`

Nextcloud apps come from Nix only, through `extraApps`. Do not enable the app store: it makes
`occ upgrade` update packaged apps from the store, which crashes the upgrade.

## Secrets

- `*secret.nix` and `secrets/` are gitignored. Never force-add them, and do not read or print
  them unless the task requires it. If you must inspect one, mask both single- and double-quoted
  values and anything inside comments.
- Never add a new credential to a tracked `.nix` file. Reference a file instead, as in
  `adminpassFile = "/etc/nixos/secrets/nextcloud_adminpass";`.
- For containers, use `environmentFiles` as in the Collabora config in `modules/nextcloud.nix`.
- The GitHub repo is **public**, so treat anything committed as exposed, even if removed later.
- The local `backup/ac2-pre-squash` branch contains old credentials in its history. Never push it.

## Deploying

**Never deploy without an explicit instruction for that deploy.** That covers `make deploy`,
`make cleanup`, and any `sudo` or state-changing command over `ssh ac`.

What to expect from a deploy:

- It ships the **working tree**, not a commit. Uncommitted changes go live, and git may not match
  the server.
- `--upgrade` also updates the channel, so any deploy can bump service versions. Check release
  notes for stateful services (Nextcloud, PostgreSQL) when that matters.
- `rsync -r` has no `--delete`, so files removed locally stay on the server.
- The sync includes `secrets/`, `*secret.nix` and `.git`. Do not change the rsync flags or add
  excludes without checking that the server still gets the secret files it needs.
- Rolling back NixOS does not undo a Nextcloud database upgrade.

## Checking changes

Evaluating the configuration is not enough: the move to 26.05 passed evaluation and still broke
two services at runtime. Before handing over a change:

1. Look up option and package names with the `nixos` MCP server (see `.mcp.json`), using channel
   `26.05`. Its default is `unstable`, which can differ from what is deployed. Also check that a
   package is not marked insecure: being listed does not mean it builds.
2. Evaluate the whole configuration with the Podman command in `README.md`.
3. For refactors, compare the system derivation before and after with `nix-diff`. It should show
   no differences, or only the ones you intended.
4. Run `prek run --all-files`.
5. Say which of these you ran, and that nothing has been tested on the server.

Read-only commands over `ssh ac` are fine for diagnosis, such as `systemctl status` or
`nixos-version`. Do not print secrets or `.env` files while doing so.

## Formatting and linting

`prek` runs as a pre-commit hook (`prek.toml`): trailing whitespace, end-of-file newline,
`nixfmt`, `statix` and `deadnix`. The Nix tools run inside the `acelpb-nix-tools` image, which
`make build-tools` creates. The podman machine must be running.

- `statix.toml` disables `repeated_keys` on purpose.
- If the hook cannot run, do not bypass it with `--no-verify` without saying so. Report it.

## Git

- `master` is the main branch. Commit, push or open a PR only when asked.
- Stage specific files rather than using `git add -A` when the working tree holds unrelated
  changes.
