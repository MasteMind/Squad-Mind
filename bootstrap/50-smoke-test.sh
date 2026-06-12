#!/usr/bin/env bash
# Stage 5: Smoke Test (4-agent squad)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 5

info "=== Stage 5: Smoke Test ==="

require_answers_v2 "setup_answers.yaml"
require_file "models.lock.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"
export HERMES_HOME

REPORT_FILE="smoke-test-report.json"
RESULTS=()
OVERALL="PASS"

# ------------------------------------------------------------------
# Helper: record result
# ------------------------------------------------------------------
record() {
    local name="$1"
    local status="$2"
    local detail="${3:-}"
    RESULTS+=("{\"name\":\"$name\",\"status\":\"$status\",\"detail\":\"$detail\"}")
    if [[ "$status" == "FAIL" ]]; then
        OVERALL="FAIL"
    fi
}

if [[ -f ".env" ]]; then
    set -a
    source .env
    set +a
fi

PROVIDER_MODE=$(read_yaml_key setup_answers.yaml "providers.mode" || echo "cli-proxy")

OLLAMA_BASE_URL=$(read_yaml_key setup_answers.yaml "ollama.base_url" \
    || read_yaml_key models.lock.yaml "ollama.base_url" \
    || echo "http://localhost:11434")

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
export TALARIA_ENABLED

# ------------------------------------------------------------------
# Test 1: Bot YAML validation (parse + model matches models.lock /
# the answers override) — covers all 4 agents
# ------------------------------------------------------------------
info "Validating rendered bot YAMLs against models.lock.yaml..."

BOT_CHECK_TSV=$(mktemp)
export BOT_CHECK_TSV

python3 << 'PYEOF'
import os
import yaml

with open('models.lock.yaml') as f:
    lock = yaml.safe_load(f)
with open('setup_answers.yaml') as f:
    answers = yaml.safe_load(f) or {}

overrides = (answers.get('agents') or {}).get('roster') or {}
hermes_home = os.environ['HERMES_HOME']
talaria_enabled = os.environ['TALARIA_ENABLED'] == 'true'

# '|'-separated rows: bash `read` with whitespace IFS collapses empty
# fields (talaria has no port/cli), so a non-whitespace separator is used.
rows = []
for agent_id in ('hermes', 'hephaestus', 'clio', 'talaria'):
    if agent_id == 'talaria' and not talaria_enabled:
        rows.append(f"{agent_id}|SKIP|SKIP|||disabled")
        continue
    path = os.path.join(hermes_home, 'bots', f'{agent_id}.yaml')
    over = overrides.get(agent_id) or {}
    expected_model = str(over.get('model') or lock['agents'][agent_id].get('model'))
    port = over.get('port', lock['agents'][agent_id].get('port'))
    port = '' if port in (None, 'null', '') else str(port)
    cli = over.get('cli') or lock['agents'][agent_id].get('cli', '')
    try:
        with open(path) as f:
            bot = yaml.safe_load(f)
        parse = 'PASS'
        actual_model = str(bot.get('model', ''))
        if actual_model == expected_model:
            model_check, detail = 'PASS', f'model={actual_model}'
        else:
            model_check = 'FAIL'
            detail = f'model={actual_model}, expected {expected_model}'
    except FileNotFoundError:
        parse, model_check, detail = 'FAIL', 'FAIL', f'{path} not found'
    except yaml.YAMLError as e:
        parse, model_check, detail = 'FAIL', 'FAIL', f'YAML parse error: {type(e).__name__}'
    rows.append(f"{agent_id}|{parse}|{model_check}|{port}|{cli}|{detail}")

with open(os.environ['BOT_CHECK_TSV'], 'w') as f:
    f.write('\n'.join(rows) + '\n')
PYEOF

PROXY_PORTS=""
PROXY_CLIS=""
while IFS='|' read -r agent_id parse model_check port cli detail; do
    if [[ "$parse" == "SKIP" ]]; then
        continue
    fi
    record "bot_yaml_${agent_id}" "$parse" "$HERMES_HOME/bots/${agent_id}.yaml"
    record "bot_model_${agent_id}" "$model_check" "$detail"
    if [[ -n "$port" ]]; then
        PROXY_PORTS="$PROXY_PORTS $port"
        PROXY_CLIS="$PROXY_CLIS $cli"
    fi
