#!/usr/bin/env bash
# vault-autocommit.sh — commit + sync the shared brain every 5 minutes.
# Run by vault-autocommit.timer as the `hermes` user (system scope).
#
# Behavior: stage everything; commit only when something is staged;
# pull --rebase then push when an `origin` remote exists. NEVER
# force-pushes; on a rebase conflict it aborts the rebase, alerts, and
# exits non-zero so a human resolves the conflict — it never guesses.
#
# Alerting: POST to $SLACK_ALERT_WEBHOOK (from /srv/squad/secrets/.env).
# If the webhook is unset, the alert still lands in the journal.
set -euo pipefail

BRAIN="${VAULT_PATH:-/srv/squad/brain}"

log() { echo "[vault-autocommit] $*"; }

alert() {
    local msg="$1"
    log "ALERT: $msg"
    if [[ -n "${SLACK_ALERT_WEBHOOK:-}" ]]; then
        curl -fsS -m 10 -X POST -H 'Content-Type: application/json' \
            -d "{\"text\":\"[squad-mind] ${msg}\"}" \
            "$SLACK_ALERT_WEBHOOK" >/dev/null \
            || log "Slack alert delivery failed (webhook unreachable)"
    else
        log "SLACK_ALERT_WEBHOOK unset — alert logged to journal only"
    fi
}

cd "$BRAIN"

# Deterministic commit identity (repo-local, written once).
if ! git config user.email >/dev/null 2>&1; then
    git config user.email "squad-auto@$(hostname -s)"
    git config user.name "Squad Auto"
fi

git add -A
if ! git diff --cached --quiet; then
    n=$(git diff --cached --name-only | wc -l | tr -d ' ')
    git commit -m "squad-auto: ${n} files changed"
    log "Committed ${n} changed files"
else
    log "No changes to commit"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    log "No 'origin' remote — local-only vault, skipping pull/push"
    exit 0
fi

if ! git pull --rebase; then
    git rebase --abort || true
    alert "vault-autocommit: rebase conflict in ${BRAIN} — manual resolution needed; vault left at local HEAD"
    exit 1
fi

if ! git push; then
    alert "vault-autocommit: git push failed for ${BRAIN} (remote unreachable or rejected)"
    exit 1
fi

log "Vault synced with origin"
