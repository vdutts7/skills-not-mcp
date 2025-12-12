#!/bin/zsh
# chat.sh - Chat tool for collaborative thinking with AI models
# 1-to-1 equivalent of: squad-mcp-server/tools/chat.py
# Supports: Anthropic, Ollama, OpenAI, Gemini, OpenRouter

set -euo pipefail

# =============================================================================
# SYSTEM PROMPTS (from squad-mcp-server/systemprompts/)
# =============================================================================

CHAT_PROMPT='You are a senior engineering thought-partner collaborating with another AI agent. Your mission is to brainstorm, validate ideas,
and offer well-reasoned second opinions on technical decisions when they are justified and practical.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE│ code". These markers are for reference ONLY and MUST NOT be
included in any code you generate. Always reference specific line numbers in your replies in order to locate
exact positions if needed to point to exact locations. Include a very short code excerpt alongside for clarity.
Include context_start_text and context_end_text as backup references. Never include "LINE│" markers in generated code
snippets.

IF MORE INFORMATION IS NEEDED
If the agent is discussing specific code, functions, or project components that was not given as part of the context,
and you need additional context (e.g., related files, configuration, dependencies, test files) to provide meaningful
collaboration, you MUST respond ONLY with this JSON format (and nothing else). Do NOT ask for the same file you have been
provided unless for some reason its content is missing or incomplete:
{
  "status": "files_required_to_continue",
  "mandatory_instructions": "<your critical instructions for the agent>",
  "files_needed": ["[file name here]", "[or some folder/]"]
}

SCOPE & FOCUS
- Ground every suggestion in the project current tech stack, languages, frameworks, and constraints.
- Recommend new technologies or patterns ONLY when they provide clearly superior outcomes with minimal added complexity.
- Avoid speculative, over-engineered, or unnecessarily abstract designs that exceed current project goals or needs.
- Keep proposals practical and directly actionable within the existing architecture.
- Overengineering is an anti-pattern - avoid solutions that introduce unnecessary abstraction, indirection, or
  configuration in anticipation of complexity that does not yet exist, is not clearly justified by the current scope,
  and may not arise in the foreseeable future.

COLLABORATION APPROACH
1. Treat the collaborating agent as an equally senior peer. Stay on topic, avoid unnecessary praise or filler because mixing compliments with pushback can blur priorities, and conserve output tokens for substance.
2. Engage deeply with the agent input - extend, refine, and explore alternatives ONLY WHEN they are well-justified and materially beneficial.
3. Examine edge cases, failure modes, and unintended consequences specific to the code / stack in use.
4. Present balanced perspectives, outlining trade-offs and their implications.
5. Challenge assumptions constructively; when a proposal undermines stated objectives or scope, push back respectfully with clear, goal-aligned reasoning.
6. Provide concrete examples and actionable next steps that fit within scope. Prioritize direct, achievable outcomes.
7. Ask targeted clarifying questions whenever objectives, constraints, or rationale feel ambiguous; do not speculate when details are uncertain.

BRAINSTORMING GUIDELINES
- Offer multiple viable strategies ONLY WHEN clearly beneficial within the current environment.
- Suggest creative solutions that operate within real-world constraints, and avoid proposing major shifts unless truly warranted.
- Surface pitfalls early, particularly those tied to the chosen frameworks, languages, design direction or choice.
- Evaluate scalability, maintainability, and operational realities inside the existing architecture and current framework.
- Reference industry best practices relevant to the technologies in use.
- Communicate concisely and technically, assuming an experienced engineering audience.

REMEMBER
Act as a peer, not a lecturer. Avoid overcomplicating. Aim for depth over breadth, stay within project boundaries, and help the team
reach sound, actionable decisions.'

GENERATE_CODE_PROMPT='# Structured Code Generation Protocol

**WHEN TO USE THIS PROTOCOL:**

