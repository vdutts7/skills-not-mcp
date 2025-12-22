#!/usr/bin/env zsh
# demo.sh - Demonstrate SQUAD tools
# Run: ./demo.sh

set -uo pipefail

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/_base.sh" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo "${BLUE}║  SQUAD: Shell-native AI Tool Suite - Demo                  ║${NC}"
echo "${BLUE}║  Source: github.com/BeehiveInnovations/pal-mcp-server      ║${NC}"
echo "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check available providers
echo "${YELLOW}=== Available Providers ===${NC}"
echo ""

check_provider() {
    local name="$1"
    local env_var="$2"
    local value="${(P)env_var:-}"
    
    if [[ -n "$value" ]]; then
        echo "${GREEN}✓${NC} $name (${env_var} set)"
        return 0
    else
        echo "${RED}✗${NC} $name (${env_var} not set)"
        return 1
    fi
}

AVAILABLE_PROVIDERS=()
check_provider "Anthropic" "ANTHROPIC_API_KEY" && AVAILABLE_PROVIDERS+=("anthropic")
check_provider "Cerebras" "CEREBRAS_API_KEY" && AVAILABLE_PROVIDERS+=("cerebras")
check_provider "OpenAI" "OPENAI_API_KEY" && AVAILABLE_PROVIDERS+=("openai")
check_provider "Gemini" "GEMINI_API_KEY" && AVAILABLE_PROVIDERS+=("gemini")
check_provider "OpenRouter" "OPENROUTER_API_KEY" && AVAILABLE_PROVIDERS+=("openrouter")

# Check Ollama
if curl -s --connect-timeout 2 "http://localhost:11434/api/tags" >/dev/null 2>&1; then
    echo "${GREEN}✓${NC} Ollama (running at localhost:11434)"
    AVAILABLE_PROVIDERS+=("ollama")
else
    echo "${RED}✗${NC} Ollama (not running)"
fi

echo ""

if [[ ${#AVAILABLE_PROVIDERS[@]} -eq 0 ]]; then
    echo "${RED}No providers available. Set at least one API key or start Ollama.${NC}"
    exit 1
fi

echo "${YELLOW}=== Demo: chat.sh ===${NC}"
echo ""
echo "Command: ${GREEN}./chat.sh -m claude-sonnet-4-20250514 \"What is 2+2? One word.\"${NC}"
echo ""

# Pick first available provider
DEMO_PROVIDER="${AVAILABLE_PROVIDERS[1]}"
case "$DEMO_PROVIDER" in
    anthropic) DEMO_MODEL="claude-sonnet-4-20250514" ;;
    cerebras) DEMO_MODEL="llama-3.3-70b" ;;
    ollama) DEMO_MODEL="qwen2.5-coder:7b" ;;
    openai) DEMO_MODEL="gpt-4o" ;;
    gemini) DEMO_MODEL="gemini-2.0-flash" ;;
    openrouter) DEMO_MODEL="anthropic/claude-sonnet-4" ;;
esac

echo "Using: ${BLUE}$DEMO_PROVIDER${NC} with model ${BLUE}$DEMO_MODEL${NC}"
echo ""

# Run demo
RESPONSE=$("${SCRIPT_DIR}/chat.sh" -m "$DEMO_MODEL" "What is 2+2? Reply with just the number, nothing else." 2>&1) || true

# Parse response (SHELL-036: sanitize control chars, SHELL-037: use printf not echo)
CLEAN_RESPONSE=$(printf '%s' "$RESPONSE" | /usr/bin/tr -d '\000-\010\013\014\016-\037')
STATUS=$(printf '%s' "$CLEAN_RESPONSE" | /usr/bin/jq -r '.status // "unknown"' 2>/dev/null)

if [[ "$STATUS" == "success" ]]; then
    # Extract just the AI response (before the "---" separator)
    CONTENT=$(printf '%s' "$CLEAN_RESPONSE" | /usr/bin/jq -r '.content' 2>/dev/null | sed '/^---$/,$d' | head -5)
    MODEL_USED=$(printf '%s' "$CLEAN_RESPONSE" | /usr/bin/jq -r '.metadata.model // "unknown"')
    PROVIDER_USED=$(printf '%s' "$CLEAN_RESPONSE" | /usr/bin/jq -r '.metadata.provider // "unknown"')
    INPUT_TOKENS=$(printf '%s' "$CLEAN_RESPONSE" | /usr/bin/jq -r '.metadata.usage.input_tokens // "?"')
    OUTPUT_TOKENS=$(printf '%s' "$CLEAN_RESPONSE" | /usr/bin/jq -r '.metadata.usage.output_tokens // "?"')
    
    echo "${GREEN}Response:${NC} $CONTENT"
    echo ""
    echo "${BLUE}Model: $MODEL_USED | Provider: $PROVIDER_USED | Tokens: $INPUT_TOKENS in / $OUTPUT_TOKENS out${NC}"
elif [[ "$STATUS" == "error" ]]; then
    ERROR=$(printf '%s' "$CLEAN_RESPONSE" | /usr/bin/jq -r '.content // "Unknown error"' 2>/dev/null)
    echo "${RED}Error: $ERROR${NC}"
else
    echo "${RED}Unexpected response: $RESPONSE${NC}"
fi

echo ""
echo "${YELLOW}=== Token Overhead Comparison ===${NC}"
echo ""
echo "MCP (18 tools loaded):     ${RED}~12,500 tokens${NC} schema overhead"
echo "Shell (scripts on demand): ${GREEN}0 tokens${NC} until called"
echo ""
echo "${BLUE}See docs/TOKEN_ANALYSIS.md for detailed breakdown.${NC}"
echo ""

echo "${YELLOW}=== Available Tools ===${NC}"
echo ""
ls -1 "${SCRIPT_DIR}"/*.sh | grep -v "_base.sh\|demo.sh" | while read script; do
    name=$(basename "$script" .sh)
    echo "  ${GREEN}$name${NC}"
done

echo ""
echo "${BLUE}Run any tool with -h for usage: ./chat.sh -h${NC}"
