#!/usr/bin/env zsh
# consensus.sh - Multi-model consensus gathering
# Converted from: squad-mcp-server/tools/consensus.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

CONSENSUS_PROMPT='You are participating in a multi-model consensus process. Provide your independent analysis of the question/proposal presented.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

YOUR ROLE:
- Provide your independent perspective on the question
- Be specific about your reasoning
- Highlight any concerns or alternative viewpoints
- If you have a stance (for/against/neutral), argue it clearly

OUTPUT FORMAT:
## Analysis
Your detailed analysis of the question/proposal.

## Key Points
- Point 1: Explanation
- Point 2: Explanation
- Point 3: Explanation

## Concerns
Any concerns or risks you identify.

## Recommendation
Your recommendation with reasoning.'

usage() {
    cat >&2 << 'EOF'
Usage: consensus.sh [OPTIONS] "<question_or_proposal>"

Multi-model consensus gathering tool.

Options:
  -m, --model MODEL    Models to consult (can repeat, default: claude + qwen)
  -f, --file FILE      File to include as context (can repeat)
  --stance STANCE      Stance for model: for|against|neutral
  -h, --help           Show this help

Examples:
  consensus.sh "Should we use microservices for this project?"
  consensus.sh -m claude-sonnet-4-20250514 -m qwen2.5-coder:7b "Best database choice?"
  consensus.sh -f architecture.md "Evaluate this design"
EOF
    exit 1
}

MODELS=()
FILES=()
STANCE=""
PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODELS+=("$2"); shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        --stance) STANCE="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) PROMPT="$1"; shift ;;
    esac
done

[[ -z "$PROMPT" ]] && { echo "Error: question or proposal required" >&2; usage; }

# Default models if none specified
if [[ ${#MODELS[@]} -eq 0 ]]; then
    MODELS=("claude-sonnet-4-20250514" "qwen2.5-coder:7b")
fi

# Build full prompt
FULL_PROMPT="CONSENSUS QUESTION:\n${PROMPT}"

if [[ -n "$STANCE" ]]; then
    FULL_PROMPT+="\n\nYour assigned stance: ${STANCE}"
fi

# Add file context
if [[ ${#FILES[@]} -gt 0 ]]; then
    file_context=$(build_file_context "${FILES[@]}") || exit 1
    FULL_PROMPT+="\n\nCONTEXT:\n${file_context}"
fi

FULL_PROMPT+="\n\nProvide your analysis following the format specified."

# Gather responses from each model
responses=()
for model in "${MODELS[@]}"; do
    provider=$(detect_provider "$model")
    response=$(call_model "$CONSENSUS_PROMPT" "$FULL_PROMPT" "$model" "0.7" "")
    responses+=("### Model: ${model} (${provider})\n\n${response}")
done

# Combine responses
combined=""
for resp in "${responses[@]}"; do
    combined+="${resp}\n\n---\n\n"
done

# Add synthesis prompt
final_content="# Multi-Model Consensus Results

${combined}

## Synthesis

Review the perspectives above and identify:
1. Points of agreement across models
2. Points of disagreement or concern
3. Recommended path forward based on consensus

---

AGENT'S TURN: Consensus gathering complete. Synthesize the perspectives above to form your recommendation."

extra_metadata=$(jq -nc \
    --argjson model_count "${#MODELS[@]}" \
    --argjson file_count "${#FILES[@]}" \
    '{models_consulted: $model_count, files_referenced: $file_count}')

format_output "$final_content" "consensus" "multi-model" "mixed" "$extra_metadata"