done < "$BOT_CHECK_TSV"
rm -f "$BOT_CHECK_TSV"

# ------------------------------------------------------------------
# Test 2: Proxy connectivity (ports from the rendered bot YAMLs)
# ------------------------------------------------------------------
if [[ "$PROVIDER_MODE" != "api-keys" ]]; then
    info "Testing CLI proxy connectivity..."
    for port in $PROXY_PORTS; do
        if curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
            "http://127.0.0.1:${port}/health" | grep -q "200"; then
            record "proxy_port_${port}" "PASS" "Proxy healthy on 127.0.0.1:${port}"
        else
            record "proxy_port_${port}" "FAIL" "No healthy proxy on 127.0.0.1:${port}"
        fi
    done
fi

# ------------------------------------------------------------------
# Test 3: Talaria / Ollama reachability
# ------------------------------------------------------------------
if [[ "$TALARIA_ENABLED" == "true" ]]; then
    if curl -s --max-time 5 "${OLLAMA_BASE_URL}/api/tags" | grep -q '"models"'; then
        record "ollama_tags" "PASS" "Ollama reachable at $OLLAMA_BASE_URL"
    else
        record "ollama_tags" "FAIL" "Ollama not responding at ${OLLAMA_BASE_URL}/api/tags"
    fi
fi

# ------------------------------------------------------------------
# Test 4: Direct API keys (if configured — supports mixed mode)
# ------------------------------------------------------------------
info "Testing direct API provider connectivity..."

if [[ -n "${ANTHROPIC_API_KEY:-}" ]] && [[ "${ANTHROPIC_API_KEY:-}" != sk-ant-api03-... ]]; then
    if curl -s -o /dev/null -w "%{http_code}" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        https://api.anthropic.com/v1/models | grep -q "200"; then
        record "anthropic_models" "PASS" "Models endpoint reachable"
    else
        record "anthropic_models" "FAIL" "Models endpoint unreachable or key invalid"
    fi
fi

if [[ -n "${GOOGLE_API_KEY:-}" ]] && [[ "${GOOGLE_API_KEY:-}" != AIza... ]]; then
    if curl -s -o /dev/null -w "%{http_code}" \
        "https://generativelanguage.googleapis.com/v1beta/models?key=$GOOGLE_API_KEY" | grep -q "200"; then
        record "google_models" "PASS" "Models endpoint reachable"
    else
        record "google_models" "FAIL" "Models endpoint unreachable or key invalid"
    fi
fi

if [[ -n "${OPENAI_API_KEY:-}" ]] && [[ "${OPENAI_API_KEY:-}" != sk-... ]]; then
    if curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        https://api.openai.com/v1/models | grep -q "200"; then
        record "openai_models" "PASS" "Models endpoint reachable"
    else
        record "openai_models" "FAIL" "Models endpoint unreachable or key invalid"
    fi
fi

# ------------------------------------------------------------------
# Test 5: Vault integrity
# ------------------------------------------------------------------
if [[ -f "$VAULT_PATH/brain/hot.md" ]]; then
    if HOT_MD="$VAULT_PATH/brain/hot.md" python3 << 'PYEOF' 2>/dev/null
import os, re, sys
import yaml
with open(os.environ['HOT_MD']) as f:
    content = f.read()
match = re.search(r'^---\s*$(.*?)^---\s*$', content, re.MULTILINE | re.DOTALL)
if match:
    try:
        yaml.safe_load(match.group(1))
        sys.exit(0)
    except yaml.YAMLError:
        sys.exit(1)
sys.exit(0)  # No frontmatter is also valid
PYEOF
    then
        record "vault_hot_md" "PASS" "Frontmatter valid or absent"
    else
        record "vault_hot_md" "FAIL" "Frontmatter YAML parse error"
    fi
else
    record "vault_hot_md" "FAIL" "brain/hot.md not found"
fi

