#!/usr/bin/env zsh
# version.sh - SQUAD MCP Server version and system information
# Converted from: squad-mcp-server/tools/version.py
# Pattern: $PATTERNSJSON#script_over_mcp

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
SQUAD_VERSION="5.5.5"
SQUAD_UPDATED="2026-01-15"
SQUAD_AUTHOR="BeehiveInnovations"
SQUAD_REPO="https://github.com/BeehiveInnovations/squad-mcp-server"
SQUAD_CONFIG_URL="https://raw.githubusercontent.com/BeehiveInnovations/squad-mcp-server/main/config.py"

REGISTRY_FILE="${CURREGISTRY:-$HOME/.cursor/registry}/squad/models.json"

# ============================================================================
# FUNCTIONS
# ============================================================================

usage() {
    cat >&2 << 'EOF'
Usage: version.sh [OPTIONS]

Display SQUAD tools version and system information.

Options:
  -j, --json        Output as JSON only (default)
  -p, --pretty      Pretty print with markdown
  -c, --check       Check for updates from GitHub
  -h, --help        Show this help

Examples:
  version.sh                    # JSON output
  version.sh --pretty           # Markdown output
  version.sh --check            # Check for updates
EOF
    exit 1
}

parse_version() {
    local ver="$1"
    echo "$ver" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}'
}

fetch_github_version() {
    local response
    response=$(curl -sS --connect-timeout 10 "$SQUAD_CONFIG_URL" 2>/dev/null) || return 1
    
    local remote_version remote_updated
    remote_version=$(echo "$response" | grep -o '__version__.*=.*"[^"]*"' | grep -o '"[^"]*"' | tr -d '"')
    remote_updated=$(echo "$response" | grep -o '__updated__.*=.*"[^"]*"' | grep -o '"[^"]*"' | tr -d '"')
    
    [[ -n "$remote_version" ]] && echo "${remote_version}|${remote_updated:-Unknown}"
}

get_provider_status() {
    local providers=()
    
    # Check Anthropic
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        providers+=("anthropic:configured")
    else
        providers+=("anthropic:not_configured")
    fi
    
    # Check OpenAI
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        providers+=("openai:configured")
    else
        providers+=("openai:not_configured")
    fi
    
    # Check Gemini
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
        providers+=("gemini:configured")
    else
        providers+=("gemini:not_configured")
    fi
    
    # Check OpenRouter
    if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
        providers+=("openrouter:configured")
    else
        providers+=("openrouter:not_configured")
    fi
    
    # Check Ollama
    if curl -s --connect-timeout 2 "${OLLAMA_HOST:-http://localhost:11434}/api/tags" >/dev/null 2>&1; then
        providers+=("ollama:running")
    else
        providers+=("ollama:not_running")
    fi
    
    printf '%s\n' "${providers[@]}"
}

get_ollama_models() {
    local models
    models=$(curl -s --connect-timeout 2 "${OLLAMA_HOST:-http://localhost:11434}/api/tags" 2>/dev/null | jq -r '.models[].name' 2>/dev/null) || echo ""
    echo "$models"
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
OUTPUT_FORMAT="json"
CHECK_UPDATES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -j|--json) OUTPUT_FORMAT="json"; shift ;;
        -p|--pretty) OUTPUT_FORMAT="pretty"; shift ;;
        -c|--check) CHECK_UPDATES=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# ============================================================================
# GATHER INFORMATION
# ============================================================================

# System info
PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "not installed")
PLATFORM="$(uname -s) $(uname -r)"
HOSTNAME=$(hostname)
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Provider status
PROVIDER_STATUS=$(get_provider_status)

# Ollama models
OLLAMA_MODELS=$(get_ollama_models)
OLLAMA_MODEL_COUNT=$(echo "$OLLAMA_MODELS" | grep -c . || echo "0")

# Registry info
REGISTRY_EXISTS=false
REGISTRY_MODEL_COUNT=0
if [[ -f "$REGISTRY_FILE" ]]; then
    REGISTRY_EXISTS=true
    REGISTRY_MODEL_COUNT=$(jq '[.providers[].models | keys | length] | add' "$REGISTRY_FILE" 2>/dev/null || echo "0")
fi

