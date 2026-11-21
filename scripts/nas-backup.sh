#!/bin/sh
# Run every night on the NAS (QNAP TS-231P2) from /etc/config/crontab, as admin. Pulls a backup of
# the server over SSH as nas-backup (modules/backup.nix). Each run is a new snapshot, in which
# unchanged files are hard links to the previous one, so they take no extra space.
#
# Snapshots are kept for 14 days, Sunday ones for 60 days and those from the 1st of the month for
# 400 days. last-success holds the time of the last good run, for scripts/daily-update.sh.
set -u

BASE=/share/CACHEDEV1_DATA/.acelpb-backup
SERVER=nas-backup@acelpb.com
PATHS="/etc/nixos /var/backup/postgresql /var/www /var/vmail /var/sieve /var/dkim /var/lib/jenkins"

SNAPSHOTS="$BASE/snapshots"
PARTIAL="$SNAPSHOTS/.partial"
LOCK="$BASE/lock"

umask 077
mkdir -p "$SNAPSHOTS"
chmod 711 "$BASE"
exec >>"$BASE/backup.log" 2>&1

log() {
  echo "$(date '+%F %T') $1"
}

# The first run takes many hours, so make sure the next night's run does not start over it.
if ! mkdir "$LOCK" 2>/dev/null; then
  if kill -0 "$(cat "$LOCK/pid" 2>/dev/null)" 2>/dev/null; then
    log "previous run still going, skipping"
    exit 0
  fi
  log "removing stale lock"
fi
echo $$ >"$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT

log "started"

link_dest=""
[ -d "$SNAPSHOTS/latest" ] && link_dest="--link-dest=$SNAPSHOTS/latest"

sources=""
for path in $PATHS; do
  sources="$sources $SERVER:$path"
done

# A failed run leaves .partial behind, and the next run carries on from it.
# shellcheck disable=SC2086
rsync -a -R -s --numeric-ids --delete --stats $link_dest \
  -e "ssh -i $BASE/ssh/id_ed25519 -o UserKnownHostsFile=$BASE/ssh/known_hosts -o BatchMode=yes -o ServerAliveInterval=60" \
  --exclude='/var/www/nextcloud/data/appdata_*/preview/' \
  --exclude='/var/lib/jenkins/workspace/' \
  $sources "$PARTIAL/"
status=$?
# 24 means some files vanished during the transfer, which is normal on a live server.
if [ "$status" -ne 0 ] && [ "$status" -ne 24 ]; then
  log "FAILED: rsync exited with $status"
  exit 1
fi

if [ "$(date +%d)" = 01 ]; then
  kind=monthly
elif [ "$(date +%u)" = 7 ]; then
  kind=weekly
else
  kind=daily
fi
name="$(date +%F_%H%M).$kind"
touch "$PARTIAL/.created"
mv "$PARTIAL" "$SNAPSHOTS/$name"
ln -sfn "$name" "$SNAPSHOTS/latest"
date +%s >"$BASE/last-success"
chmod 644 "$BASE/last-success"
log "snapshot $name done"

for marker in "$SNAPSHOTS"/*/.created; do
  snapshot=$(dirname "$marker")
  case "$snapshot" in
    *.daily) days=14 ;;
    *.weekly) days=60 ;;
    *.monthly) days=400 ;;
    *) continue ;;
  esac
  [ "$(basename "$snapshot")" = "$name" ] && continue
  if [ -n "$(find "$marker" -mtime +"$days")" ]; then
    log "removing $(basename "$snapshot")"
    rm -rf "$snapshot"
  fi
done

log "finished"
