#!/usr/bin/env zsh
# docgen.sh - Documentation generation
# Converted from: squad-mcp-server/tools/docgen.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

DOCGEN_PROMPT='You are an expert technical writer generating comprehensive code documentation. Focus on clarity, completeness, and maintainability.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

IF MORE INFORMATION IS NEEDED respond with:
{"status": "files_required_to_continue", "mandatory_instructions": "<instructions>", "files_needed": ["[file]"]}

DOCUMENTATION STRATEGY:
1. Analyze code structure and purpose
2. Document function signatures with parameters and return types
3. Add complexity analysis (Big O) where relevant
4. Document call flows and dependencies
5. Add inline comments for complex logic

DOCUMENTATION ELEMENTS:
- Module/File Overview: Purpose and responsibilities
- Function/Method Docs: Parameters, returns, exceptions, examples
- Complexity Analysis: Time and space complexity
- Dependencies: External calls and side effects
- Usage Examples: Common use cases

OUTPUT FORMAT:
## Documentation Summary
Overview of documentation added.

## Documented Code

```[language]
/**
 * Function description
 * @param name - Parameter description
 * @returns Return value description
 * @throws Exception conditions
 * @complexity O(n) - Complexity explanation
 * @example
 *   // Usage example
 */
function example(name) {
    // Implementation with inline comments
}
```

## Additional Notes
Important context or caveats.'

usage() {
    cat >&2 << 'EOF'
Usage: docgen.sh [OPTIONS] -f <file>

Documentation generation tool.

Options:
  -m, --model MODEL    Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE      File to document (required, can repeat)
  --style STYLE        Doc style: jsdoc|pydoc|godoc|rustdoc
  --complexity         Include Big O complexity analysis
  -h, --help           Show this help

Examples:
  docgen.sh -f src/utils.py --style pydoc
  docgen.sh -f lib/algo.ts --style jsdoc --complexity
EOF
    exit 1
}

MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
FILES=()
STYLE=""
COMPLEXITY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        --style) STYLE="$2"; shift 2 ;;
        --complexity) COMPLEXITY=true; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) shift ;;
    esac
done

[[ ${#FILES[@]} -eq 0 ]] && { echo "Error: at least one file required (-f)" >&2; usage; }

PROVIDER=$(detect_provider "$MODEL")

FULL_PROMPT="DOCUMENTATION GENERATION REQUEST"
[[ -n "$STYLE" ]] && FULL_PROMPT+="\nDocumentation Style: ${STYLE}"
[[ "$COMPLEXITY" == true ]] && FULL_PROMPT+="\nInclude Big O complexity analysis: Yes"

file_context=$(build_file_context "${FILES[@]}") || exit 1
FULL_PROMPT+="\n\nCODE TO DOCUMENT:\n${file_context}"
FULL_PROMPT+="\n\nGenerate comprehensive documentation following the format specified."

content=$(call_model "$DOCGEN_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "")

if [[ $? -ne 0 ]] || echo "$content" | grep -q '"status".*:.*"files_required'; then
    echo "$content"
    exit $([[ $? -ne 0 ]] && echo 1 || echo 0)
fi

final_content="${content}\n\n---\n\nAGENT'S TURN: Documentation generated. Review and apply the documented code to the source files."

extra_metadata=$(jq -nc --argjson fc "${#FILES[@]}" --arg style "$STYLE" --argjson complexity "$COMPLEXITY" '{files_documented: $fc, style: $style, include_complexity: $complexity}')
format_output "$final_content" "docgen" "$MODEL" "$PROVIDER" "$extra_metadata"