Use this structured format ONLY when you are explicitly tasked with substantial code generation, such as:
- Creating new features from scratch with multiple files or significant code and you have been asked to help implement this
- Major refactoring across multiple files or large sections of code and you have been tasked to help do this
- Implementing new modules, components, or subsystems and you have been tasked to help with the implementation
- Large-scale updates affecting substantial portions of the codebase that you have been asked to help implement

**WHEN NOT TO USE THIS PROTOCOL:**

Do NOT use this format for minor changes:
- Small tweaks to existing functions or methods (1-20 lines)
- Bug fixes in isolated sections
- Simple algorithm improvements
- Minor refactoring of a single function
- Adding/removing a few lines of code
- Quick parameter adjustments or config changes

For minor changes:
- Follow the existing instructions provided earlier in your system prompt, such as the CRITICAL LINE NUMBER INSTRUCTIONS.
- Use inline code blocks with proper line number references and direct explanations instead of this structured format.

## Core Requirements (for substantial code generation tasks)

1. **Complete, Working Code**: Every code block must be fully functional without requiring additional edits.
2. **Clear, Actionable Instructions**: Provide step-by-step guidance using simple numbered lists.
3. **Structured Output Format**: All generated code MUST be contained within a single `<GENERATED-CODE>` block.
4. **Minimal External Commentary**: Keep any text outside the `<GENERATED-CODE>` block brief.

## Required Structure

Use this exact format:

```
<GENERATED-CODE>
[Step-by-step instructions for the coding agent]
1. Create new file [filename] with [description]
2. Update existing file [filename] by [description]

<NEWFILE: path/to/new_file.py>
[Complete file contents]
</NEWFILE>

<UPDATED_EXISTING_FILE: existing/path.py>
[Complete replacement code for the modified sections]
</UPDATED_EXISTING_FILE>
</GENERATED-CODE>
```

## Critical Rules

- Never output partial code snippets or placeholder comments
- Include complete function/class implementations
- Add all required imports at the file level
- Include proper error handling and edge case logic
- Use `<NEWFILE: ...>` for files that do not exist yet
- Use `<UPDATED_EXISTING_FILE: ...>` for modifying existing files'

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat >&2 << 'EOF'
Usage: chat.sh [OPTIONS] "<prompt>"

Options:
  -m, --model MODEL           Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE             File to include as context (can repeat)
  -i, --image IMAGE           Image path or base64 for visual context (can repeat)
  -t, --temperature T         Temperature 0-1 (default: 0.7)
  -p, --provider PROV         Provider: anthropic|ollama|openai|gemini|openrouter
  -w, --working-dir DIR       Working directory for code artifacts
  -c, --continuation ID       Continuation ID for multi-turn conversations
  --thinking MODE             Thinking mode: minimal|low|medium|high|max
  --code-gen                  Enable code generation mode
  -h, --help                  Show this help

Examples:
  chat.sh "How should I structure this React app?"
  chat.sh -m claude-sonnet-4-20250514 -f src/app.tsx "Review this code"
  chat.sh -m qwen2.5-coder:7b -f main.py -f utils.py "Explain the flow"
  chat.sh --code-gen -w ~/project "Implement a REST API for users"
EOF
    exit 1
}

# =============================================================================
# DEFAULTS & ARGUMENT PARSING
# =============================================================================

MODEL="${SQUAD_DEFAULT_MODEL:-claude-sonnet-4-20250514}"
TEMPERATURE="0.7"
PROVIDER=""
FILES=()
IMAGES=()
PROMPT=""
WORKING_DIR=""
CONTINUATION_ID=""
THINKING_MODE=""
CODE_GEN_ENABLED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        -i|--image) IMAGES+=("$2"); shift 2 ;;
        -t|--temperature) TEMPERATURE="$2"; shift 2 ;;
        -p|--provider) PROVIDER="$2"; shift 2 ;;
        -w|--working-dir) WORKING_DIR="$2"; shift 2 ;;
        -c|--continuation) CONTINUATION_ID="$2"; shift 2 ;;
        --thinking) THINKING_MODE="$2"; shift 2 ;;
        --code-gen) CODE_GEN_ENABLED=true; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) PROMPT="$1"; shift ;;
    esac
