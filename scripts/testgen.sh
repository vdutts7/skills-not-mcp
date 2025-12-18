#!/usr/bin/env zsh
# testgen.sh - Test generation and planning
# Converted from: squad-mcp-server/tools/testgen.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

TESTGEN_PROMPT='You are an expert test engineer generating comprehensive test suites. Focus on critical paths, edge cases, boundary conditions, and error handling.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

IF MORE INFORMATION IS NEEDED respond with:
{"status": "files_required_to_continue", "mandatory_instructions": "<instructions>", "files_needed": ["[file]"]}

TEST GENERATION STRATEGY:
1. Analyze code structure and identify testable units
2. Identify critical paths and business logic
3. Find edge cases and boundary conditions
4. Plan error handling and failure scenarios
5. Consider integration points and dependencies

TEST CATEGORIES:
- Unit Tests: Individual function/method testing
- Integration Tests: Component interaction testing
- Edge Cases: Boundary conditions, null/empty inputs
- Error Handling: Exception paths, invalid inputs
- Performance: Load-sensitive operations

OUTPUT FORMAT:
## Test Plan Summary
Overview of testing strategy and coverage goals.

## Test Cases

### [Function/Method Name]
**Purpose:** What this tests
**Test Cases:**
1. Happy path - normal operation
2. Edge case - boundary conditions
3. Error case - failure scenarios

```[language]
// Test implementation
```

## Coverage Recommendations
Areas needing additional test coverage.'

usage() {
    cat >&2 << 'EOF'
Usage: testgen.sh [OPTIONS] -f <file>

Test generation and planning tool.

Options:
  -m, --model MODEL    Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE      File to generate tests for (required, can repeat)
  --framework FW       Test framework: pytest|jest|junit|go|rspec
  --focus AREA         Focus: unit|integration|edge|error
  -h, --help           Show this help

Examples:
  testgen.sh -f src/auth.py --framework pytest
  testgen.sh -f api.ts --framework jest --focus edge
EOF
    exit 1
}

MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
FILES=()
FRAMEWORK=""
FOCUS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        --framework) FRAMEWORK="$2"; shift 2 ;;
        --focus) FOCUS="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) shift ;;
    esac
done

[[ ${#FILES[@]} -eq 0 ]] && { echo "Error: at least one file required (-f)" >&2; usage; }

PROVIDER=$(detect_provider "$MODEL")

FULL_PROMPT="TEST GENERATION REQUEST"
[[ -n "$FRAMEWORK" ]] && FULL_PROMPT+="\nTest Framework: ${FRAMEWORK}"
[[ -n "$FOCUS" ]] && FULL_PROMPT+="\nFocus Area: ${FOCUS}"

file_context=$(build_file_context "${FILES[@]}") || exit 1
FULL_PROMPT+="\n\nCODE TO TEST:\n${file_context}"
FULL_PROMPT+="\n\nGenerate comprehensive tests following the format specified."

content=$(call_model "$TESTGEN_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "")

if [[ $? -ne 0 ]] || echo "$content" | grep -q '"status".*:.*"files_required'; then
    echo "$content"
    exit $([[ $? -ne 0 ]] && echo 1 || echo 0)
fi

final_content="${content}\n\n---\n\nAGENT'S TURN: Test generation complete. Implement the test cases and verify coverage."

extra_metadata=$(jq -nc --argjson fc "${#FILES[@]}" --arg fw "$FRAMEWORK" --arg focus "$FOCUS" '{files_analyzed: $fc, framework: $fw, focus: $focus}')
format_output "$final_content" "testgen" "$MODEL" "$PROVIDER" "$extra_metadata"
