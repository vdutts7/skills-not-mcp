#!/usr/bin/env zsh
# _base.sh - Shared functions for SQUAD tools
# Pattern: $PATTERNSJSON#script_over_mcp
# All SQUAD AI tools source this file for common functionality

# ============================================================================
# CONFIGURATION
# ============================================================================
SQUAD_REGISTRY="${SQUAD_REGISTRY:-${0:A:h}/../registry/models.json}"
SQUAD_CONV_DIR="${TMPDIR:-/tmp}/squad-conversations"
mkdir -p "$SQUAD_CONV_DIR"

# Source environment
[[ -f "${CURENV:-$HOME/.cursor/.env}" ]] && source "${CURENV:-$HOME/.cursor/.env}"

# ============================================================================
# PROVIDER ENABLED CHECK (reads from models.json)
# ============================================================================
is_provider_enabled() {
    local provider="$1"
    if [[ -f "$SQUAD_REGISTRY" ]]; then
        local enabled=$(jq -r ".enabled_providers.${provider}" "$SQUAD_REGISTRY" 2>/dev/null)
        # If key doesn't exist (null), default to enabled
        [[ "$enabled" == "null" || "$enabled" == "true" ]]
    else
        return 0  # Default to enabled if no registry
    fi
}

get_fallback_chain() {
    if [[ -f "$SQUAD_REGISTRY" ]]; then
        jq -r '.fallback_chain // ["anthropic", "cerebras", "ollama"] | .[]' "$SQUAD_REGISTRY" 2>/dev/null
    else
        echo "anthropic"
        echo "cerebras"
        echo "ollama"
    fi
}

get_default_model_for_provider() {
    local provider="$1"
    case "$provider" in
        anthropic) echo "claude-sonnet-4-20250514" ;;
        cerebras) echo "llama-3.3-70b" ;;
        ollama) echo "qwen2.5-coder:7b" ;;
        openai) echo "gpt-4o" ;;
        gemini) echo "gemini-2.0-flash" ;;
        openrouter) echo "anthropic/claude-sonnet-4" ;;
        *) echo "claude-sonnet-4-20250514" ;;
    esac
}

