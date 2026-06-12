# Phase 2 Hardening

Deliberate next steps once the Phase 1 server (see
[server-deployment.md](server-deployment.md)) is running and earning its keep.
None of these block day-1 operation.

## GCP Secret Manager

Phase 1 keeps secrets in `/srv/squad/secrets/.env` (root:hermes 640). Phase 2
removes the at-rest file: an `ExecStartPre=` script on each gateway unit
fetches secrets from GCP Secret Manager using the VM's service account
(`gcloud secrets versions access latest --secret=squad-env`) and writes them to
a `tmpfs`-backed runtime file consumed by `EnvironmentFile=`. Rotation then
becomes "add a new secret version + restart the target" — no file edits, and
IAM gives per-secret audit.

## Langfuse cost dashboard

journald + the kanban audit export already answer *who did what, when*.
Langfuse answers *what it cost* — per-trace, tagged by profile, so Hermes vs
Hephaestus vs Clio spend is directly comparable. Enable it per
[deploy/langfuse.md](../deploy/langfuse.md) when spend attribution becomes a
question; it's env-var-configured and fails open when unset.

## Restore drill cadence

A backup that has never been restored is a hope, not a backup. **Quarterly**,
run the full restore procedure from
[server-deployment.md §4](server-deployment.md#restore) onto a scratch VM:
pull the latest GCS archive, restore, start the target, and complete one Slack
round-trip. Log the date and outcome in the brain so the drill itself is
auditable.

## Second team

Second team = **second VM via the same installer**. One team per VM is the
scaling model: tenancy, secrets, Slack app, and brain repo all stay
team-scoped, and a noisy neighbor can't exist.

## Explicitly NOT built (and why)

- **Kubernetes** — the runtime is a stateful single-writer SQLite system;
  K8s adds failure modes and gains nothing.
- **SSO / RBAC engine** — the security boundary is Slack channel membership +
  `SLACK_ALLOWED_USERS`; finer-grained roles are deliberately out of scope
  rather than building a homegrown auth layer.
- **Org-wide OpenAI-compatible API exposure** — the squad is a team surface,
  not a model gateway; exposing it invites unattributable spend and prompt
  abuse.
- **Postgres migration** — single-writer SQLite with nightly `.backup` copies
  is correct at this scale; a DB server is operational weight without a
  concurrency problem to solve.
- **Streaming responses** — Slack threads are the UX; per-token streaming buys
  nothing there.
