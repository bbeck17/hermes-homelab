#!/usr/bin/env bash
# Snapshot the agent's entire state to a dated archive.
#
# The archive CONTAINS CREDENTIALS (.env holds the Telegram bot token and any API
# keys; auth.json holds Portal OAuth state). It is written mode 600 and must never
# be committed, synced to a public location, or shared. That is deliberate: a backup
# you have to reconfigure by hand is a backup you won't restore from.
#
# Usage:  ./backup-hermes.sh [dest_dir]        (default: ~/backups/hermes)
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
DEST="${1:-$HOME/backups/hermes}"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$DEST/hermes-$STAMP.tar.gz"

[ -d "$HERMES_HOME" ] || { echo "No Hermes home at $HERMES_HOME" >&2; exit 1; }
mkdir -p "$DEST"

# Excluded: the source checkout (re-fetchable via git), caches, and the venv.
# Everything else IS the agent — config, identity, memory, skills, schedule.
tar -czf "$ARCHIVE" \
  --exclude='hermes-agent' \
  --exclude='node' \
  --exclude='*_cache' \
  --exclude='sandboxes' \
  -C "$(dirname "$HERMES_HOME")" "$(basename "$HERMES_HOME")"

chmod 600 "$ARCHIVE"

echo "Wrote $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
echo "Contains credentials — mode 600, keep it off shared storage."

# Retain the 10 most recent, prune older.
ls -1t "$DEST"/hermes-*.tar.gz 2>/dev/null | tail -n +11 | while read -r old; do
  echo "Pruning $old"; rm -f -- "$old"
done
