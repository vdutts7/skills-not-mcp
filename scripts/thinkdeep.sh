#!/usr/bin/env zsh
# thinkdeep.sh - Extended reasoning with systematic investigation
# Converted from: squad-mcp-server/tools/thinkdeep.py
# Pattern: $PATTERNSJSON#script_over_mcp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

# ============================================================================
# SYSTEM PROMPT
# ============================================================================
THINKDEEP_PROMPT='ROLE
You are a senior engineering collaborator working alongside the agent on complex software problems. The agent will send you content - analysis, prompts, questions, ideas, or theories - to deepen, validate, or extend with rigor and clarity.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". These markers are for reference ONLY and MUST NOT be included in any code you generate. Always reference specific line numbers in your replies in order to locate exact positions if needed to point to exact locations. Include a very short code excerpt alongside for clarity. Never include "LINE|" markers in generated code snippets.

IF MORE INFORMATION IS NEEDED
If you need additional context (e.g., related files, system architecture, requirements, code snippets) to provide thorough analysis, you MUST ONLY respond with this exact JSON (and nothing else):
{
  "status": "files_required_to_continue",
  "mandatory_instructions": "<your critical instructions for the agent>",
  "files_needed": ["[file name here]", "[or some folder/]"]
}

GUIDELINES
1. Begin with context analysis: identify tech stack, languages, frameworks, and project constraints.
2. Stay on scope: avoid speculative, over-engineered, or oversized ideas; keep suggestions practical and grounded.
3. Challenge and enrich: find gaps, question assumptions, and surface hidden complexities or risks.
4. Provide actionable next steps: offer specific advice, trade-offs, and implementation strategies.
5. Offer multiple viable strategies ONLY WHEN clearly beneficial within the current environment.
6. Suggest creative solutions that operate within real-world constraints, and avoid proposing major shifts unless truly warranted.
7. Use concise, technical language; assume an experienced engineering audience.
8. Remember: Overengineering is an anti-pattern - avoid suggesting solutions that introduce unnecessary abstraction, indirection, or configuration in anticipation of complexity that does not yet exist.

KEY FOCUS AREAS (apply when relevant)
- Architecture & Design: modularity, boundaries, abstraction layers, dependencies
- Performance & Scalability: algorithmic efficiency, concurrency, caching, bottlenecks
- Security & Safety: validation, authentication/authorization, error handling, vulnerabilities
- Quality & Maintainability: readability, testing, monitoring, refactoring
- Integration & Deployment: ONLY IF APPLICABLE - external systems, compatibility, configuration

EVALUATION
Your response will be reviewed by the agent before any decision is made. Your goal is to practically extend the agent'\''s thinking, surface blind spots, and refine options - not to deliver final answers in isolation.

REMINDERS
- Ground all insights in the current project'\''s architecture, limitations, and goals.
- If further context is needed, request it via the clarification JSON - nothing else.
- Prioritize depth over breadth; propose alternatives ONLY if they clearly add value.
- Be the ideal development partner - rigorous, focused, and fluent in real-world software trade-offs.'

# ============================================================================
# USAGE
# ============================================================================
usage() {
    cat >&2 << 'EOF'
Usage: thinkdeep.sh [OPTIONS] "<problem_or_question>"

Extended reasoning tool for complex problem analysis.

Options:
  -m, --model MODEL           Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE             File to include as context (can repeat)
  -t, --temperature T         Temperature 0-1 (default: 0.7)
  -p, --provider PROV         Provider: anthropic|ollama|openai|gemini|openrouter
  --focus AREA                Focus area: architecture|performance|security|quality
  --context TEXT              Additional problem context
  -c, --continuation ID       Continuation ID for multi-turn
  -h, --help                  Show this help

Examples:
  thinkdeep.sh "How should I architect a real-time notification system?"
  thinkdeep.sh -f src/api.py --focus performance "Why is this endpoint slow?"
  thinkdeep.sh -m qwen2.5-coder:7b "Best approach for database migrations?"
EOF
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.7
PROVIDER=""
FOCUS_AREAS=()
PROBLEM_CONTEXT=""
CONTINUATION_ID=""
FILES=()
PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        -t|--temperature) TEMPERATURE="$2"; shift 2 ;;
        -p|--provider) PROVIDER="$2"; shift 2 ;;
        --focus) FOCUS_AREAS+=("$2"); shift 2 ;;
        --context) PROBLEM_CONTEXT="$2"; shift 2 ;;
        -c|--continuation) CONTINUATION_ID="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) PROMPT="$1"; shift ;;
    esac
done

[[ -z "$PROMPT" ]] && { echo "Error: prompt required" >&2; usage; }

# Auto-detect provider if not specified
[[ -z "$PROVIDER" ]] && PROVIDER=$(detect_provider "$MODEL")

# ============================================================================
# BUILD PROMPT
# ============================================================================
FULL_PROMPT="$PROMPT"

# Add problem context if provided
if [[ -n "$PROBLEM_CONTEXT" ]]; then
    FULL_PROMPT="PROBLEM CONTEXT:\n${PROBLEM_CONTEXT}\n\nQUESTION/ANALYSIS:\n${PROMPT}"
fi

# Add focus areas if specified
if [[ ${#FOCUS_AREAS[@]} -gt 0 ]]; then
    focus_str=$(printf '%s, ' "${FOCUS_AREAS[@]}")
    focus_str="${focus_str%, }"
    FULL_PROMPT="FOCUS AREAS: ${focus_str}\n\n${FULL_PROMPT}"
fi

# Add file context if provided
if [[ ${#FILES[@]} -gt 0 ]]; then
    file_context=$(build_file_context "${FILES[@]}") || exit 1
    FULL_PROMPT="FILE CONTEXT:\n${file_context}\n\n${FULL_PROMPT}"
fi

# ============================================================================
# CALL MODEL
# ============================================================================
content=$(call_model "$THINKDEEP_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "$CONTINUATION_ID")

if [[ $? -ne 0 ]]; then
    # Content already contains error JSON
    echo "$content"
    exit 1
fi

# Check if model requested more files
if echo "$content" | grep -q '"status".*:.*"files_required_to_continue"'; then
    # Pass through the file request
    echo "$content"
    exit 0
fi

# ============================================================================
# FORMAT OUTPUT
# ============================================================================
# Add thinking footer
final_content="${content}

---

AGENT'S TURN: Deep thinking analysis complete. Evaluate these insights alongside your understanding to form a comprehensive solution. Consider the trade-offs, risks, and implementation strategies outlined above."

# Build metadata
extra_metadata=$(jq -nc \
    --arg focus "$(printf '%s,' "${FOCUS_AREAS[@]}" | sed 's/,$//')" \
    --arg context "$PROBLEM_CONTEXT" \
    --argjson file_count "${#FILES[@]}" \
    '{focus_areas: $focus, problem_context: $context, files_analyzed: $file_count}')

format_output "$final_content" "thinkdeep" "$MODEL" "$PROVIDER" "$extra_metadata"
