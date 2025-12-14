#!/usr/bin/env zsh
# codereview.sh - Systematic code review with expert analysis
# Converted from: squad-mcp-server/tools/codereview.py
# Pattern: $PATTERNSJSON#script_over_mcp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

# ============================================================================
# SYSTEM PROMPT
# ============================================================================
CODEREVIEW_PROMPT='ROLE
You are an expert code reviewer, combining deep architectural knowledge with the precision of a static analysis tool. Deliver precise, actionable feedback covering architecture, maintainability, performance, and correctness.

CRITICAL GUIDING PRINCIPLES
- User-Centric Analysis: Align review with the user'\''s specific goals and constraints
- Scoped & Actionable Feedback: Focus strictly on provided code with concrete fixes
- Pragmatic Solutions: Prioritize practical improvements, avoid unnecessary complexity
- DO NOT OVERSTEP: No wholesale changes, technology migrations, or unrelated improvements

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

SEVERITY DEFINITIONS
🔴 CRITICAL: Security flaws, crashes, data loss, undefined behavior
🟠 HIGH: Bugs, performance bottlenecks, anti-patterns impairing usability/reliability
🟡 MEDIUM: Maintainability concerns, code smells, test gaps
🟢 LOW: Style nits, minor improvements

EVALUATION AREAS
- Security: Auth flaws, input validation, cryptography, hardcoded secrets
- Performance: Algorithmic complexity, resource leaks, concurrency issues
- Code Quality: Readability, structure, error handling, documentation
- Testing: Coverage, edge cases, test reliability
- Architecture: Design patterns, modularity, data flow

OUTPUT FORMAT
For each issue:
[SEVERITY] File:Line - Issue description
→ Fix: Specific solution

After listing issues:
- Overall Code Quality Summary (one paragraph)
- Top 3 Priority Fixes (bullets)
- Positive Aspects (what was done well)

IF MORE INFORMATION IS NEEDED respond with:
{
  "status": "files_required_to_continue",
  "mandatory_instructions": "<instructions>",
  "files_needed": ["[file]"]
}'

# ============================================================================
# USAGE
# ============================================================================
usage() {
    cat >&2 << 'EOF'
Usage: codereview.sh [OPTIONS] -f <file> [<additional_context>]

Systematic code review tool.

Options:
  -m, --model MODEL           Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE             File to review (required, can repeat)
  -t, --temperature T         Temperature 0-1 (default: 0.5)
  --type TYPE                 Review type: full|security|performance|quick
  --focus TEXT                Specific areas to focus on
  --standards TEXT            Coding standards to enforce
  -c, --continuation ID       Continuation ID for multi-turn
  -h, --help                  Show this help

Examples:
  codereview.sh -f src/auth.py
  codereview.sh -f api.py --type security "Focus on input validation"
  codereview.sh -f handler.go --type performance --focus "concurrency"
  codereview.sh -m qwen2.5-coder:7b -f main.py
EOF
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
FILES=()
REVIEW_TYPE="full"
FOCUS=""
STANDARDS=""
CONTINUATION_ID=""
CONTEXT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        -t|--temperature) TEMPERATURE="$2"; shift 2 ;;
        --type) REVIEW_TYPE="$2"; shift 2 ;;
        --focus) FOCUS="$2"; shift 2 ;;
        --standards) STANDARDS="$2"; shift 2 ;;
        -c|--continuation) CONTINUATION_ID="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) CONTEXT="$1"; shift ;;
    esac
done

[[ ${#FILES[@]} -eq 0 ]] && { echo "Error: at least one file required (-f)" >&2; usage; }

PROVIDER=$(detect_provider "$MODEL")

# ============================================================================
# BUILD PROMPT
# ============================================================================
FULL_PROMPT="CODE REVIEW REQUEST\n\nReview Type: ${REVIEW_TYPE}"

if [[ -n "$FOCUS" ]]; then
    FULL_PROMPT+="\nFocus Areas: ${FOCUS}"
fi

if [[ -n "$STANDARDS" ]]; then
    FULL_PROMPT+="\nCoding Standards: ${STANDARDS}"
fi

if [[ -n "$CONTEXT" ]]; then
    FULL_PROMPT+="\nAdditional Context: ${CONTEXT}"
fi

# Add file context
file_context=$(build_file_context "${FILES[@]}") || exit 1
FULL_PROMPT+="\n\nFILES TO REVIEW:\n${file_context}"

FULL_PROMPT+="\n\nPlease provide a comprehensive code review following the severity definitions and output format specified."

# ============================================================================
# CALL MODEL
# ============================================================================
content=$(call_model "$CODEREVIEW_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "$CONTINUATION_ID")

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

AGENT'S TURN: Code review complete. Address the issues above in order of severity (CRITICAL first). Implement fixes and verify each change doesn't introduce regressions."

extra_metadata=$(jq -nc \
    --argjson file_count "${#FILES[@]}" \
    --arg review_type "$REVIEW_TYPE" \
    --arg focus "$FOCUS" \
    '{files_reviewed: $file_count, review_type: $review_type, focus: $focus}')

format_output "$final_content" "codereview" "$MODEL" "$PROVIDER" "$extra_metadata"
