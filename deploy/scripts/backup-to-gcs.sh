#!/usr/bin/env bash
# backup-to-gcs.sh — nightly Squad-Mind backup. Run by squad-backup.timer
# as the `hermes` user.
#
# 1. Consistent sqlite copies of kanban.db (+ state.db if present) via
#    `.backup` into a staging dir — the live db files are NEVER tarred.
# 2. tar.zst of HERMES_HOME excluding venv/caches/live dbs; the .backup
#    copies travel inside the archive under dbs/.
# 3. Upload to $BACKUP_GCS_BUCKET (gcloud storage cp, gsutil fallback).
#    Bucket unset => local-only mode with a journal warning.
# Retention: last 14 archives kept in /srv/squad/archive/backups/.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-/srv/squad/hermes}"
BACKUP_DIR="${BACKUP_DIR:-/srv/squad/archive/backups}"
KEEP=14

log() { echo "[squad-backup] $*"; }

if [[ ! -d "$HERMES_HOME" ]]; then
    echo "[squad-backup] ERROR: HERMES_HOME not found: $HERMES_HOME" >&2
    exit 1
fi

STAGING=$(mktemp -d /tmp/squad-backup.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/dbs" "$BACKUP_DIR"

for db in kanban.db state.db; do
    if [[ -f "$HERMES_HOME/$db" ]]; then
        sqlite3 "$HERMES_HOME/$db" ".backup '$STAGING/dbs/$db'"
        log "sqlite .backup: $db"
    fi
done

BASE=$(basename "$HERMES_HOME")
TS=$(date +%Y%m%d_%H%M%S)
ARCHIVE="$BACKUP_DIR/squad_${TS}.tar.zst"

tar --zstd -cf "$ARCHIVE" \
    --exclude="$BASE/venv" \
    --exclude='*/__pycache__' \
    --exclude='*.pyc' \
    --exclude='*/.cache' \
    --exclude="$BASE/kanban.db*" \
    --exclude="$BASE/state.db*" \
    -C "$(dirname "$HERMES_HOME")" "$BASE" \
    -C "$STAGING" dbs
log "Wrote $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

# Local retention: keep the newest $KEEP archives.
ls -t "$BACKUP_DIR"/squad_*.tar.zst 2>/dev/null | tail -n +$((KEEP + 1)) \
    | while read -r old; do rm -f "$old"; log "Pruned $old"; done

if [[ -z "${BACKUP_GCS_BUCKET:-}" ]]; then
    log "WARNING: BACKUP_GCS_BUCKET unset — local-only backup, skipping GCS upload"
    exit 0
fi

DEST="gs://${BACKUP_GCS_BUCKET#gs://}/backups/$(basename "$ARCHIVE")"
if command -v gcloud >/dev/null 2>&1; then
    gcloud storage cp "$ARCHIVE" "$DEST"
elif command -v gsutil >/dev/null 2>&1; then
    gsutil cp "$ARCHIVE" "$DEST"
else
    log "WARNING: neither gcloud nor gsutil found — archive kept locally only"
    exit 0
fi
log "Uploaded to $DEST"
