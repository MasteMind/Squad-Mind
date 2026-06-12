#!/usr/bin/env bash
# Stage 4: Wire the 4-agent squad (bots, launchers, roster, workspace symlinks)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 4

info "=== Stage 4: Agent Wiring ==="

require_answers_v2 "setup_answers.yaml"
require_file "models.lock.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"
export VAULT_PATH HERMES_HOME

PROVIDER_MODE=$(read_yaml_key setup_answers.yaml "providers.mode" || echo "cli-proxy")

OLLAMA_BASE_URL=$(read_yaml_key setup_answers.yaml "ollama.base_url" \
    || read_yaml_key models.lock.yaml "ollama.base_url" \
    || echo "http://localhost:11434")

# Talaria is optional: explicit agents.talaria_enabled wins; otherwise it is
# enabled iff an Ollama URL was answered at the interview.
TALARIA_ENABLED=$(read_yaml_key setup_answers.yaml "agents.talaria_enabled" || echo "")
if [[ -z "$TALARIA_ENABLED" ]]; then
    if read_yaml_key setup_answers.yaml "ollama.base_url" >/dev/null; then
        TALARIA_ENABLED="true"
    else
        TALARIA_ENABLED="false"
    fi
fi
case "$TALARIA_ENABLED" in
    True|true|yes|1) TALARIA_ENABLED="true" ;;
    *) TALARIA_ENABLED="false" ;;
esac
export TALARIA_ENABLED OLLAMA_BASE_URL

info "Provider mode: $PROVIDER_MODE"
info "Talaria enabled: $TALARIA_ENABLED (ollama: $OLLAMA_BASE_URL)"

# ------------------------------------------------------------------
# Resolve the 4-agent table: setup_answers agents.roster.* overrides,
# models.lock.yaml supplies the defaults (single source of truth).
# ------------------------------------------------------------------
ROSTER_TSV=$(mktemp)
export ROSTER_TSV

python3 << 'PYEOF'
import os
import yaml

with open('models.lock.yaml') as f:
    lock = yaml.safe_load(f)
with open('setup_answers.yaml') as f:
    answers = yaml.safe_load(f) or {}

overrides = (answers.get('agents') or {}).get('roster') or {}
talaria_enabled = os.environ['TALARIA_ENABLED'] == 'true'
vault = os.environ['VAULT_PATH']

rows = []
for agent_id in ('hermes', 'hephaestus', 'clio', 'talaria'):
    lock_entry = lock['agents'][agent_id]
    over = overrides.get(agent_id) or {}
    name = over.get('name') or agent_id.title()
    role = lock_entry.get('role', agent_id)
    cli = over.get('cli') or lock_entry.get('cli') or lock_entry.get('runtime', '')
    model = str(over.get('model') or lock_entry.get('model'))
    port = over.get('port', lock_entry.get('port'))
    port = '' if port in (None, 'null', '') else str(port)
    enabled = 'true'
    if agent_id == 'talaria' and not talaria_enabled:
        enabled = 'false'
    workspace = f"{vault}/agents/{name}"
    rows.append('\t'.join([agent_id, name, role, cli, model, port, workspace, enabled]))

with open(os.environ['ROSTER_TSV'], 'w') as f:
    f.write('\n'.join(rows) + '\n')
PYEOF

# roster_get <agent_id> <column>  (1=id 2=name 3=role 4=cli 5=model 6=port 7=workspace 8=enabled)
roster_get() {
    awk -F'\t' -v id="$1" -v col="$2" '$1 == id {print $col}' "$ROSTER_TSV"
}

# ------------------------------------------------------------------
# Create .env from template
# ------------------------------------------------------------------
if [[ ! -f ".env.example" ]]; then
    die ".env.example not found. Cannot create .env."
fi

cp .env.example .env

# Fill in keys from setup_answers.yaml (never commit .env — values come
# from interview answers at install time).
python3 << 'PYEOF'
import os
import re
import yaml

with open('setup_answers.yaml') as f:
    config = yaml.safe_load(f) or {}
with open('models.lock.yaml') as f:
    lock = yaml.safe_load(f)

with open('.env') as f:
    env = f.read()


def set_var(name, value):
    global env
    env = re.sub(rf'^{name}=.*$', f'{name}={value}', env, flags=re.MULTILINE)


providers = config.get('providers') or {}
provider_mode = providers.get('mode', 'cli-proxy')
set_var('PROXY_MODE', 'true' if provider_mode == 'cli-proxy' else 'false')

