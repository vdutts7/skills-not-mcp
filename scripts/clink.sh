#!/usr/bin/env zsh
# clink.sh - Multi-CLI bridge to external AI CLIs
# Supports: claude, gemini, codex, aider
# Based on: pal-mcp-server/tools/clink.py

set -euo pipefail

usage() {
    cat >&2 << 'EOF'
Usage: clink.sh [OPTIONS] "<prompt>"

Bridge to external AI CLI tools (Claude, Gemini, Codex, Aider).

Options:
  --cli NAME           CLI to use: claude, gemini, codex, aider (default: auto-detect)
  --role ROLE          Role preset: default, planner, codereviewer
  -f, --file FILE      File to include as context (can repeat)
  --all                Query ALL available CLIs in parallel
  -h, --help           Show this help

Supported CLIs:
  - claude:  Anthropic Claude CLI (--print --output-format json)
  - gemini:  Google Gemini CLI (--yolo for tool access)
  - codex:   Sourcegraph Codex CLI (--json)
  - aider:   Aider coding assistant

Examples:
  clink.sh "Explain this code"
  clink.sh --cli gemini "What are the latest React 19 features?"
  clink.sh --cli claude --role codereviewer -f src/main.py "Review this"
  clink.sh --all "What's the best approach for caching?"
EOF
    exit 1
}

# ============================================================================
# CLI CONFIGURATIONS (mirrors pal-mcp-server/conf/cli_clients/)
# ============================================================================
declare -A CLI_COMMANDS
CLI_COMMANDS=(
    [claude]="claude --print --output-format json --permission-mode acceptEdits"
    [gemini]="gemini --yolo"
    [codex]="codex exec --json --dangerously-bypass-approvals-and-sandbox"
    [aider]="aider --message"
)

declare -A CLI_AVAILABLE
CLI_AVAILABLE=()

# Detect available CLIs
detect_available_clis() {
    for cli in claude gemini codex aider; do
        if command -v "$cli" >/dev/null 2>&1; then
            CLI_AVAILABLE[$cli]=1
        fi
    done
}

get_default_cli() {
    # Priority: gemini > claude > codex > aider
    for cli in gemini claude codex aider; do
        if [[ -n "${CLI_AVAILABLE[$cli]:-}" ]]; then
            echo "$cli"
            return
        fi
    done
    echo ""
}

list_available_clis() {
    local available=()
    for cli in claude gemini codex aider; do
        if [[ -n "${CLI_AVAILABLE[$cli]:-}" ]]; then
            available+=("$cli")
        fi
    done
    echo "${available[*]}"
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
CLI_NAME=""
ROLE="default"
FILES=()
PROMPT=""
QUERY_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cli) CLI_NAME="$2"; shift 2 ;;
        --role) ROLE="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        --all) QUERY_ALL=true; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) PROMPT="$1"; shift ;;
    esac
done

[[ -z "$PROMPT" ]] && { echo "Error: prompt required" >&2; usage; }

# ============================================================================
# DETECT AVAILABLE CLIS
# ============================================================================
detect_available_clis

if [[ ${#CLI_AVAILABLE[@]} -eq 0 ]]; then
    jq -nc '{"status":"error","content":"No supported CLI found. Install one of: claude, gemini, codex, aider","metadata":{"tool_name":"clink"}}'
    exit 1
fi

# ============================================================================
# BUILD PROMPT WITH FILE CONTEXT
# ============================================================================
build_full_prompt() {
    local base_prompt="$1"
    local full="$base_prompt"
    
    if [[ ${#FILES[@]} -gt 0 ]]; then
        for f in "${FILES[@]}"; do
            if [[ -f "$f" ]]; then
                full+="\n\n=== FILE: $f ===\n$(cat "$f")\n=== END FILE ==="
            else
                full+="\n\n=== FILE: $f === (not found)"
            fi
        done
    fi
    
    printf '%s' "$full"
}

# ============================================================================
# EXECUTE SINGLE CLI
# ============================================================================
execute_cli() {
    local cli="$1"
    local prompt="$2"
    local response=""
    local exit_code=0
    
    case "$cli" in
        claude)
            response=$(echo "$prompt" | claude --print --output-format json 2>&1) || exit_code=$?
            # Extract content from JSON if possible
            if echo "$response" | jq -e '.result // .content // .text' >/dev/null 2>&1; then
                response=$(echo "$response" | jq -r '.result // .content // .text // .')
            fi
            ;;
        gemini)
            response=$(echo "$prompt" | gemini --yolo 2>&1) || exit_code=$?
            ;;
        codex)
            response=$(codex exec --json --dangerously-bypass-approvals-and-sandbox "$prompt" 2>&1) || exit_code=$?
            # Extract from JSON
            if echo "$response" | jq -e '.output // .result // .content' >/dev/null 2>&1; then
                response=$(echo "$response" | jq -r '.output // .result // .content // .')
            fi
            ;;
        aider)
            response=$(echo "$prompt" | aider --message - 2>&1) || exit_code=$?
            ;;
        *)
            response="Unknown CLI: $cli"
            exit_code=1
            ;;
    esac
    
    if [[ $exit_code -ne 0 ]]; then
        jq -nc --arg err "$response" --arg cli "$cli" \
            '{"status":"error","content":$err,"metadata":{"tool_name":"clink","cli":$cli}}'
        return 1
    fi
    
    echo "$response"
    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
FULL_PROMPT=$(build_full_prompt "$PROMPT")

if [[ "$QUERY_ALL" == "true" ]]; then
    # Query all available CLIs in parallel
    available_list=$(list_available_clis)
    responses=()
    cli_names=()
    
    # Create temp files for parallel execution
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" EXIT
    
    for cli in $available_list; do
        (
            result=$(execute_cli "$cli" "$FULL_PROMPT" 2>&1)
            echo "$result" > "$tmpdir/$cli.out"
        ) &
    done
    wait
    
    # Collect results
    combined_content="# Multi-CLI Responses\n\n"
    for cli in $available_list; do
        if [[ -f "$tmpdir/$cli.out" ]]; then
            result=$(cat "$tmpdir/$cli.out")
            combined_content+="## $cli\n\n$result\n\n---\n\n"
            cli_names+=("$cli")
        fi
    done
    
    jq -nc \
        --arg content "$combined_content" \
        --argjson clis "$(printf '%s\n' "${cli_names[@]}" | jq -R . | jq -s .)" \
        '{
            "status": "success",
            "content": $content,
            "metadata": {
                "tool_name": "clink",
                "mode": "multi-cli",
                "clis_queried": $clis
            }
        }'
else
    # Single CLI execution
    if [[ -z "$CLI_NAME" ]]; then
        CLI_NAME=$(get_default_cli)
    fi
    
    if [[ -z "${CLI_AVAILABLE[$CLI_NAME]:-}" ]]; then
        available=$(list_available_clis)
        jq -nc --arg cli "$CLI_NAME" --arg available "$available" \
            '{"status":"error","content":"CLI not available: \($cli). Available: \($available)","metadata":{"tool_name":"clink"}}'
        exit 1
    fi
    
    response=$(execute_cli "$CLI_NAME" "$FULL_PROMPT")
    exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        exit 1
    fi
    
    jq -nc \
        --arg content "$response" \
        --arg cli "$CLI_NAME" \
        --arg role "$ROLE" \
        '{
            "status": "success",
            "content": $content,
            "metadata": {
                "tool_name": "clink",
                "cli_used": $cli,
                "role": $role
            }
        }'
fi
