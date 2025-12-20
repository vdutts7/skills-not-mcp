#!/usr/bin/env zsh
# precommit.sh - Pre-commit validation and analysis
# Converted from: squad-mcp-server/tools/precommit.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

PRECOMMIT_PROMPT='You are an expert code reviewer performing pre-commit validation. Analyze git changes for quality, security, and correctness before commit.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

IF MORE INFORMATION IS NEEDED respond with:
{"status": "files_required_to_continue", "mandatory_instructions": "<instructions>", "files_needed": ["[file]"]}

PRE-COMMIT VALIDATION AREAS:
- Code Quality: Style, complexity, maintainability
- Security: Hardcoded secrets, injection risks, auth issues
- Testing: Missing tests, broken tests, coverage gaps
- Documentation: Missing docs, outdated comments
- Dependencies: Version issues, security vulnerabilities
- Git Hygiene: Commit message, file organization

SEVERITY DEFINITIONS:
🔴 BLOCKER: Must fix before commit
🟠 WARNING: Should fix, but can proceed
🟡 SUGGESTION: Nice to have improvements
🟢 INFO: Informational notes

OUTPUT FORMAT:
## Pre-Commit Summary
Overview of changes and validation status.

## Changes Analyzed
- Files modified: X
- Lines added: Y
- Lines removed: Z

## Issues Found

### [SEVERITY] Issue Description
**File:** path/to/file
**Change:** What was changed
**Issue:** What'\''s wrong
**Fix:** How to resolve

## Commit Readiness
[READY/NOT READY] - Summary of commit status

## Recommended Actions
Prioritized list of actions before committing.'

usage() {
    cat >&2 << 'EOF'
Usage: precommit.sh [OPTIONS] [<repo_path>]

Pre-commit validation tool.

Options:
  -m, --model MODEL    Model to use (default: claude-sonnet-4-20250514)
  --staged             Only check staged changes (default)
  --all                Check all uncommitted changes
  -h, --help           Show this help

Examples:
  precommit.sh                    # Current directory, staged changes
  precommit.sh ~/project          # Specific repo
  precommit.sh --all              # All uncommitted changes
EOF
    exit 1
}

MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
REPO_PATH="."
CHECK_MODE="staged"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        --staged) CHECK_MODE="staged"; shift ;;
        --all) CHECK_MODE="all"; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) REPO_PATH="$1"; shift ;;
    esac
done

PROVIDER=$(detect_provider "$MODEL")

# Get git diff
cd "$REPO_PATH"
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo '{"status":"error","content":"Not a git repository"}'
    exit 1
fi

if [[ "$CHECK_MODE" == "staged" ]]; then
    DIFF=$(git diff --cached 2>/dev/null || echo "")
    DIFF_STAT=$(git diff --cached --stat 2>/dev/null || echo "")
else
    DIFF=$(git diff 2>/dev/null || echo "")
    DIFF_STAT=$(git diff --stat 2>/dev/null || echo "")
fi

if [[ -z "$DIFF" ]]; then
    jq -nc '{"status":"success","content":"No changes to validate.","metadata":{"tool_name":"precommit"}}'
    exit 0
fi

FULL_PROMPT="PRE-COMMIT VALIDATION REQUEST\n\nCheck Mode: ${CHECK_MODE}\n\nDIFF STATISTICS:\n${DIFF_STAT}\n\nFULL DIFF:\n${DIFF}\n\nValidate these changes following the format specified."

content=$(call_model "$PRECOMMIT_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "")

if [[ $? -ne 0 ]]; then
    echo "$content"
    exit 1
fi

final_content="${content}\n\n---\n\nAGENT'S TURN: Pre-commit validation complete. Address any BLOCKER issues before committing."

extra_metadata=$(jq -nc --arg mode "$CHECK_MODE" --arg repo "$REPO_PATH" '{check_mode: $mode, repository: $repo}')
format_output "$final_content" "precommit" "$MODEL" "$PROVIDER" "$extra_metadata"
