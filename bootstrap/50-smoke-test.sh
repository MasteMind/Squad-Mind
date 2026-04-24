#!/usr/bin/env bash
# Stage 5: Smoke Test
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

guard_step 5

info "=== Stage 5: Smoke Test ==="

require_file "setup_answers.yaml"

VAULT_PATH=$(read_yaml_key setup_answers.yaml "paths.vault" || echo "$HOME/Documents/Home-Brain")
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
HERMES_HOME=$(read_yaml_key setup_answers.yaml "paths.hermes_home" || echo "$HOME/.hermes")
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"

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

# ------------------------------------------------------------------
# Test 1: Provider connectivity
# ------------------------------------------------------------------
if [[ -f ".env" ]]; then
    set -a
    source .env
    set +a
fi

PROVIDER_MODE=$(python3 -c "
import yaml
with open('setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print(data.get('providers', {}).get('mode', 'api-keys'))
")

# Test proxies if configured (supports mixed mode)
info "Testing CLI proxy connectivity..."

if [[ -n "${CLAUDE_PROXY_URL:-}" ]] && [[ "$CLAUDE_PROXY_URL" != *"local-proxy"* ]]; then
    if curl -s -o /dev/null -w "%{http_code}" \
        "${CLAUDE_PROXY_URL%/v1}/health" | grep -q "200"; then
        record "claude_proxy" "PASS" "Claude proxy healthy at $CLAUDE_PROXY_URL"
    else
        record "claude_proxy" "FAIL" "Claude proxy not responding at $CLAUDE_PROXY_URL"
    fi
fi

if [[ -n "${GEMINI_PROXY_URL:-}" ]] && [[ "$GEMINI_PROXY_URL" != *"local-proxy"* ]]; then
    if curl -s -o /dev/null -w "%{http_code}" \
        "${GEMINI_PROXY_URL%/v1}/health" | grep -q "200"; then
        record "gemini_proxy" "PASS" "Gemini proxy healthy at $GEMINI_PROXY_URL"
    else
        record "gemini_proxy" "FAIL" "Gemini proxy not responding at $GEMINI_PROXY_URL"
    fi
fi

# Test direct API keys if configured (supports mixed mode)
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

if [[ -n "${KIMI_API_KEY:-}" ]] && [[ "${KIMI_API_KEY:-}" != sk-... ]]; then
    if curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $KIMI_API_KEY" \
        https://api.moonshot.cn/v1/models | grep -q "200"; then
        record "kimi_models" "PASS" "Models endpoint reachable"
    else
        record "kimi_models" "FAIL" "Models endpoint unreachable or key invalid"
    fi
fi

if [[ -n "${OPENROUTER_API_KEY:-}" ]] && [[ "${OPENROUTER_API_KEY:-}" != sk-or-v1-... ]]; then
    if curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        https://openrouter.ai/api/v1/models | grep -q "200"; then
        record "openrouter_models" "PASS" "Models endpoint reachable"
    else
        record "openrouter_models" "FAIL" "Models endpoint unreachable or key invalid"
    fi
fi

# ------------------------------------------------------------------
# Test 2: Vault integrity
# ------------------------------------------------------------------
if [[ -f "$VAULT_PATH/brain/hot.md" ]]; then
    if python3 -c "
import yaml, re, sys
with open('$VAULT_PATH/brain/hot.md') as f:
    content = f.read()
match = re.search(r'^---\s*$(.*?)^---\s*$', content, re.MULTILINE | re.DOTALL)
if match:
    try:
        yaml.safe_load(match.group(1))
        sys.exit(0)
    except:
        sys.exit(1)
else:
    sys.exit(0)  # No frontmatter is also valid
" 2>/dev/null; then
        record "vault_hot_md" "PASS" "Frontmatter valid or absent"
    else
        record "vault_hot_md" "FAIL" "Frontmatter YAML parse error"
    fi
else
    record "vault_hot_md" "FAIL" "brain/hot.md not found"
fi

# ------------------------------------------------------------------
# Test 3: Runtime permissions
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
# Test 4: .env permissions
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
# Test 5: Delivery (if enabled)
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
# Test 6: Proxy prerequisites (if proxies configured)
# ------------------------------------------------------------------
CLI_PROXY_ENABLED=$(python3 -c "
import yaml
with open('setup_answers.yaml') as f:
    data = yaml.safe_load(f)
for p in data.get('providers', {}).get('cli_proxy', {}).get('enabled', []):
    print(p)
" 2>/dev/null || true)

if [[ -n "$CLI_PROXY_ENABLED" ]]; then
    if command -v llm-cli-proxy >/dev/null 2>&1; then
        record "llm_cli_proxy_installed" "PASS" "llm-cli-proxy found in PATH"
    else
        record "llm_cli_proxy_installed" "WARN" "llm-cli-proxy not found. Run: npm install -g llm-cli-proxy"
    fi

    if echo "$CLI_PROXY_ENABLED" | grep -q "claude"; then
        if command -v claude >/dev/null 2>&1; then
            record "claude_cli_installed" "PASS" "claude CLI found"
        else
            record "claude_cli_installed" "FAIL" "claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
        fi
    fi

    if echo "$CLI_PROXY_ENABLED" | grep -q "gemini"; then
        if command -v gemini >/dev/null 2>&1; then
            record "gemini_cli_installed" "PASS" "gemini CLI found"
        else
            record "gemini_cli_installed" "FAIL" "gemini CLI not found. Install: npm install -g @google/gemini-cli"
        fi
    fi
fi

# ------------------------------------------------------------------
# Test 7: Proxy binding security (if proxies configured)
# ------------------------------------------------------------------
if [[ -n "$CLI_PROXY_ENABLED" ]]; then
    if command -v ss &>/dev/null; then
        info "Checking proxy binding security..."
        insecure_bindings=$(ss -tlnp 2>/dev/null | grep -E ':(3456|3457|3458|3459)' | grep -v '127.0.0.1' | grep '\*:' || true)
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
