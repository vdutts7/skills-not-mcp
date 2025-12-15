#!/usr/bin/env zsh
# planner.sh - Interactive sequential planning for complex tasks
# Converted from: squad-mcp-server/tools/planner.py
# Pattern: $PATTERNSJSON#script_over_mcp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

# ============================================================================
# SYSTEM PROMPT
# ============================================================================
PLANNER_PROMPT='You are an expert planning consultant and systems architect with deep expertise in plan structuring, risk assessment, and software development strategy.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

IF MORE INFORMATION IS NEEDED respond with:
{
  "status": "files_required_to_continue",
  "mandatory_instructions": "<instructions>",
  "files_needed": ["[file]"]
}

PLANNING METHODOLOGY:
1. DECOMPOSITION: Break down the main objective into logical, sequential steps
2. DEPENDENCIES: Identify which steps depend on others and order them appropriately
3. BRANCHING: When multiple valid approaches exist, create branches to explore alternatives
4. ITERATION: Be willing to step back and refine earlier steps if new insights emerge
5. COMPLETENESS: Ensure all aspects of the task are covered without gaps

STEP STRUCTURE:
Each step MUST include:
- Step number and branch identifier (if branching)
- Clear, actionable description
- Prerequisites or dependencies
- Expected outcomes
- Potential challenges or considerations
- Alternative approaches (when applicable)

PLANNING PRINCIPLES:
- Start with high-level strategy, then add implementation details
- Consider technical, organizational, and resource constraints
- Include validation and testing steps
- Plan for error handling and rollback scenarios
- Think about maintenance and future extensibility

PLAN PRESENTATION:
When complete, present the final plan with:
- Clear headings and numbered phases/sections
- Visual elements like ASCII charts for workflows
- Bullet points and sub-steps for detailed breakdowns
- Implementation guidance and next steps
- Priority indicators and sequence information

Example visual elements:
- Phase diagrams: Phase 1 → Phase 2 → Phase 3
- Dependency charts: A ← B ← C
- Sequence boxes: [Setup] → [Development] → [Testing]

IMPORTANT: Do NOT use emojis. Do NOT mention time estimates unless explicitly requested.'

# ============================================================================
# USAGE
# ============================================================================
usage() {
    cat >&2 << 'EOF'
Usage: planner.sh [OPTIONS] "<task_or_goal>"

Interactive sequential planning for complex tasks.

Options:
  -m, --model MODEL           Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE             File to include as context (can repeat)
  -t, --temperature T         Temperature 0-1 (default: 0.7)
  --context TEXT              Additional context about constraints
  -c, --continuation ID       Continuation ID for multi-turn planning
  -h, --help                  Show this help

Examples:
  planner.sh "Design a microservices migration strategy"
  planner.sh -f architecture.md "Plan API versioning approach"
  planner.sh --context "Team of 3, 2 month deadline" "Build user auth system"
  planner.sh -m qwen2.5-coder:7b "Plan database schema for e-commerce"
EOF
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.7
FILES=()
CONTEXT=""
CONTINUATION_ID=""
PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        -t|--temperature) TEMPERATURE="$2"; shift 2 ;;
        --context) CONTEXT="$2"; shift 2 ;;
        -c|--continuation) CONTINUATION_ID="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) PROMPT="$1"; shift ;;
    esac
done

[[ -z "$PROMPT" ]] && { echo "Error: task or goal required" >&2; usage; }

PROVIDER=$(detect_provider "$MODEL")

# ============================================================================
# BUILD PROMPT
# ============================================================================
FULL_PROMPT="PLANNING REQUEST:\n${PROMPT}"

if [[ -n "$CONTEXT" ]]; then
    FULL_PROMPT+="\n\nCONSTRAINTS/CONTEXT:\n${CONTEXT}"
fi

# Add file context
if [[ ${#FILES[@]} -gt 0 ]]; then
    file_context=$(build_file_context "${FILES[@]}") || exit 1
    FULL_PROMPT+="\n\nREFERENCE FILES:\n${file_context}"
fi

FULL_PROMPT+="\n\nPlease create a comprehensive plan following the methodology and presentation guidelines."

# ============================================================================
# CALL MODEL
# ============================================================================
content=$(call_model "$PLANNER_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "$CONTINUATION_ID")

if [[ $? -ne 0 ]]; then
    echo "$content"
    exit 1
fi

# Check if model requested more files
if echo "$content" | grep -q '"status".*:.*"files_required_to_continue"'; then
    echo "$content"
    exit 0
fi

# ============================================================================
# FORMAT OUTPUT
# ============================================================================
final_content="${content}

---

AGENT'S TURN: Planning complete. Review the plan above and begin implementation following the phases in order. Validate each step before proceeding to the next."

extra_metadata=$(jq -nc \
    --argjson file_count "${#FILES[@]}" \
    --arg context "${CONTEXT:0:100}" \
    '{files_referenced: $file_count, has_constraints: ($context != "")}')

format_output "$final_content" "planner" "$MODEL" "$PROVIDER" "$extra_metadata"
