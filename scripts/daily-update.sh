#!/bin/sh
# Run every day by an OpenClaw command job on the Mac (see README.md). If the channel has moved,
# update the server with the configuration already in /etc/nixos. Then check that everything is up.
# Whatever this prints goes to WhatsApp, unless it is only NO_REPLY. A non-zero exit sends the
# failure alert. Each day's full output is kept in LOG_DIR.
set -u

SITES="
https://acelpb.com
https://annechristinefunk.com
https://cloud.acelpb.com/login
https://collabora.acelpb.com/hosting/capabilities
https://inscriptions.acelpb.com
https://inscriptions.dynamobile.net
https://jenkins.acelpb.com/login
"
MAX_CHANGES=30

LOG_DIR="$HOME/Library/Logs/acelpb-daily-update"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$(date +%F).log"
find "$LOG_DIR" -name '*.log' -mtime +730 -delete

log() {
  echo "$(date +%T) $1" >>"$LOG"
}

server() {
  ssh -o BatchMode=yes -o ConnectTimeout=30 -o ServerAliveInterval=30 ac "$@"
}

fetch() {
  # Services can still be restarting just after an update, so retry before reporting them as down.
  curl -fsSL --max-time 30 --retry 3 --retry-delay 30 --retry-all-errors "$@"
}

fail() {
  log "FAILED: $1"
  echo "acelpb daily update: $1"
  exit 1
}

# Package version changes between two systems, one per line, without colours or sizes.
list_changes() {
  esc=$(printf '\033')
  diff=$(server "nix --extra-experimental-features nix-command store diff-closures $1 $2") || return 1
  echo "$diff" | sed -e "s/$esc\[[0-9;]*m//g" -e 's/, [+-][0-9.]* [KMG]iB$//' |
    grep '→' | grep -v '^nixos-system-'
  return 0
}

log "started"

# nixos-version prints something like "26.05.13297.fa1373130d5a (Yarara)".
version=$(server nixos-version) || fail "cannot reach the server over SSH"
release=$(echo "$version" | cut -d. -f1,2)
installed=$(echo "$version" | cut -d' ' -f1 | cut -d. -f4)
latest=$(fetch "https://channels.nixos.org/nixos-$release/git-revision") ||
  fail "cannot read the nixos-$release channel revision"
log "installed $installed, channel $latest"

report=""
case "$latest" in
  "$installed"*)
    log "no update needed"
    ;;
  *)
    old_system=$(server readlink -f /run/current-system)
    log "updating"
    log_lines=$(wc -l <"$LOG")
    if ! server 'sudo nixos-rebuild switch --upgrade' >>"$LOG" 2>&1; then
      tail -n +"$((log_lines + 1))" "$LOG" | tail -n 20
      fail "nixos-rebuild failed. The full log is $LOG"
    fi
    new_system=$(server readlink -f /run/current-system)
    new_version=$(server nixos-version | cut -d' ' -f1)
    changes_listed=yes
    changes=$(list_changes "$old_system" "$new_system") || changes_listed=no
    log "updated to $new_version. Changes:
${changes:-none listed}"

    report="Server updated to $new_version."
    if [ "$changes_listed" = no ]; then
      report="$report
Could not list what changed."
    elif [ -z "$changes" ]; then
      report="$report
No package versions changed."
    else
      count=$(echo "$changes" | wc -l | tr -d ' ')
      report="$report
$(echo "$changes" | head -n "$MAX_CHANGES")"
      if [ "$count" -gt "$MAX_CHANGES" ]; then
        report="$report
... and $((count - MAX_CHANGES)) more, see $LOG"
      fi
    fi
    # A new kernel only takes effect after a reboot, which this job does not do.
    if [ "$(server readlink /run/booted-system/kernel)" != "$(server readlink /run/current-system/kernel)" ]; then
      report="$report
A reboot is needed for the new kernel."
    fi
    ;;
esac

problems=""

failed_units=$(server 'systemctl --failed --no-legend --plain') ||
  problems="$problems
cannot list failed units"
if [ -n "$failed_units" ]; then
  problems="$problems
failed units:
$failed_units"
fi

for site in $SITES; do
  fetch -o /dev/null "$site" || problems="$problems
down: $site"
done

status=$(fetch https://cloud.acelpb.com/status.php) || status=""
case "$status" in
  *'"maintenance":false'*'"needsDbUpgrade":false'*) ;;
  *) problems="$problems
Nextcloud is not healthy: ${status:-no status}" ;;
esac

if [ -n "$problems" ]; then
  fail "something is wrong:$problems${report:+

$report}"
fi

log "all checks passed"
echo "${report:-NO_REPLY}"
