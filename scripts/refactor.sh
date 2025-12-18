#!/usr/bin/env zsh
# refactor.sh - Code refactoring analysis
# Converted from: squad-mcp-server/tools/refactor.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

REFACTOR_PROMPT='You are an expert software architect analyzing code for refactoring opportunities. Focus on code smells, decomposition, modernization, and organization improvements.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

IF MORE INFORMATION IS NEEDED respond with:
{"status": "files_required_to_continue", "mandatory_instructions": "<instructions>", "files_needed": ["[file]"]}

REFACTORING CATEGORIES:
- Code Smells: Long methods, large classes, duplicate code, dead code
- Decomposition: Extract method/class, split responsibilities
- Modernization: Update patterns, use modern language features
- Organization: Improve structure, naming, module boundaries

ANALYSIS APPROACH:
1. Identify code smells and anti-patterns
2. Assess complexity and maintainability
3. Find decomposition opportunities
4. Suggest modernization improvements
5. Recommend organizational changes

OUTPUT FORMAT:
## Refactoring Summary
Overview of code quality and main opportunities.

## Refactoring Opportunities

### [PRIORITY] [Type] - Description
**Location:** File:Line
**Current Issue:** What'\''s wrong
**Proposed Change:** How to fix it
**Impact:** Benefits of the change
**Risk:** Potential issues to watch for

```[language]
// Before
old_code()

// After
new_code()
```

## Recommended Order
Prioritized sequence for implementing refactors.

## Quick Wins
Low-effort improvements with immediate benefit.'

usage() {
    cat >&2 << 'EOF'
Usage: refactor.sh [OPTIONS] -f <file>

Code refactoring analysis tool.

Options:
  -m, --model MODEL    Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE      File to analyze (required, can repeat)
  --type TYPE          Focus: codesmells|decompose|modernize|organization
  -h, --help           Show this help

Examples:
  refactor.sh -f src/legacy.py
  refactor.sh -f services/ --type decompose
  refactor.sh -m qwen2.5-coder:7b -f main.go --type modernize
EOF
    exit 1
}

MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
FILES=()
REFACTOR_TYPE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        --type) REFACTOR_TYPE="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) shift ;;
    esac
done

[[ ${#FILES[@]} -eq 0 ]] && { echo "Error: at least one file required (-f)" >&2; usage; }

PROVIDER=$(detect_provider "$MODEL")

FULL_PROMPT="REFACTORING ANALYSIS REQUEST"
[[ -n "$REFACTOR_TYPE" ]] && FULL_PROMPT+="\nRefactoring Focus: ${REFACTOR_TYPE}"

file_context=$(build_file_context "${FILES[@]}") || exit 1
FULL_PROMPT+="\n\nCODE TO ANALYZE:\n${file_context}"
FULL_PROMPT+="\n\nAnalyze for refactoring opportunities following the format specified."

content=$(call_model "$REFACTOR_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "")

if [[ $? -ne 0 ]] || echo "$content" | grep -q '"status".*:.*"files_required'; then
    echo "$content"
    exit $([[ $? -ne 0 ]] && echo 1 || echo 0)
fi

final_content="${content}\n\n---\n\nAGENT'S TURN: Refactoring analysis complete. Implement changes in the recommended order, testing after each refactor."

extra_metadata=$(jq -nc --argjson fc "${#FILES[@]}" --arg type "$REFACTOR_TYPE" '{files_analyzed: $fc, refactor_type: $type}')
format_output "$final_content" "refactor" "$MODEL" "$PROVIDER" "$extra_metadata"