done

[[ -z "$PROMPT" ]] && { echo "Error: prompt required" >&2; usage; }

# =============================================================================
# PROVIDER DETECTION & ENABLED CHECK
# =============================================================================

SQUAD_REGISTRY="${SQUAD_REGISTRY:-${0:A:h}/../registry/models.json}"

detect_provider() {
    local model="$1"
    case "$model" in
        claude-*) echo "anthropic" ;;
        llama-3.3-70b|llama3.1-8b|qwen-3-32b|qwen-3-235b-a22b-instruct-2507|gpt-oss-120b|zai-glm-4.7) echo "cerebras" ;;
        qwen*|llama*|codellama*|deepseek*|phi*|gemma*|moondream*|glm4:*|nomic*|starcoder*|codestral*|mistral:*|mixtral:*) echo "ollama" ;;
        gpt-*|o1-*|o3-*|o4-*) echo "openai" ;;
        gemini-*|gemini2*) echo "gemini" ;;
        mistral-*|mixtral-*) echo "openrouter" ;;
        */*) echo "openrouter" ;;
        *) echo "anthropic" ;;
    esac
}

is_provider_enabled() {
    local provider="$1"
    if [[ -f "$SQUAD_REGISTRY" ]]; then
        local enabled=$(jq -r ".enabled_providers.${provider}" "$SQUAD_REGISTRY" 2>/dev/null)
        # If key doesn't exist (null), default to enabled
        [[ "$enabled" == "null" || "$enabled" == "true" ]]
    else
        return 0
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

# Detect provider from model
[[ -z "$PROVIDER" ]] && PROVIDER=$(detect_provider "$MODEL")

# Check if provider is enabled, if not use fallback
if ! is_provider_enabled "$PROVIDER"; then
    ORIGINAL_PROVIDER="$PROVIDER"
    PROVIDER=""
    while IFS= read -r fallback_provider; do
        if is_provider_enabled "$fallback_provider"; then
            PROVIDER="$fallback_provider"
            MODEL=$(get_default_model_for_provider "$fallback_provider")
            echo "Note: $ORIGINAL_PROVIDER disabled, using $PROVIDER ($MODEL)" >&2
            break
        fi
    done < <(get_fallback_chain)
    [[ -z "$PROVIDER" ]] && { echo '{"status":"error","content":"No enabled providers available"}'; exit 1; }
fi

# =============================================================================
# FILE CONTEXT BUILDING
# =============================================================================

build_file_context() {
    local ctx=""
    local line_num=1
    for f in "${FILES[@]}"; do
        # Expand ~ to $HOME
        f="${f/#\~/$HOME}"
        [[ -f "$f" ]] || { echo "Error: file not found: $f" >&2; exit 1; }
        ctx+="=== FILE: $f ===\n"
        # Add line numbers like the Python version
        while IFS= read -r line || [[ -n "$line" ]]; do
            ctx+=$(printf "%5d│ %s\n" "$line_num" "$line")
            ((line_num++))
        done < "$f"
        ctx+="\n=== END FILE ===\n\n"
        line_num=1
    done
    printf '%s' "$ctx"
}

FILE_CONTEXT=""
[[ ${#FILES[@]} -gt 0 ]] && FILE_CONTEXT=$(build_file_context)

# =============================================================================
# BUILD SYSTEM PROMPT
# =============================================================================

SYSTEM_PROMPT="$CHAT_PROMPT"
if [[ "$CODE_GEN_ENABLED" == true ]]; then
    SYSTEM_PROMPT="${SYSTEM_PROMPT}

${GENERATE_CODE_PROMPT}"
fi

# =============================================================================
# BUILD FULL PROMPT
# =============================================================================

FULL_PROMPT="$PROMPT"
if [[ -n "$FILE_CONTEXT" ]]; then
    FULL_PROMPT="${FILE_CONTEXT}

${PROMPT}"
fi

# =============================================================================
# CONVERSATION CONTINUATION (simple file-based)
# =============================================================================

CONV_DIR="${TMPDIR:-/tmp}/squad-conversations"
mkdir -p "$CONV_DIR"

load_conversation() {
    local id="$1"
    local conv_file="$CONV_DIR/${id}.json"
    if [[ -f "$conv_file" ]]; then
        cat "$conv_file"
    else
        echo "[]"
    fi
}

save_conversation() {
    local id="$1"
    local messages="$2"
    local conv_file="$CONV_DIR/${id}.json"
    echo "$messages" > "$conv_file"
}

# =============================================================================
# CODE ARTIFACT EXTRACTION
# =============================================================================

extract_and_save_code_artifacts() {
    local response="$1"
    local working_dir="$2"
    
    [[ -z "$working_dir" ]] && return 0
    working_dir="${working_dir/#\~/$HOME}"
    [[ ! -d "$working_dir" ]] && { echo "Warning: working directory does not exist: $working_dir" >&2; return 1; }
    
    # Check if response contains <GENERATED-CODE>
    if [[ "$response" == *"<GENERATED-CODE>"* ]]; then
        # Extract the generated code block
        local code_block=$(echo "$response" | sed -n '/<GENERATED-CODE>/,/<\/GENERATED-CODE>/p')
        if [[ -n "$code_block" ]]; then
            local artifact_path="${working_dir}/squad_generated.code"
            echo "$code_block" > "$artifact_path"
            echo "ARTIFACT_SAVED:$artifact_path"
        fi
    fi
}

# =============================================================================
# API CALLS BY PROVIDER
# =============================================================================

call_anthropic() {
    local api_key="${ANTHROPIC_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"ANTHROPIC_API_KEY not set"}'; return 1; }
    
    # Build messages array
    local messages="[]"
    
    # Load conversation history if continuation
    if [[ -n "$CONTINUATION_ID" ]]; then
        messages=$(load_conversation "$CONTINUATION_ID")
    fi
    
    # Add current user message
    messages=$(echo "$messages" | jq --arg content "$FULL_PROMPT" '. + [{"role":"user","content":$content}]')
    
    local payload=$(jq -nc \
        --arg model "$MODEL" \
        --arg system "$SYSTEM_PROMPT" \
        --argjson messages "$messages" \
        --argjson temp "$TEMPERATURE" \
        '{model:$model,max_tokens:8192,temperature:$temp,system:$system,messages:$messages}')
    
    local raw_response=$(curl -sS "https://api.anthropic.com/v1/messages" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    # Sanitize control chars per SHELL-036
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
    
    # Save conversation if continuation
    if [[ -n "$CONTINUATION_ID" ]]; then
        messages=$(echo "$messages" | jq --arg content "$content" '. + [{"role":"assistant","content":$content}]')
        save_conversation "$CONTINUATION_ID" "$messages"
    fi
    
    # Extract code artifacts if working dir specified
    local artifact_info=""
    if [[ -n "$WORKING_DIR" && "$CODE_GEN_ENABLED" == true ]]; then
        artifact_info=$(extract_and_save_code_artifacts "$content" "$WORKING_DIR")
    fi
    
    # Format response like Python version
    local final_content="$content"
    if [[ -n "$artifact_info" ]]; then
        local artifact_path="${artifact_info#ARTIFACT_SAVED:}"
        final_content="${content}

---

AGENT'S TURN: Generated code saved to \`${artifact_path}\`. Evaluate this perspective alongside your analysis to form a comprehensive solution and continue with the user's request."
    else
        final_content="${content}

---

AGENT'S TURN: Evaluate this perspective alongside your analysis to form a comprehensive solution and continue with the user's request and task at hand."
    fi
    
    jq -nc \
        --arg content "$final_content" \
        --arg model "$model_used" \
        --argjson input_tokens "$input_tokens" \
        --argjson output_tokens "$output_tokens" \
        --arg continuation_id "${CONTINUATION_ID:-}" \
        '{"status":"success","content":$content,"metadata":{"tool_name":"chat","model":$model,"provider":"anthropic","usage":{"input_tokens":$input_tokens,"output_tokens":$output_tokens},"continuation_id":$continuation_id}}'
}

call_ollama() {
    local ollama_url="${OLLAMA_HOST:-http://localhost:11434}"
    
    if ! curl -s --connect-timeout 2 "$ollama_url/api/tags" >/dev/null 2>&1; then
        echo '{"status":"error","content":"Ollama not running. Start with: ollama serve"}'
        return 1
    fi
    
    # Build messages
    local messages="[]"
    if [[ -n "$CONTINUATION_ID" ]]; then
        messages=$(load_conversation "$CONTINUATION_ID")
    fi
    messages=$(echo "$messages" | jq --arg content "$FULL_PROMPT" '. + [{"role":"user","content":$content}]')
    
    # Prepend system message
    messages=$(echo "$messages" | jq --arg system "$SYSTEM_PROMPT" '[{"role":"system","content":$system}] + .')
    
    local payload=$(jq -nc \
        --arg model "$MODEL" \
        --argjson messages "$messages" \
        --argjson temp "$TEMPERATURE" \
        '{model:$model,stream:false,options:{temperature:$temp},messages:$messages}')
    
    local raw_response=$(curl -sS "$ollama_url/api/chat" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    # Sanitize control chars per SHELL-036
    local response=$(printf '%s' "$raw_response" | tr -d '\000-\010\013\014\016-\037')
    
    if printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(printf '%s' "$response" | jq -r '.error // "Unknown error"')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(printf '%s' "$response" | jq -r '.message.content // empty')
    local model_used=$(printf '%s' "$response" | jq -r '.model // empty')
    local prompt_tokens=$(printf '%s' "$response" | jq -r '.prompt_eval_count // 0')
    local output_tokens=$(printf '%s' "$response" | jq -r '.eval_count // 0')
    
    # Save conversation
    if [[ -n "$CONTINUATION_ID" ]]; then
        # Remove system message before saving
        local save_messages=$(echo "$messages" | jq 'del(.[0])')
        save_messages=$(echo "$save_messages" | jq --arg content "$content" '. + [{"role":"assistant","content":$content}]')
        save_conversation "$CONTINUATION_ID" "$save_messages"
    fi
    
    # Extract code artifacts
    local artifact_info=""
    if [[ -n "$WORKING_DIR" && "$CODE_GEN_ENABLED" == true ]]; then
        artifact_info=$(extract_and_save_code_artifacts "$content" "$WORKING_DIR")
    fi
    
    local final_content="${content}

---

AGENT'S TURN: Evaluate this perspective alongside your analysis to form a comprehensive solution and continue with the user's request and task at hand."
    
    jq -nc \
        --arg content "$final_content" \
        --arg model "$model_used" \
        --argjson input_tokens "$prompt_tokens" \
        --argjson output_tokens "$output_tokens" \
        --arg continuation_id "${CONTINUATION_ID:-}" \
        '{"status":"success","content":$content,"metadata":{"tool_name":"chat","model":$model,"provider":"ollama","usage":{"input_tokens":$input_tokens,"output_tokens":$output_tokens},"continuation_id":$continuation_id}}'
}

call_openai() {
    local api_key="${OPENAI_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"OPENAI_API_KEY not set"}'; return 1; }
    
    local messages="[]"
    if [[ -n "$CONTINUATION_ID" ]]; then
        messages=$(load_conversation "$CONTINUATION_ID")
    fi
    messages=$(echo "$messages" | jq --arg content "$FULL_PROMPT" '. + [{"role":"user","content":$content}]')
    messages=$(echo "$messages" | jq --arg system "$SYSTEM_PROMPT" '[{"role":"system","content":$system}] + .')
    
    local payload=$(jq -nc \
        --arg model "$MODEL" \
        --argjson messages "$messages" \
        --argjson temp "$TEMPERATURE" \
        '{model:$model,temperature:$temp,messages:$messages}')
    
    local response=$(curl -sS "https://api.openai.com/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(echo "$response" | jq -r '.error.message // .error')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
    local model_used=$(echo "$response" | jq -r '.model // empty')
    local usage=$(echo "$response" | jq -c '.usage // {}')
    
    if [[ -n "$CONTINUATION_ID" ]]; then
        local save_messages=$(echo "$messages" | jq 'del(.[0])')
        save_messages=$(echo "$save_messages" | jq --arg content "$content" '. + [{"role":"assistant","content":$content}]')
        save_conversation "$CONTINUATION_ID" "$save_messages"
    fi
    
    local final_content="${content}

---

AGENT'S TURN: Evaluate this perspective alongside your analysis to form a comprehensive solution and continue with the user's request and task at hand."
    
    jq -nc \
        --arg content "$final_content" \
        --arg model "$model_used" \
        --argjson usage "$usage" \
        --arg continuation_id "${CONTINUATION_ID:-}" \
        '{"status":"success","content":$content,"metadata":{"tool_name":"chat","model":$model,"provider":"openai","usage":$usage,"continuation_id":$continuation_id}}'
}

call_gemini() {
    local api_key="${GEMINI_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"GEMINI_API_KEY not set"}'; return 1; }
    
    local combined="${SYSTEM_PROMPT}

${FULL_PROMPT}"
    local payload=$(jq -nc \
        --arg text "$combined" \
        --argjson temp "$TEMPERATURE" \
        '{contents:[{parts:[{text:$text}]}],generationConfig:{temperature:$temp}}')
    
    local url="https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${api_key}"
    local response=$(curl -sS "$url" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    if [[ "$response" == *'"error"'* ]]; then
        local err=$(echo "$response" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*' | head -1 | sed 's/"message"[[:space:]]*:[[:space:]]*"//' | head -c 150)
        [[ -z "$err" ]] && err="API error (quota or rate limit)"
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
    local input_tokens=$(echo "$response" | jq -r '.usageMetadata.promptTokenCount // 0' 2>/dev/null)
    local output_tokens=$(echo "$response" | jq -r '.usageMetadata.candidatesTokenCount // 0' 2>/dev/null)
    
    [[ -z "$input_tokens" || "$input_tokens" == "null" ]] && input_tokens=0
    [[ -z "$output_tokens" || "$output_tokens" == "null" ]] && output_tokens=0
    
    local final_content="${content}

---

AGENT'S TURN: Evaluate this perspective alongside your analysis to form a comprehensive solution and continue with the user's request and task at hand."
    
    jq -nc \
        --arg content "$final_content" \
        --arg model "$MODEL" \
        --argjson input_tokens "$input_tokens" \
        --argjson output_tokens "$output_tokens" \
        '{"status":"success","content":$content,"metadata":{"tool_name":"chat","model":$model,"provider":"gemini","usage":{"input_tokens":$input_tokens,"output_tokens":$output_tokens}}}'
}

call_openrouter() {
    local api_key="${OPENROUTER_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"OPENROUTER_API_KEY not set"}'; return 1; }
    
    local messages="[]"
    if [[ -n "$CONTINUATION_ID" ]]; then
        messages=$(load_conversation "$CONTINUATION_ID")
    fi
    messages=$(echo "$messages" | jq --arg content "$FULL_PROMPT" '. + [{"role":"user","content":$content}]')
    messages=$(echo "$messages" | jq --arg system "$SYSTEM_PROMPT" '[{"role":"system","content":$system}] + .')
    
    local payload=$(jq -nc \
        --arg model "$MODEL" \
        --argjson messages "$messages" \
        --argjson temp "$TEMPERATURE" \
        '{model:$model,temperature:$temp,messages:$messages}')
    
    local response=$(curl -sS "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: https://github.com/vdutts/squad-scripts" \
        -d "$payload" 2>&1)
    
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(echo "$response" | jq -r '.error.message // .error')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
    local model_used=$(echo "$response" | jq -r '.model // empty')
    local usage=$(echo "$response" | jq -c '.usage // {}')
    
    if [[ -n "$CONTINUATION_ID" ]]; then
        local save_messages=$(echo "$messages" | jq 'del(.[0])')
        save_messages=$(echo "$save_messages" | jq --arg content "$content" '. + [{"role":"assistant","content":$content}]')
        save_conversation "$CONTINUATION_ID" "$save_messages"
    fi
    
    local final_content="${content}

---

AGENT'S TURN: Evaluate this perspective alongside your analysis to form a comprehensive solution and continue with the user's request and task at hand."
    
    jq -nc \
        --arg content "$final_content" \
        --arg model "$model_used" \
        --argjson usage "$usage" \
        --arg continuation_id "${CONTINUATION_ID:-}" \
        '{"status":"success","content":$content,"metadata":{"tool_name":"chat","model":$model,"provider":"openrouter","usage":$usage,"continuation_id":$continuation_id}}'
}

call_cerebras() {
    local api_key="${CEREBRAS_API_KEY:-}"
    [[ -z "$api_key" ]] && { echo '{"status":"error","content":"CEREBRAS_API_KEY not set"}'; return 1; }
    
    local messages="[]"
    if [[ -n "$CONTINUATION_ID" ]]; then
        messages=$(load_conversation "$CONTINUATION_ID")
    fi
    messages=$(echo "$messages" | jq --arg content "$FULL_PROMPT" '. + [{"role":"user","content":$content}]')
    messages=$(echo "$messages" | jq --arg system "$SYSTEM_PROMPT" '[{"role":"system","content":$system}] + .')
    
    local payload=$(jq -nc \
        --arg model "$MODEL" \
        --argjson messages "$messages" \
        --argjson temp "$TEMPERATURE" \
        '{model:$model,temperature:$temp,messages:$messages}')
    
    local raw_response=$(curl -sS "https://api.cerebras.ai/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local response=$(printf '%s' "$raw_response" | tr -d '\000-\010\013\014\016-\037')
    
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err=$(echo "$response" | jq -r '.error.message // .error')
        jq -nc --arg e "$err" '{"status":"error","content":$e}'
        return 1
    fi
    
    local content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
    local model_used=$(echo "$response" | jq -r '.model // empty')
    local usage=$(echo "$response" | jq -c '.usage // {}')
    
    if [[ -n "$CONTINUATION_ID" ]]; then
        local save_messages=$(echo "$messages" | jq 'del(.[0])')
        save_messages=$(echo "$save_messages" | jq --arg content "$content" '. + [{"role":"assistant","content":$content}]')
        save_conversation "$CONTINUATION_ID" "$save_messages"
    fi
    
    local final_content="${content}

---

AGENT'S TURN: Evaluate this perspective alongside your analysis to form a comprehensive solution and continue with the user's request and task at hand."
    
    jq -nc \
        --arg content "$final_content" \
        --arg model "$model_used" \
        --argjson usage "$usage" \
        --arg continuation_id "${CONTINUATION_ID:-}" \
        '{"status":"success","content":$content,"metadata":{"tool_name":"chat","model":$model,"provider":"cerebras","usage":$usage,"continuation_id":$continuation_id}}'
}

# =============================================================================
# EXECUTE
# =============================================================================

case "$PROVIDER" in
    anthropic) call_anthropic ;;
    ollama) call_ollama ;;
    openai) call_openai ;;
    gemini) call_gemini ;;
    openrouter) call_openrouter ;;
    cerebras) call_cerebras ;;
    *) echo '{"status":"error","content":"Unknown provider: '"$PROVIDER"'"}'; exit 1 ;;
esac