# Direct API keys (always written if present — supports mixed mode)
for provider, env_var in (
    ('anthropic', 'ANTHROPIC_API_KEY'),
    ('google', 'GOOGLE_API_KEY'),
    ('openai', 'OPENAI_API_KEY'),
):
    key = (providers.get(provider) or {}).get('api_key', '')
    if key:
        set_var(env_var, key)

# Ollama endpoint (talaria)
ollama_url = os.environ.get('OLLAMA_BASE_URL', '')
if ollama_url:
    set_var('OLLAMA_BASE_URL', ollama_url)

# Proxy URLs: one per CLI, port taken from the agent bound to that CLI
# (answers override, models.lock default).
overrides = (config.get('agents') or {}).get('roster') or {}
cli_env_vars = {'claude': 'CLAUDE_PROXY_URL', 'gemini': 'GEMINI_PROXY_URL',
                'agy': 'GEMINI_PROXY_URL', 'codex': 'CODEX_PROXY_URL'}
for agent_id, lock_entry in lock['agents'].items():
    over = overrides.get(agent_id) or {}
    cli = over.get('cli') or lock_entry.get('cli')
    port = over.get('port', lock_entry.get('port'))
    env_var = cli_env_vars.get(cli)
    if env_var and port:
        set_var(env_var, f'http://127.0.0.1:{port}/v1')

# Paths
vault = (config.get('paths') or {}).get('vault', '')
hermes_home = (config.get('paths') or {}).get('hermes_home', '')
if vault:
    set_var('VAULT_PATH', vault)
if hermes_home:
    set_var('HERMES_HOME', hermes_home)

# Delivery: per-agent Telegram bot tokens + chat id
delivery = config.get('delivery') or {}
if delivery.get('platform') == 'telegram':
    tg = delivery.get('telegram') or {}
    tokens = tg.get('bot_tokens') or {}
    if not tokens and tg.get('bot_token'):
        tokens = {'hermes': tg['bot_token']}
    for agent_id in ('hermes', 'hephaestus', 'clio', 'talaria'):
        token = tokens.get(agent_id, '')
        if token:
            set_var(f'TELEGRAM_BOT_TOKEN_{agent_id.upper()}', token)
    if tg.get('chat_id'):
        set_var('TELEGRAM_CHAT_ID', tg['chat_id'])

with open('.env', 'w') as f:
    f.write(env)
PYEOF

chmod 600 .env
info ".env created with permissions 600"

# Ensure .env is in .gitignore
if ! grep -q "^\.env$" .gitignore 2>/dev/null; then
    echo ".env" >> .gitignore
    info "Added .env to .gitignore"
fi

# ------------------------------------------------------------------
# Render bot YAMLs + launcher scripts
# ------------------------------------------------------------------
mkdir -p "$HERMES_HOME/bots" "$HERMES_HOME/scripts"

# Superset of vars used across the four bot templates — unused keys in a
# given template are simply not present, so passing all is harmless.
BOT_VARS=(
    "HERMES_CLI=$(roster_get hermes 4)"
    "HERMES_MODEL=$(roster_get hermes 5)"
    "HERMES_PORT=$(roster_get hermes 6)"
    "HEPHAESTUS_CLI=$(roster_get hephaestus 4)"
    "HEPHAESTUS_MODEL=$(roster_get hephaestus 5)"
    "HEPHAESTUS_PORT=$(roster_get hephaestus 6)"
    "CLIO_CLI=$(roster_get clio 4)"
    "CLIO_MODEL=$(roster_get clio 5)"
    "CLIO_PORT=$(roster_get clio 6)"
    "TALARIA_MODEL=$(roster_get talaria 5)"
    "OLLAMA_BASE_URL=$OLLAMA_BASE_URL"
    "VAULT_PATH=$VAULT_PATH"
    "HERMES_HOME=$HERMES_HOME"
)

LAUNCH_TMPL="templates/runtime/hermes/scripts/launch-agent.sh.tmpl"

