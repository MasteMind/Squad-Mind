---
type: memory
status: active
description: "Long-lived facts about the user. Hermes reads this once per session for grounding."
---

# Memories

## Identity

- **Name:** {{USER_NAME}}
- **Email:** {{USER_EMAIL}}
- **Timezone:** {{TIMEZONE}}

## Working Context

- Team: {{TEAM_NAME}}
- Current initiative: <!-- TODO: one line on what the squad is driving right now -->

## Preferences

- Communication style: concise, engineering-tone.
- Default to surfacing tradeoffs over silent decisions.

## Tools

- Primary agent runtime: Squad-Mind (`{{HERMES_HOME}}`)
- Vault: `{{VAULT_PATH}}` (this file)

## Team Domain Architecture

{{TEAM_DOMAIN_BLURB}}

<!-- TODO (adopting team): this section is the orchestrator's declarative
     domain grounding. Distill it from your team's authoritative
     architecture docs (runbook repo, design wiki, ADRs). Recommended
     structure, proven in the reference deployment — one subsection per
     owned component, each containing:

     ### <Component name>
     #### Purpose          — WHAT-IS + WHY it exists
     #### Components       — the moving parts (services, jobs, stores)
     #### Data flow        — how requests/events traverse the system
     #### Scale & constraints
     #### Tradeoffs / design principles
     #### Dependencies     — upstream / downstream / infrastructure
     #### Ownership signals — which questions land with this team
     #### 3-AM gotchas     — the incidents-waiting-to-happen an on-call
                             engineer must know cold

     Operational procedures (HOW-TO) live in `brain/Skills.md` under the
     matching component split — keep WHAT/WHY here, HOW there.
-->

### Refresh protocol

When the upstream architecture docs update:

```bash
cd /tmp && rm -rf team-architecture-docs
# clone your team's authoritative docs repo, e.g.:
# gh repo clone <org>/<architecture-docs-repo> /tmp/team-architecture-docs -- --depth 1
# then re-distill the changed files and re-fold into brain/Memories.md + brain/Skills.md
```

Re-distill component by component (parallel agents work well — one per
component), then update the line below.

Last refresh: <!-- TODO: YYYY-MM-DD (set on first distillation) -->
