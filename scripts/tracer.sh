#!/usr/bin/env zsh
# tracer.sh - Code tracing and dependency analysis
# Converted from: squad-mcp-server/tools/tracer.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

TRACER_PROMPT='You are an expert code analyst performing execution flow tracing and dependency analysis. Map call chains, data flow, and structural relationships.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

IF MORE INFORMATION IS NEEDED respond with:
{"status": "files_required_to_continue", "mandatory_instructions": "<instructions>", "files_needed": ["[file]"]}

TRACING MODES:
- Precision: Execution flow, call chains, data transformations
- Dependencies: Structural relationships, imports, class hierarchies

ANALYSIS APPROACH:
1. Identify entry points and target functions/methods
2. Map call chains and execution paths
3. Track data flow and transformations
4. Document dependencies and relationships
5. Identify side effects and state changes

OUTPUT FORMAT:
## Trace Summary
Overview of what was traced and key findings.

## Call Chain
```
entry_point()
  └─> function_a()
      └─> function_b()
          └─> external_call()
```

## Data Flow
```
input → validation → transformation → output
         ↓
      side_effect
```

## Dependencies
- Direct: Immediate imports and calls
- Transitive: Indirect dependencies
- External: Third-party libraries

## Key Findings
Important observations about the traced code.

## Potential Issues
Concerns identified during tracing (circular deps, tight coupling, etc.).'

usage() {
    cat >&2 << 'EOF'
Usage: tracer.sh [OPTIONS] -f <file> "<function_or_method>"

Code tracing and dependency analysis tool.

Options:
  -m, --model MODEL    Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE      File containing the code (required, can repeat)
  --mode MODE          Trace mode: precision|dependencies
  -h, --help           Show this help

Examples:
  tracer.sh -f src/api.py "handle_request"
  tracer.sh -f services/ --mode dependencies "UserService"
  tracer.sh -m qwen2.5-coder:7b -f main.go "main"
EOF
    exit 1
}

MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
FILES=()
TRACE_MODE="precision"
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        --mode) TRACE_MODE="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[[ ${#FILES[@]} -eq 0 ]] && { echo "Error: at least one file required (-f)" >&2; usage; }
[[ -z "$TARGET" ]] && { echo "Error: target function/method required" >&2; usage; }

PROVIDER=$(detect_provider "$MODEL")

FULL_PROMPT="CODE TRACING REQUEST\n\nTarget: ${TARGET}\nTrace Mode: ${TRACE_MODE}"

file_context=$(build_file_context "${FILES[@]}") || exit 1
FULL_PROMPT+="\n\nCODE TO TRACE:\n${file_context}"
FULL_PROMPT+="\n\nTrace the target following the format specified."

content=$(call_model "$TRACER_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "")

if [[ $? -ne 0 ]] || echo "$content" | grep -q '"status".*:.*"files_required'; then
    echo "$content"
    exit $([[ $? -ne 0 ]] && echo 1 || echo 0)
fi

final_content="${content}\n\n---\n\nAGENT'S TURN: Tracing complete. Use the call chain and dependency information to understand the code flow."

extra_metadata=$(jq -nc --argjson fc "${#FILES[@]}" --arg mode "$TRACE_MODE" --arg target "$TARGET" '{files_traced: $fc, trace_mode: $mode, target: $target}')
format_output "$final_content" "tracer" "$MODEL" "$PROVIDER" "$extra_metadata"