for agent_id in hermes hephaestus clio talaria; do
    if [[ "$(roster_get "$agent_id" 8)" != "true" ]]; then
        info "Skipping disabled agent: $agent_id"
        continue
    fi

    tmpl="templates/runtime/hermes/bots/${agent_id}.yaml.tmpl"
    require_file "$tmpl"
    render_template "$tmpl" "$HERMES_HOME/bots/${agent_id}.yaml" "${BOT_VARS[@]}"
    info "Rendered $HERMES_HOME/bots/${agent_id}.yaml"

    # Launcher scripts only for proxied agents (talaria runs as a hermes
    # gateway profile and talks to Ollama directly — no launcher).
    port=$(roster_get "$agent_id" 6)
    if [[ -n "$port" && -f "$LAUNCH_TMPL" ]]; then
        render_template "$LAUNCH_TMPL" "$HERMES_HOME/scripts/launch-${agent_id}.sh" \
            "AGENT_ID=$agent_id" \
            "AGENT_NAME=$(roster_get "$agent_id" 2)" \
            "AGENT_ROLE=$(roster_get "$agent_id" 3)" \
            "AGENT_CLI=$(roster_get "$agent_id" 4)" \
            "AGENT_WORKSPACE=$(roster_get "$agent_id" 7)" \
            "HERMES_HOME=$HERMES_HOME"
        chmod +x "$HERMES_HOME/scripts/launch-${agent_id}.sh"
        info "Rendered $HERMES_HOME/scripts/launch-${agent_id}.sh"
    fi
done

verify_no_placeholders "$HERMES_HOME/bots"

# ------------------------------------------------------------------
# Render AGENT_ROSTER.md (one row per enabled agent)
# ------------------------------------------------------------------
ROSTER_TMPL="$VAULT_PATH/brain/AGENT_ROSTER.md.tmpl"
if [[ ! -f "$ROSTER_TMPL" ]]; then
    ROSTER_TMPL="templates/vault/brain/AGENT_ROSTER.md.tmpl"
fi
require_file "$ROSTER_TMPL"
export ROSTER_TMPL

python3 << 'PYEOF'
import os

tmpl_path = os.environ['ROSTER_TMPL']
out_path = os.path.join(os.environ['VAULT_PATH'], 'brain', 'AGENT_ROSTER.md')

with open(tmpl_path) as f:
    text = f.read()

begin = '<!-- ROSTER_ROWS_BEGIN -->'
end = '<!-- ROSTER_ROWS_END -->'
head, rest = text.split(begin, 1)
row_tmpl, tail = rest.split(end, 1)
row_tmpl = row_tmpl.strip('\n')

rows = []
with open(os.environ['ROSTER_TSV']) as f:
    for line in f:
        agent_id, name, role, cli, model, port, workspace, enabled = line.rstrip('\n').split('\t')
        if enabled != 'true':
            continue
        row = row_tmpl
        for key, val in (
            ('AGENT_NAME', name),
            ('AGENT_ROLE', role),
            ('AGENT_CLI', cli),
            ('AGENT_MODEL', model),
            ('AGENT_PORT', port or '—'),
            ('AGENT_WORKSPACE', workspace),
        ):
            row = row.replace('{{' + key + '}}', val)
        rows.append(row)

rendered = head + '\n'.join(rows) + tail
rendered = rendered.replace('{{HERMES_HOME}}', os.environ['HERMES_HOME'])

with open(out_path, 'w') as f:
    f.write(rendered)

print(f"Wrote {out_path} ({len(rows)} agents)")
PYEOF

info "AGENT_ROSTER.md rendered to $VAULT_PATH/brain/AGENT_ROSTER.md"

# ------------------------------------------------------------------
# Workspace wiring: brain symlinks + role-scoped project symlinks
# ------------------------------------------------------------------
for agent_id in hermes hephaestus clio talaria; do
    if [[ "$(roster_get "$agent_id" 8)" != "true" ]]; then
        continue
    fi

    agent_name=$(roster_get "$agent_id" 2)
    agent_dir="$VAULT_PATH/agents/$agent_name"
    mkdir -p "$agent_dir"

    for brain_file in hot.md Memories.md Skills.md AGENT_ROSTER.md; do
        ln -sfn "../../brain/$brain_file" "$agent_dir/$brain_file"
    done

    case "$agent_id" in
        hermes)
            # Orchestrator sees the full projects tree
            ln -sfn ../../projects "$agent_dir/projects"
            ;;
        hephaestus|clio)
            # Scoped to the lab project only
            if [[ ! -L "$agent_dir/projects" ]]; then
                mkdir -p "$agent_dir/projects"
                ln -sfn ../../../projects/agent-distribution-lab "$agent_dir/projects/agent-distribution-lab"
            else
                warn "$agent_dir/projects is a symlink — leaving as-is"
            fi
            ;;
        talaria)
            # Junior agent gets no projects link
            ;;
    esac

    info "Wired workspace for $agent_name"
done

rm -f "$ROSTER_TSV"

set_step 4
info "=== Stage 4 complete ==="
