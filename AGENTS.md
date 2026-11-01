# AGENTS.md

NixOS configuration for one production OVH VPS (`vps-0ce22064`, serving acelpb.com and
several other sites). Changes here affect live services, including mail and personal data.

## Stack

- NixOS on the `nixos-25.11` channel, with no flakes and no `flake.lock`. The channel on the
  server decides package versions.
- `system.stateVersion = "23.11"`. Do not change it.
- nginx with ACME in front of every web service, PostgreSQL 16, Nextcloud 32.
- Podman is the `oci-containers` backend. Jenkins builds app images and pushes them to the
  local registry at `localhost:5000`.

## Layout

`configuration.nix` is the entry point. Its `imports` list decides what is live, so check it
before assuming a module is in use.

| Status | Files |
| --- | --- |
| Active | `modules/normandy.nix`, `annechristinefunk.nix`, `jenkins.nix`, `dyn_signup.nix`, `dyn_signup_test.nix`, `mail-secret.nix`, `nextcloud.nix`, `immich.nix`, `postgres.nix` (all in `modules/`), plus `distant-secret.nix` and `hardware-configuration.nix` at the root |
| Commented out | `modules/dynaform.nix`, `modules/minecraft.nix` |
| Not imported | `modules/cockpit.nix`, `elk.nix`, `jupyterhub.nix`, `jupyterhub_old.nix`, `mail.nix`, `nextcloud.old/` |
| Legacy | `distant.nix` imports `./acelpb.nix` and `./distant-hardware.nix`, which do not exist |

Mail is configured by `modules/mail-secret.nix`, which is gitignored. Editing `modules/mail.nix`
has no effect on the server.

Do not edit inactive modules unless asked. Do not delete them either: the owner decides what
gets retired.

## Module conventions

Each service gets one file with this shape:

```nix
{ config, lib, pkgs, ... }:
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
  5432 (PostgreSQL), 7777 and 7778 (dyn_signup test and prod) and 9980 (Collabora). Immich also
  has its own port (`services.immich.port`).

Apps that Jenkins deploys, such as `dyn_signup`, also need:

- a polkit `manage-units` rule limited to that one unit and `subject.user == "jenkins"`
- an image from `localhost:5000`
- state and `.env` kept under `/var/www/<name>/`

`dyn_signup.nix` and `dyn_signup_test.nix` are near-identical. Apply a change to both unless it
is specific to one environment.

## Secrets

- `*secret.nix` and everything in `secrets/` are gitignored. Never force-add them, and do not
  read or print them unless the task requires it.
- Never add a new credential to a tracked `.nix` file. Reference a file instead, as in
  `adminpassFile = "/etc/nixos/secrets/nextcloud_adminpass";`.
- For containers, use `environmentFiles` as in the Collabora config in `modules/nextcloud.nix`.
- The GitHub repo is **public**, so treat anything committed as exposed, even if removed later.
- The local `backup/ac2-pre-squash` branch contains old credentials in its history. Never push it.

## Deploying

**Never deploy without an explicit instruction for that deploy.** That covers every `make`
target below except `build-tools`, and any `sudo` or state-changing command over `ssh ac`.

| Target | What it does |
| --- | --- |
| `make deploy` | Syncs the working tree to `ac:/etc/nixos`, then runs `nixos-rebuild switch --upgrade` |
| `make dev` | Same, plus a force-push from `../nixpkgs` and a rebuild against that checkout |
| `make deploy2` | Same as `deploy`, for host `ac2` |
| `make cleanup` | Runs `nix-collect-garbage -d` on the server, which removes rollback generations |

What to expect from a deploy:

- It ships the **working tree**, not a commit. Uncommitted changes go live, and git may not match
  the server.
- `--upgrade` also updates the channel, so any deploy can bump service versions. Check release
  notes for stateful services (Nextcloud, PostgreSQL, Immich) when that matters.
- `rsync -r` has no `--delete`, so files removed locally stay on the server.
- The sync includes `secrets/`, `*secret.nix` and `.git`. Do not change the rsync flags or add
  excludes without checking that the server still gets the secret files it needs.
- `ac2` is not in the owner's `~/.ssh/config` on this Mac, so `make deploy2` will not resolve as
  things stand. Ask before working around that.
- `../nixpkgs` is not checked out on this Mac, so `make dev` will fail as things stand.

## Checking changes

`nix` and `nixos-rebuild` are not installed on the Mac, so a full evaluation only happens on the
server. Before handing over a change:

1. Look up option and package names with the `nixos` MCP server (see `.mcp.json`), using channel
   `25.11`. Its default is `unstable`, which can differ from what is deployed.
2. Check syntax through the tools image:
   `podman run --rm -v .:/src:z -w /src acelpb-nix-tools nix-instantiate --parse <file>`
3. Run the lint hooks (see below).
4. Say plainly that the change has not been evaluated on the server. The owner confirms it when
   deploying.

Read-only commands over `ssh ac` are fine for diagnosis, such as `systemctl status` or
`nixos-version`. Do not print secrets or `.env` files while doing so.

## Formatting and linting

`prek` runs as a pre-commit hook (`prek.toml`): trailing whitespace, end-of-file newline,
`nixfmt`, `statix` and `deadnix`. The Nix tools run inside the `acelpb-nix-tools` image.

- Build the image with `make build-tools`. The podman machine must be running.
- `nixfmt` and the whitespace hooks rewrite files in place, and much of the repo is not yet
  formatted. Expect noise in any file you touch, and keep formatting-only changes separate from
  functional ones when you can.
- The repo does not pass `deadnix`, `statix` or `nixfmt --check` yet, so the hook can fail on
  existing code you did not touch. Report those failures rather than fixing them in passing.
- If the hook cannot run, do not bypass it with `--no-verify` without saying so. Report it.

## Git

- `master` is the main branch. Commit, push or open a PR only when asked.
- Stage specific files rather than using `git add -A`. The working tree often holds unrelated
  changes, and `.DS_Store` and `.idea/` are tracked.
