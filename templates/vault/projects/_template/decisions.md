# Decisions — <Project Title>

ADR-style log of architectural calls. **Append-only once a decision is
locked** — record decisions as they happen, never backfill from memory.
Supersede a locked decision with a new entry that references the old ID.

Entry format: `D-<SLUG>-NNN` where `<SLUG>` is the project slug (uppercased,
shortened is fine) and `NNN` is a zero-padded sequence number.

---

## D-<SLUG>-001 — <decision title>

- **Date:** <fill — YYYY-MM-DD>
- **Decision:** <fill — one sentence, imperative>
- **Rationale:** <fill — why this call, what it optimizes for>
- **Alternatives considered:** <fill — what was rejected and why>