# ------------------------------------------------------------------
# Test 6: Runtime permissions
# ------------------------------------------------------------------
if [[ -d "$HERMES_HOME" ]]; then
    PERMS=$(stat -c '%a' "$HERMES_HOME" 2>/dev/null || stat -f '%Lp' "$HERMES_HOME")
    if [[ "$PERMS" == "700" ]]; then
        record "hermes_perms" "PASS" "Permissions are 700"
    else
        record "hermes_perms" "FAIL" "Permissions are $PERMS, expected 700"
    fi
else
    record "hermes_perms" "FAIL" "Hermes home directory not found"
fi

# ------------------------------------------------------------------
# Test 7: .env permissions
# ------------------------------------------------------------------
if [[ -f ".env" ]]; then
    PERMS=$(stat -c '%a' ".env" 2>/dev/null || stat -f '%Lp' ".env")
    if [[ "$PERMS" == "600" ]]; then
        record "env_perms" "PASS" "Permissions are 600"
    else
        record "env_perms" "FAIL" "Permissions are $PERMS, expected 600"
    fi
else
    record "env_perms" "FAIL" ".env not found"
fi

# ------------------------------------------------------------------
# Test 8: Delivery (if enabled)
# ------------------------------------------------------------------
PLATFORM=$(read_yaml_key setup_answers.yaml "delivery.platform" || echo "local-only")
if [[ "$PLATFORM" == "telegram" ]] && [[ -n "${TELEGRAM_BOT_TOKEN_HERMES:-}" ]]; then
    if curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_HERMES}/getMe" | grep -q '"ok":true'; then
        record "telegram_getme" "PASS" "Bot API responds"
    else
        record "telegram_getme" "FAIL" "Bot API did not respond with ok:true"
    fi
fi

# ------------------------------------------------------------------
# Test 9: Proxy prerequisites (CLIs from the rendered bot YAMLs)
# ------------------------------------------------------------------
if [[ "$PROVIDER_MODE" != "api-keys" ]]; then
    if command -v llm-cli-proxy >/dev/null 2>&1; then
        record "llm_cli_proxy_installed" "PASS" "llm-cli-proxy found in PATH"
    else
        record "llm_cli_proxy_installed" "WARN" "llm-cli-proxy not found. Run: npm install -g llm-cli-proxy"
    fi

    for cli in $(echo "$PROXY_CLIS" | tr ' ' '\n' | sort -u); do
        if command -v "$cli" >/dev/null 2>&1; then
            record "cli_${cli}_installed" "PASS" "$cli CLI found"
        else
            record "cli_${cli}_installed" "FAIL" "$cli CLI not found in PATH"
        fi
    done
fi

# ------------------------------------------------------------------
# Test 10: Proxy binding security
# ------------------------------------------------------------------
if [[ "$PROVIDER_MODE" != "api-keys" ]] && [[ -n "${PROXY_PORTS// /}" ]]; then
    if command -v ss &>/dev/null; then
        info "Checking proxy binding security..."
        PORT_REGEX=$(echo "$PROXY_PORTS" | tr -s ' ' '|' | sed 's/^|//;s/|$//')
        insecure_bindings=$(ss -tlnp 2>/dev/null | grep -E ":(${PORT_REGEX})" | grep -v '127.0.0.1' | grep '\*:' || true)
        if [[ -n "$insecure_bindings" ]]; then
            record "proxy_binding" "FAIL" "Proxy bound to 0.0.0.0 instead of 127.0.0.1"
        else
            record "proxy_binding" "PASS" "Proxies restricted to localhost"
        fi
    else
        record "proxy_binding" "WARN" "ss not available, cannot verify binding"
    fi
fi

# ------------------------------------------------------------------
# Write report
# ------------------------------------------------------------------
{
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"provider_mode\": \"$PROVIDER_MODE\","
    echo "  \"overall\": \"$OVERALL\","
    echo "  \"tests\": ["
    for i in "${!RESULTS[@]}"; do
        if [[ $i -gt 0 ]]; then echo ","; fi
        echo -n "    ${RESULTS[$i]}"
    done
    echo ""
    echo "  ]"
    echo "}"
} > "$REPORT_FILE"

info "Smoke test report written to $REPORT_FILE"
info "Overall result: $OVERALL"

if [[ "$OVERALL" == "FAIL" ]]; then
    die "Smoke test failed. Review $REPORT_FILE for details."
fi

set_step 5
info "=== Stage 5 complete ==="
