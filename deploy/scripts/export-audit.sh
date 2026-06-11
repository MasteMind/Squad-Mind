#!/usr/bin/env bash
# export-audit.sh [YYYY-MM-DD] — JSONL audit export of one UTC day of
# kanban activity into the brain. Run nightly by audit-export.timer as the
# `hermes` user; the next vault-autocommit tick commits the file.
#
# Tables (column names verified against hermes_cli/kanban_db.py SCHEMA_SQL):
#   task_events   — id, task_id, run_id, kind, payload, created_at
#   task_comments — id, task_id, author, body, created_at
#   task_runs     — id, task_id, profile, step_key, status, started_at,
#                   ended_at, outcome, summary, error (window on started_at)
#
# One JSON object per row, tagged with "table". Idempotent: re-running a
# day atomically overwrites /srv/squad/brain/audit/<YYYY-MM-DD>.jsonl.
# Uses python3 stdlib sqlite3 (deterministic; no dependence on the sqlite3
# CLI's -json support). DB opened read-only. Default day: yesterday (UTC).
set -euo pipefail

DB="${KANBAN_DB:-/srv/squad/hermes/kanban.db}"
AUDIT_DIR="${AUDIT_DIR:-/srv/squad/brain/audit}"
DAY="${1:-}"

python3 - "$DB" "$AUDIT_DIR" "$DAY" << 'PYEOF'
import datetime
import json
import os
import sqlite3
import sys

db_path, audit_dir, day_arg = sys.argv[1], sys.argv[2], sys.argv[3]

if day_arg:
    day = datetime.date.fromisoformat(day_arg)
else:
    day = (datetime.datetime.now(datetime.timezone.utc)
           - datetime.timedelta(days=1)).date()

start = int(datetime.datetime.combine(
    day, datetime.time.min, tzinfo=datetime.timezone.utc).timestamp())
end = start + 86400

QUERIES = {
    "task_events": (
        "SELECT id, task_id, run_id, kind, payload, created_at "
        "FROM task_events WHERE created_at >= ? AND created_at < ? "
        "ORDER BY id"
    ),
    "task_comments": (
        "SELECT id, task_id, author, body, created_at "
        "FROM task_comments WHERE created_at >= ? AND created_at < ? "
        "ORDER BY id"
    ),
    "task_runs": (
        "SELECT id, task_id, profile, step_key, status, started_at, "
        "ended_at, outcome, summary, error "
        "FROM task_runs WHERE started_at >= ? AND started_at < ? "
        "ORDER BY id"
    ),
}

conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
conn.row_factory = sqlite3.Row

os.makedirs(audit_dir, exist_ok=True)
out_path = os.path.join(audit_dir, f"{day.isoformat()}.jsonl")
tmp_path = out_path + ".tmp"

counts = {}
with open(tmp_path, "w", encoding="utf-8") as f:
    for table, sql in QUERIES.items():
        n = 0
        for row in conn.execute(sql, (start, end)):
            obj = {"table": table}
            obj.update(dict(row))
            f.write(json.dumps(obj, ensure_ascii=False, sort_keys=False))
            f.write("\n")
            n += 1
        counts[table] = n
conn.close()

os.replace(tmp_path, out_path)
total = sum(counts.values())
detail = ", ".join(f"{t}={n}" for t, n in counts.items())
print(f"[export-audit] {day.isoformat()} (UTC): {total} rows ({detail}) -> {out_path}")
PYEOF