# Update check
UPDATE_STATUS="not_checked"
REMOTE_VERSION=""
REMOTE_UPDATED=""
if [[ "$CHECK_UPDATES" == true ]]; then
    github_info=$(fetch_github_version 2>/dev/null || echo "")
    if [[ -n "$github_info" ]]; then
        REMOTE_VERSION="${github_info%%|*}"
        REMOTE_UPDATED="${github_info##*|}"
        
        current_num=$(parse_version "$SQUAD_VERSION")
        remote_num=$(parse_version "$REMOTE_VERSION")
        
        if [[ "$current_num" -lt "$remote_num" ]]; then
            UPDATE_STATUS="update_available"
        elif [[ "$current_num" -eq "$remote_num" ]]; then
            UPDATE_STATUS="up_to_date"
        else
            UPDATE_STATUS="development"
        fi
    else
        UPDATE_STATUS="check_failed"
    fi
fi

# ============================================================================
# OUTPUT
# ============================================================================

if [[ "$OUTPUT_FORMAT" == "pretty" ]]; then
    cat << EOF
# SQUAD Tools Version

## Server Information
**Current Version**: ${SQUAD_VERSION}
**Last Updated**: ${SQUAD_UPDATED}
**Author**: ${SQUAD_AUTHOR}
**Repository**: ${SQUAD_REPO}

## System Information
**Platform**: ${PLATFORM}
**Hostname**: ${HOSTNAME}
**Python**: ${PYTHON_VERSION}
**Script Location**: ${SCRIPT_DIR}

## Providers
EOF
    
    echo "$PROVIDER_STATUS" | while IFS=: read -r prov stat; do
        if [[ "$stat" == "configured" || "$stat" == "running" ]]; then
            echo "- **${prov}**: ✅ ${stat}"
        else
            echo "- **${prov}**: ❌ ${stat}"
        fi
    done
    
    echo ""
    echo "## Ollama Models (${OLLAMA_MODEL_COUNT} installed)"
    if [[ -n "$OLLAMA_MODELS" ]]; then
        echo "$OLLAMA_MODELS" | while read -r model; do
            echo "- ${model}"
        done
    else
        echo "- No models installed or Ollama not running"
    fi
    
    if [[ "$CHECK_UPDATES" == true ]]; then
        echo ""
        echo "## Update Status"
        case "$UPDATE_STATUS" in
            update_available)
                echo "🚀 **UPDATE AVAILABLE!**"
                echo "Your version \`${SQUAD_VERSION}\` → Latest \`${REMOTE_VERSION}\`"
                ;;
            up_to_date)
                echo "✅ **UP TO DATE**"
                ;;
            development)
                echo "🔬 **DEVELOPMENT VERSION**"
                echo "Your version \`${SQUAD_VERSION}\` is ahead of \`${REMOTE_VERSION}\`"
                ;;
            check_failed)
                echo "❌ **Could not check for updates**"
                ;;
        esac
    fi
else
    # JSON output
    providers_json=$(echo "$PROVIDER_STATUS" | jq -R -s 'split("\n") | map(select(length > 0)) | map(split(":") | {(.[0]): .[1]}) | add')
    ollama_models_json=$(echo "$OLLAMA_MODELS" | jq -R -s 'split("\n") | map(select(length > 0))')
    
    jq -nc \
        --arg version "$SQUAD_VERSION" \
        --arg updated "$SQUAD_UPDATED" \
        --arg author "$SQUAD_AUTHOR" \
        --arg repo "$SQUAD_REPO" \
        --arg platform "$PLATFORM" \
        --arg hostname "$HOSTNAME" \
        --arg python "$PYTHON_VERSION" \
        --arg script_dir "$SCRIPT_DIR" \
        --argjson providers "$providers_json" \
        --argjson ollama_models "$ollama_models_json" \
        --argjson ollama_count "$OLLAMA_MODEL_COUNT" \
        --argjson registry_count "$REGISTRY_MODEL_COUNT" \
        --arg update_status "$UPDATE_STATUS" \
        --arg remote_version "$REMOTE_VERSION" \
        --arg remote_updated "$REMOTE_UPDATED" \
        '{
            "status": "success",
            "content": {
                "server": {
                    "version": $version,
                    "updated": $updated,
                    "author": $author,
                    "repository": $repo
                },
                "system": {
                    "platform": $platform,
                    "hostname": $hostname,
                    "python_version": $python,
                    "script_location": $script_dir
                },
                "providers": $providers,
                "ollama": {
                    "models": $ollama_models,
                    "count": $ollama_count
                },
                "registry_model_count": $registry_count,
                "update_check": {
                    "status": $update_status,
                    "remote_version": $remote_version,
                    "remote_updated": $remote_updated
                }
            },
            "metadata": {
                "tool_name": "version",
                "server_version": $version
            }
        }'
fi
