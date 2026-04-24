#!/usr/bin/env bash
# Squad-Mind system health check
# Usage: ./scripts/health-check.sh [--json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$(dirname "$SCRIPT_DIR")"

JSON_MODE=false
if [[ "${1:-}" == "--json" ]]; then
    JSON_MODE=true
fi

# ------------------------------------------------------------------
# Load config
# ------------------------------------------------------------------
VAULT_PATH="$HOME/Documents/Home-Brain"
HERMES_HOME="$HOME/.hermes"

if [[ -f "$SETUP_DIR/setup_answers.yaml" ]]; then
    VAULT_PATH=$(python3 -c "
import yaml
with open('$SETUP_DIR/setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print(data.get('paths', {}).get('vault', '$VAULT_PATH'))
" 2>/dev/null)
    HERMES_HOME=$(python3 -c "
import yaml
with open('$SETUP_DIR/setup_answers.yaml') as f:
    data = yaml.safe_load(f)
print(data.get('paths', {}).get('hermes_home', '$HERMES_HOME'))
" 2>/dev/null)
fi
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
HERMES_HOME="${HERMES_HOME/#\~/$HOME}"

# ------------------------------------------------------------------
# Results collector
# ------------------------------------------------------------------
declare -a RESULT_NAMES
declare -a RESULT_STATUSES
declare -a RESULT_DETAILS
OVERALL="PASS"

record() {
    local name="$1"
    local status="$2"
    local detail="${3:-}"
    RESULT_NAMES+=("$name")
    RESULT_STATUSES+=("$status")
    RESULT_DETAILS+=("$detail")
    if [[ "$status" == "FAIL" ]]; then
        OVERALL="FAIL"
    fi
}

# ------------------------------------------------------------------
# Proxy checks
# ------------------------------------------------------------------
for port in 3456 3457 3458 3459; do
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port/health" 2>/dev/null || echo "down")
    if [[ "$http_status" == "200" ]]; then
        record "proxy_$port" "PASS" "Healthy on port $port"
    else
        record "proxy_$port" "WARN" "Port $port: $http_status"
    fi
done

# ------------------------------------------------------------------
# Disk check
# ------------------------------------------------------------------
if command -v df &>/dev/null; then
    disk_avail=$(df -h "$HOME" | tail -1 | awk '{print $4}')
    record "disk_free" "PASS" "$disk_avail available in \$HOME"
else
    record "disk_free" "WARN" "df not available"
fi

# ------------------------------------------------------------------
# Vault check
# ------------------------------------------------------------------
if [[ -f "$VAULT_PATH/brain/hot.md" ]]; then
    record "vault_brain" "PASS" "Vault present at $VAULT_PATH"
else
    record "vault_brain" "FAIL" "brain/hot.md missing at $VAULT_PATH"
fi

# ------------------------------------------------------------------
# Hermes runtime check
# ------------------------------------------------------------------
if [[ -d "$HERMES_HOME" ]]; then
    perms=$(stat -c '%a' "$HERMES_HOME" 2>/dev/null || stat -f '%Lp' "$HERMES_HOME")
    if [[ "$perms" == "700" ]]; then
        record "hermes_runtime" "PASS" "$HERMES_HOME exists with 700"
    else
        record "hermes_runtime" "WARN" "$HERMES_HOME exists but perms are $perms (expected 700)"
    fi
else
    record "hermes_runtime" "FAIL" "$HERMES_HOME not found"
fi

# ------------------------------------------------------------------
# .env check
# ------------------------------------------------------------------
if [[ -f "$SETUP_DIR/.env" ]]; then
    env_perms=$(stat -c '%a' "$SETUP_DIR/.env" 2>/dev/null || stat -f '%Lp' "$SETUP_DIR/.env")
    if [[ "$env_perms" == "600" ]]; then
        record "env_permissions" "PASS" ".env permissions are 600"
    else
        record "env_permissions" "WARN" ".env permissions are $env_perms (expected 600)"
    fi
else
    record "env_permissions" "FAIL" ".env not found"
fi

# ------------------------------------------------------------------
# Output
# ------------------------------------------------------------------
if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"overall\": \"$OVERALL\","
    echo "  \"checks\": ["
    for i in "${!RESULT_NAMES[@]}"; do
        if [[ $i -gt 0 ]]; then echo ","; fi
        echo -n "    {\"name\":\"${RESULT_NAMES[$i]}\",\"status\":\"${RESULT_STATUSES[$i]}\",\"detail\":\"${RESULT_DETAILS[$i]}\"}"
    done
    echo ""
    echo "  ]"
    echo "}"
else
    echo "=== Squad-Mind Health Check ==="
    echo ""
    for i in "${!RESULT_NAMES[@]}"; do
        status="${RESULT_STATUSES[$i]}"
        if [[ "$status" == "PASS" ]]; then
            icon="✅"
        elif [[ "$status" == "WARN" ]]; then
            icon="⚠️"
        else
            icon="❌"
        fi
        printf "%-25s %s %s\n" "${RESULT_NAMES[$i]}:" "$icon" "${RESULT_DETAILS[$i]}"
    done
    echo ""
    echo "Overall: $OVERALL"
fi

if [[ "$OVERALL" == "FAIL" ]]; then
    exit 1
fi