# ============================================================================
# PROVIDER DETECTION
# ============================================================================
detect_provider() {
    local model="$1"
    case "$model" in
        claude*|opus*|sonnet*|haiku*) echo "anthropic" ;;
        gpt-*|o1*|o3*) echo "openai" ;;
        gemini*) echo "gemini" ;;
        llama-3.3-70b|llama3.1-8b|qwen-3-32b|qwen-3-235b-a22b-instruct-2507|gpt-oss-120b|zai-glm-4.7) echo "cerebras" ;;  # Cerebras models (exact match)
        */*) echo "openrouter" ;;  # Contains slash = OpenRouter format
        qwen*|llama*|mistral*|codellama*|deepseek*|glm*|moondream*|nomic*|phi*|starcoder*|wizardcoder*|magicoder*)
            echo "ollama" ;;
        *) echo "anthropic" ;;  # Default to anthropic
    esac
}

# ============================================================================
# CONVERSATION MEMORY
# ============================================================================
load_conversation() {
    local id="$1"
    local file="$SQUAD_CONV_DIR/${id}.json"
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo "[]"
    fi
}

save_conversation() {
    local id="$1"
    local messages="$2"
    echo "$messages" > "$SQUAD_CONV_DIR/${id}.json"
}

# ============================================================================
# FILE CONTEXT BUILDER
# ============================================================================
build_file_context() {
    local -a files=("$@")
    local ctx=""
    local line_num=1
    
    for f in "${files[@]}"; do
        f="${f/#\~/$HOME}"
        [[ -f "$f" ]] || { echo "Error: file not found: $f" >&2; return 1; }
        ctx+="=== FILE: $f ===\n"
        while IFS= read -r line || [[ -n "$line" ]]; do
            ctx+=$(printf "%5d│ %s\n" "$line_num" "$line")
            ((line_num++))
        done < "$f"
        ctx+="\n=== END FILE ===\n\n"
        line_num=1
    done
    printf '%s' "$ctx"
}

# ============================================================================
# API CALLERS
# ============================================================================

# Anthropic API
call_anthropic() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="${3:-claude-sonnet-4-20250514}"
    local temperature="${4:-0.7}"
    local continuation_id="${5:-}"
    
    local api_key="${ANTHROPIC_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"ANTHROPIC_API_KEY not set"}'; return 1; }
    
    # Build messages
    local messages="[]"
    if [[ -n "$continuation_id" ]]; then
        messages=$(load_conversation "$continuation_id")
    fi
    messages=$(printf '%s' "$messages" | jq --arg content "$user_prompt" '. + [{"role":"user","content":$content}]')
    
    local payload=$(jq -nc \
        --arg model "$model" \
        --arg system "$system_prompt" \
        --argjson messages "$messages" \
        --argjson temp "$temperature" \
        '{model:$model,max_tokens:8192,temperature:$temp,system:$system,messages:$messages}')
    
    local raw_response=$(curl -sS "https://api.anthropic.com/v1/messages" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    # Sanitize control chars
    local response=$(printf '%s' "$raw_response" | tr -d '\000-\010\013\014\016-\037')
    
    if printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(printf '%s' "$response" | jq -r '.error.message // .error.type // "Unknown error"')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(printf '%s' "$response" | jq -r '.content[0].text // empty')
    local model_used=$(printf '%s' "$response" | jq -r '.model // empty')
    local input_tokens=$(printf '%s' "$response" | jq -r '.usage.input_tokens // 0')
    local output_tokens=$(printf '%s' "$response" | jq -r '.usage.output_tokens // 0')
    
    # Save conversation
    if [[ -n "$continuation_id" ]]; then
        messages=$(printf '%s' "$messages" | jq --arg content "$content" '. + [{"role":"assistant","content":$content}]')
        save_conversation "$continuation_id" "$messages"
    fi
    
    echo "$content"
    return 0
}

# Ollama API
call_ollama() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="${3:-qwen2.5-coder:7b}"
    local temperature="${4:-0.7}"
    local continuation_id="${5:-}"
    
    local ollama_url="${OLLAMA_HOST:-http://localhost:11434}"
    
    if ! curl -s --connect-timeout 2 "$ollama_url/api/tags" >/dev/null 2>&1; then
        echo '{"status":"error","content":"Ollama not running. Start with: ollama serve"}'
        return 1
    fi
    
    # Build messages with system prompt
    local messages="[]"
    if [[ -n "$continuation_id" ]]; then
        messages=$(load_conversation "$continuation_id")
    fi
    
    # Add system message if not already present
    if [[ $(printf '%s' "$messages" | jq 'length') -eq 0 ]]; then
        messages=$(jq -nc --arg sys "$system_prompt" '[{"role":"system","content":$sys}]')
    fi
    messages=$(printf '%s' "$messages" | jq --arg content "$user_prompt" '. + [{"role":"user","content":$content}]')
    
    local payload=$(jq -nc \
        --arg model "$model" \
        --argjson messages "$messages" \
        --argjson temp "$temperature" \
        '{model:$model,stream:false,options:{temperature:$temp},messages:$messages}')
    
    local raw_response=$(curl -sS "$ollama_url/api/chat" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local response=$(printf '%s' "$raw_response" | tr -d '\000-\010\013\014\016-\037')
    
    if printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(printf '%s' "$response" | jq -r '.error // "Unknown error"')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(printf '%s' "$response" | jq -r '.message.content // empty')
    
    # Save conversation
    if [[ -n "$continuation_id" ]]; then
        local save_messages=$(printf '%s' "$messages" | jq 'del(.[0])')  # Remove system for storage
        save_messages=$(printf '%s' "$save_messages" | jq --arg content "$content" '. + [{"role":"assistant","content":$content}]')
        save_conversation "$continuation_id" "$save_messages"
    fi
    
    echo "$content"
    return 0
}

# OpenAI API
call_openai() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="${3:-gpt-4o}"
    local temperature="${4:-0.7}"
    local continuation_id="${5:-}"
    
    local api_key="${OPENAI_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"OPENAI_API_KEY not set"}'; return 1; }
    
    local messages="[]"
    if [[ -n "$continuation_id" ]]; then
        messages=$(load_conversation "$continuation_id")
    fi
    
    if [[ $(printf '%s' "$messages" | jq 'length') -eq 0 ]]; then
        messages=$(jq -nc --arg sys "$system_prompt" '[{"role":"system","content":$sys}]')
    fi
    messages=$(printf '%s' "$messages" | jq --arg content "$user_prompt" '. + [{"role":"user","content":$content}]')
    
    local payload=$(jq -nc \
        --arg model "$model" \
        --argjson messages "$messages" \
        --argjson temp "$temperature" \
        '{model:$model,messages:$messages,temperature:$temp}')
    
    local raw_response=$(curl -sS "https://api.openai.com/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local response=$(printf '%s' "$raw_response" | tr -d '\000-\010\013\014\016-\037')
    
    if printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(printf '%s' "$response" | jq -r '.error.message // "Unknown error"')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(printf '%s' "$response" | jq -r '.choices[0].message.content // empty')
    
    if [[ -n "$continuation_id" ]]; then
        local save_messages=$(printf '%s' "$messages" | jq 'del(.[0])')
        save_messages=$(printf '%s' "$save_messages" | jq --arg content "$content" '. + [{"role":"assistant","content":$content}]')
        save_conversation "$continuation_id" "$save_messages"
    fi
    
    echo "$content"
    return 0
}

# Gemini API
call_gemini() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="${3:-gemini-2.0-flash}"
    local temperature="${4:-0.7}"
    
    local api_key="${GEMINI_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"GEMINI_API_KEY not set"}'; return 1; }
    
    local url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${api_key}"
    
    local full_prompt="${system_prompt}\n\n${user_prompt}"
    local payload=$(jq -nc \
        --arg text "$full_prompt" \
        --argjson temp "$temperature" \
        '{contents:[{parts:[{text:$text}]}],generationConfig:{temperature:$temp}}')
    
    local raw_response=$(curl -sS "$url" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local response=$(printf '%s' "$raw_response" | tr -d '\000-\010\013\014\016-\037')
    
    if printf '%s' "$response" | grep -q '"error"'; then
        local err=$(printf '%s' "$response" | grep -o '"message":"[^"]*"' | head -1 | sed 's/"message":"//;s/"$//')
        jq -nc --arg e "${err:-Unknown Gemini error}" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text // empty')
    echo "$content"
    return 0
}

# OpenRouter API
call_openrouter() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="${3:-anthropic/claude-sonnet-4}"
    local temperature="${4:-0.7}"
    
    local api_key="${OPENROUTER_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"OPENROUTER_API_KEY not set"}'; return 1; }
    
    local messages=$(jq -nc \
        --arg sys "$system_prompt" \
        --arg user "$user_prompt" \
        '[{"role":"system","content":$sys},{"role":"user","content":$user}]')
    
    local payload=$(jq -nc \
        --arg model "$model" \
        --argjson messages "$messages" \
        --argjson temp "$temperature" \
        '{model:$model,messages:$messages,temperature:$temp}')
    
    local raw_response=$(curl -sS "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local response=$(printf '%s' "$raw_response" | tr -d '\000-\010\013\014\016-\037')
    
    if printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(printf '%s' "$response" | jq -r '.error.message // "Unknown error"')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(printf '%s' "$response" | jq -r '.choices[0].message.content // empty')
    echo "$content"
    return 0
}

# Cerebras API (OpenAI-compatible)
call_cerebras() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="${3:-llama-3.3-70b}"
    local temperature="${4:-0.7}"
    
    local api_key="${CEREBRAS_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"CEREBRAS_API_KEY not set"}'; return 1; }
    
    local messages=$(jq -nc \
        --arg sys "$system_prompt" \
        --arg user "$user_prompt" \
        '[{"role":"system","content":$sys},{"role":"user","content":$user}]')
    
    local payload=$(jq -nc \
        --arg model "$model" \
        --argjson messages "$messages" \
        --argjson temp "$temperature" \
        '{model:$model,messages:$messages,temperature:$temp}')
    
    local raw_response=$(curl -sS "https://api.cerebras.ai/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local response=$(printf '%s' "$raw_response" | tr -d '\000-\010\013\014\016-\037')
    
    if printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(printf '%s' "$response" | jq -r '.error.message // "Unknown error"')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(printf '%s' "$response" | jq -r '.choices[0].message.content // empty')
    echo "$content"
    return 0
}

# ============================================================================
# UNIFIED CALLER
# ============================================================================
call_model() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="$3"
    local temperature="${4:-0.7}"
    local continuation_id="${5:-}"
    
    local provider=$(detect_provider "$model")
    
    case "$provider" in
        anthropic)
            call_anthropic "$system_prompt" "$user_prompt" "$model" "$temperature" "$continuation_id"
            ;;
        ollama)
            call_ollama "$system_prompt" "$user_prompt" "$model" "$temperature" "$continuation_id"
            ;;
        openai)
            call_openai "$system_prompt" "$user_prompt" "$model" "$temperature" "$continuation_id"
            ;;
        gemini)
            call_gemini "$system_prompt" "$user_prompt" "$model" "$temperature"
            ;;
        openrouter)
            call_openrouter "$system_prompt" "$user_prompt" "$model" "$temperature"
            ;;
        cerebras)
            call_cerebras "$system_prompt" "$user_prompt" "$model" "$temperature"
            ;;
        *)
            echo '{"status":"error","content":"Unknown provider"}'
            return 1
            ;;
    esac
}

# ============================================================================
# OUTPUT FORMATTER
# ============================================================================
format_output() {
    local content="$1"
    local tool_name="$2"
    local model="$3"
    local provider="$4"
    local extra_metadata="${5:-\{\}}"
    
    jq -nc \
        --arg content "$content" \
        --arg tool "$tool_name" \
        --arg model "$model" \
        --arg provider "$provider" \
        --argjson extra "$extra_metadata" \
        '{
            status: "success",
            content: $content,
            metadata: ({tool_name: $tool, model: $model, provider: $provider} + $extra)
        }'
}

format_error() {
    local error="$1"
    local tool_name="$2"
    
    jq -nc \
        --arg error "$error" \
        --arg tool "$tool_name" \
        '{status: "error", content: $error, metadata: {tool_name: $tool}}'
}
