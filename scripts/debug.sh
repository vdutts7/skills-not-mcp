#!/usr/bin/env zsh
# debug.sh - Systematic root cause analysis and debugging assistance
# Converted from: squad-mcp-server/tools/debug.py
# Pattern: $PATTERNSJSON#script_over_mcp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

# ============================================================================
# SYSTEM PROMPT
# ============================================================================
DEBUG_PROMPT='ROLE
You are an expert debugging assistant. Your role is to provide systematic root cause analysis based on the investigation presented to you.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". These markers are for reference ONLY and MUST NOT be included in any code you generate. Always reference specific line numbers in your replies.

IF MORE INFORMATION IS NEEDED
If you need additional context to provide thorough analysis, respond with this exact JSON:
{
  "status": "files_required_to_continue",
  "mandatory_instructions": "<your critical instructions>",
  "files_needed": ["[file name here]", "[or some folder/]"]
}

IF NO BUG FOUND
If after thorough investigation no concrete evidence of a bug is found:
{
  "status": "no_bug_found",
  "summary": "<what was investigated>",
  "investigation_steps": ["<step 1>", "<step 2>"],
  "alternative_explanations": ["<possible misunderstanding>"],
  "recommended_questions": ["<question to clarify>"]
}

FOR COMPLETE ANALYSIS provide:
1. Summary of the problem and impact
2. Investigation steps taken
3. Hypotheses ranked by likelihood with:
   - Root cause explanation
   - Evidence supporting it
   - Minimal fix recommendation
   - Regression check
4. Key findings
5. Immediate actions

CRITICAL DEBUGGING PRINCIPLES:
1. Bugs can ONLY be found from given code - do not imagine issues
2. Focus ONLY on the reported issue - avoid suggesting extensive refactoring
3. Propose minimal fixes that address the specific problem
4. Rank hypotheses by likelihood based on evidence
5. Always include specific file:line references'

# ============================================================================
# USAGE
# ============================================================================
usage() {
    cat >&2 << 'EOF'
Usage: debug.sh [OPTIONS] "<issue_description>"

Systematic debugging and root cause analysis tool.

Options:
  -m, --model MODEL           Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE             File to include as context (can repeat)
  -t, --temperature T         Temperature 0-1 (default: 0.5)
  -e, --error TEXT            Error message or stack trace
  -l, --logs TEXT             Relevant log output
  --hypothesis TEXT           Your current hypothesis
  -c, --continuation ID       Continuation ID for multi-turn
  -h, --help                  Show this help

Examples:
  debug.sh -f src/api.py -e "TypeError: undefined is not a function" "API returns 500"
  debug.sh -f app.py --logs "Connection refused" "Database connection failing"
  debug.sh -m qwen2.5-coder:7b -f main.go "Race condition in concurrent handler"
EOF
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
FILES=()
ERROR_MSG=""
LOGS=""
HYPOTHESIS=""
CONTINUATION_ID=""
PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        -t|--temperature) TEMPERATURE="$2"; shift 2 ;;
        -e|--error) ERROR_MSG="$2"; shift 2 ;;
        -l|--logs) LOGS="$2"; shift 2 ;;
        --hypothesis) HYPOTHESIS="$2"; shift 2 ;;
        -c|--continuation) CONTINUATION_ID="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) PROMPT="$1"; shift ;;
    esac
done

[[ -z "$PROMPT" ]] && { echo "Error: issue description required" >&2; usage; }

PROVIDER=$(detect_provider "$MODEL")

# ============================================================================
# BUILD PROMPT
# ============================================================================
FULL_PROMPT="ISSUE DESCRIPTION:\n${PROMPT}"

if [[ -n "$ERROR_MSG" ]]; then
    FULL_PROMPT+="\n\nERROR MESSAGE:\n${ERROR_MSG}"
fi

if [[ -n "$LOGS" ]]; then
    FULL_PROMPT+="\n\nRELEVANT LOGS:\n${LOGS}"
fi

if [[ -n "$HYPOTHESIS" ]]; then
    FULL_PROMPT+="\n\nCURRENT HYPOTHESIS:\n${HYPOTHESIS}"
fi

# Add file context
if [[ ${#FILES[@]} -gt 0 ]]; then
    file_context=$(build_file_context "${FILES[@]}") || exit 1
    FULL_PROMPT+="\n\nFILE CONTEXT:\n${file_context}"
fi

FULL_PROMPT+="\n\nPlease analyze this issue systematically and provide your debugging analysis."

# ============================================================================
# CALL MODEL
# ============================================================================
content=$(call_model "$DEBUG_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "$CONTINUATION_ID")

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

AGENT'S TURN: Debug analysis complete. Review the hypotheses and recommended fixes above. Implement the minimal fix for the highest-confidence hypothesis first, then verify the issue is resolved."

extra_metadata=$(jq -nc \
    --argjson file_count "${#FILES[@]}" \
    --arg error "${ERROR_MSG:0:100}" \
    '{files_analyzed: $file_count, error_provided: ($error != "")}')

format_output "$final_content" "debug" "$MODEL" "$PROVIDER" "$extra_metadata"
