#!/usr/bin/env zsh
# listmodels.sh - List available AI models by provider
# Converted from: squad-mcp-server/tools/listmodels.py
# Pattern: $PATTERNSJSON#script_over_mcp
# NOTE: This tool does NOT call AI - it reads from registry and checks providers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

# ============================================================================
# USAGE
# ============================================================================
usage() {
    cat >&2 << 'EOF'
Usage: listmodels.sh [OPTIONS]

List all available AI models organized by provider.

Options:
  -p, --provider PROV    Filter by provider: anthropic|openai|gemini|openrouter|ollama
  -j, --json             Output as JSON (default)
  --pretty               Pretty print with markdown
  -h, --help             Show this help

Examples:
  listmodels.sh                    # All providers
  listmodels.sh -p ollama          # Only Ollama models
  listmodels.sh --pretty           # Markdown output
EOF
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
FILTER_PROVIDER=""
OUTPUT_FORMAT="json"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--provider) FILTER_PROVIDER="$2"; shift 2 ;;
        -j|--json) OUTPUT_FORMAT="json"; shift ;;
        --pretty) OUTPUT_FORMAT="pretty"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# ============================================================================
# GATHER MODEL INFORMATION
# ============================================================================

# Check provider status
check_provider() {
    local provider="$1"
    case "$provider" in
        anthropic) [[ -n "${ANTHROPIC_API_KEY:-}" ]] && echo "configured" || echo "not_configured" ;;
        openai) [[ -n "${OPENAI_API_KEY:-}" ]] && echo "configured" || echo "not_configured" ;;
        gemini) [[ -n "${GEMINI_API_KEY:-}" ]] && echo "configured" || echo "not_configured" ;;
        openrouter) [[ -n "${OPENROUTER_API_KEY:-}" ]] && echo "configured" || echo "not_configured" ;;
        ollama) curl -s --connect-timeout 2 "${OLLAMA_HOST:-http://localhost:11434}/api/tags" >/dev/null 2>&1 && echo "running" || echo "not_running" ;;
    esac
}

# Get Ollama models
get_ollama_models() {
    curl -s --connect-timeout 2 "${OLLAMA_HOST:-http://localhost:11434}/api/tags" 2>/dev/null | jq -r '.models[].name' 2>/dev/null || echo ""
}

# ============================================================================
# BUILD OUTPUT
# ============================================================================

if [[ "$OUTPUT_FORMAT" == "pretty" ]]; then
    echo "# Available AI Models"
    echo ""
    
    # Anthropic
    if [[ -z "$FILTER_PROVIDER" || "$FILTER_PROVIDER" == "anthropic" ]]; then
        prov_status=$(check_provider anthropic)
        echo "## Anthropic ($prov_status)"
        if [[ "$prov_status" == "configured" ]]; then
            echo "- claude-sonnet-4-20250514 (Claude Sonnet 4) - 200K context"
            echo "- claude-opus-4-20250514 (Claude Opus 4) - 200K context, extended reasoning"
        else
            echo "- Set ANTHROPIC_API_KEY to enable"
        fi
        echo ""
    fi
    
    # OpenAI
    if [[ -z "$FILTER_PROVIDER" || "$FILTER_PROVIDER" == "openai" ]]; then
        prov_status=$(check_provider openai)
        echo "## OpenAI ($prov_status)"
        if [[ "$prov_status" == "configured" ]]; then
            echo "- gpt-4o - 128K context"
            echo "- gpt-4o-mini - 128K context, fast"
            echo "- o1 - 200K context, reasoning"
            echo "- o3-mini - 200K context, reasoning"
        else
            echo "- Set OPENAI_API_KEY to enable"
        fi
        echo ""
    fi
    
    # Gemini
    if [[ -z "$FILTER_PROVIDER" || "$FILTER_PROVIDER" == "gemini" ]]; then
        prov_status=$(check_provider gemini)
        echo "## Google Gemini ($prov_status)"
        if [[ "$prov_status" == "configured" ]]; then
            echo "- gemini-2.0-flash - 1M context"
            echo "- gemini-2.0-flash-thinking-exp - 1M context, reasoning"
        else
            echo "- Set GEMINI_API_KEY to enable"
        fi
        echo ""
    fi
    
    # OpenRouter
    if [[ -z "$FILTER_PROVIDER" || "$FILTER_PROVIDER" == "openrouter" ]]; then
        prov_status=$(check_provider openrouter)
        echo "## OpenRouter ($prov_status)"
        if [[ "$prov_status" == "configured" ]]; then
            echo "- anthropic/claude-sonnet-4"
            echo "- google/gemini-2.0-flash-001"
            echo "- deepseek/deepseek-r1"
            echo "- (many more via openrouter.ai)"
        else
            echo "- Set OPENROUTER_API_KEY to enable"
        fi
        echo ""
    fi
    
    # Ollama
    if [[ -z "$FILTER_PROVIDER" || "$FILTER_PROVIDER" == "ollama" ]]; then
        prov_status=$(check_provider ollama)
        echo "## Ollama - Local Models ($prov_status)"
        if [[ "$prov_status" == "running" ]]; then
            models=$(get_ollama_models)
            if [[ -n "$models" ]]; then
                echo "$models" | while read -r mdl; do
                    echo "- $mdl"
                done
            else
                echo "- No models installed. Run: ollama pull qwen2.5-coder:7b"
            fi
        else
            echo "- Ollama not running. Start with: ollama serve"
        fi
        echo ""
    fi
    
    echo "## Aliases"
    echo "- claude → claude-sonnet-4-20250514"
    echo "- gpt → gpt-4o"
    echo "- gemini → gemini-2.0-flash"
    echo "- qwen → qwen2.5-coder:7b"
    echo "- local → qwen2.5-coder:7b"
else
    # JSON output
    ollama_models=$(get_ollama_models | jq -R -s 'split("\n") | map(select(length > 0))')
    
    jq -nc \
        --arg anthropic_status "$(check_provider anthropic)" \
        --arg openai_status "$(check_provider openai)" \
        --arg gemini_status "$(check_provider gemini)" \
        --arg openrouter_status "$(check_provider openrouter)" \
        --arg ollama_status "$(check_provider ollama)" \
        --argjson ollama_models "$ollama_models" \
        '{
            "status": "success",
            "providers": {
                "anthropic": {
                    "status": $anthropic_status,
                    "models": ["claude-sonnet-4-20250514", "claude-opus-4-20250514"]
                },
                "openai": {
                    "status": $openai_status,
                    "models": ["gpt-4o", "gpt-4o-mini", "o1", "o3-mini"]
                },
                "gemini": {
                    "status": $gemini_status,
                    "models": ["gemini-2.0-flash", "gemini-2.0-flash-thinking-exp"]
                },
                "openrouter": {
                    "status": $openrouter_status,
                    "models": ["anthropic/claude-sonnet-4", "google/gemini-2.0-flash-001", "deepseek/deepseek-r1"]
                },
                "ollama": {
                    "status": $ollama_status,
                    "models": $ollama_models
                }
            },
            "aliases": {
                "claude": "claude-sonnet-4-20250514",
                "opus": "claude-opus-4-20250514",
                "gpt": "gpt-4o",
                "gemini": "gemini-2.0-flash",
                "qwen": "qwen2.5-coder:7b",
                "local": "qwen2.5-coder:7b"
            },
            "metadata": {
                "tool_name": "listmodels"
            }
        }'
fi
