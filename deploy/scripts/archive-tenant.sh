#!/usr/bin/env bash
# archive-tenant.sh <tenant-id> [--force] — cold-archive a tenant's kanban
# workspaces. Run manually as the `hermes` user (or root).
#
# 1. Refuses if the tenant has tasks with status NOT IN ('done','archived')
#    (tasks.tenant / tasks.status — verified against kanban_db.py) unless
#    --force is given.
# 2. tar --zstd of /srv/squad/hermes/kanban/workspaces/<tenant>* into
#    /srv/squad/archive/<tenant>-<date>.tar.zst.
# 3. Verifies the archive lists cleanly, THEN removes the workspace dirs.
set -euo pipefail

DB="${KANBAN_DB:-/srv/squad/hermes/kanban.db}"
WS_ROOT="${WORKSPACES_ROOT:-/srv/squad/hermes/kanban/workspaces}"
ARCHIVE_DIR="${ARCHIVE_DIR:-/srv/squad/archive}"

usage() { echo "usage: archive-tenant.sh <tenant-id> [--force]" >&2; }

TENANT=""
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown flag: $arg" >&2; usage; exit 1 ;;
        *)
            if [[ -n "$TENANT" ]]; then usage; exit 1; fi
            TENANT="$arg"
            ;;
    esac
done
if [[ -z "$TENANT" ]]; then usage; exit 1; fi

log() { echo "[archive-tenant] $*"; }

if [[ ! -f "$DB" ]]; then
    echo "[archive-tenant] ERROR: kanban db not found: $DB" >&2
    exit 1
fi

open_count=$(python3 - "$DB" "$TENANT" << 'PYEOF'
import sqlite3
import sys

db, tenant = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
n = conn.execute(
    "SELECT COUNT(*) FROM tasks "
    "WHERE tenant = ? AND status NOT IN ('done', 'archived')",
    (tenant,),
).fetchone()[0]
print(n)
PYEOF
)

if [[ "$open_count" -gt 0 && "$FORCE" -ne 1 ]]; then
    echo "[archive-tenant] REFUSING: tenant '$TENANT' has $open_count non-done task(s)." >&2
    echo "[archive-tenant] Finish/archive them in kanban, or re-run with --force." >&2
    exit 1
fi
if [[ "$open_count" -gt 0 ]]; then
    log "WARNING: --force given — archiving despite $open_count non-done task(s)"
fi

shopt -s nullglob
dirs=("$WS_ROOT/$TENANT"*)
if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "[archive-tenant] ERROR: no workspaces matching $WS_ROOT/${TENANT}*" >&2
    exit 1
fi

names=()
for d in "${dirs[@]}"; do names+=("$(basename "$d")"); done

mkdir -p "$ARCHIVE_DIR"
OUT="$ARCHIVE_DIR/${TENANT}-$(date +%Y-%m-%d).tar.zst"

log "Archiving ${#names[@]} workspace dir(s) -> $OUT"
tar --zstd -cf "$OUT" -C "$WS_ROOT" "${names[@]}"

# Verify the archive lists cleanly before touching the originals.
if ! tar --zstd -tf "$OUT" > /dev/null; then
    echo "[archive-tenant] ERROR: archive verification failed — workspaces NOT removed" >&2
    exit 1
fi
log "Archive verified ($(du -h "$OUT" | cut -f1))"

rm -rf "${dirs[@]}"
log "Removed: ${names[*]}"
log "Done. Restore with: tar --zstd -xf $OUT -C $WS_ROOT"
