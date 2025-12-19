#!/usr/bin/env zsh
# challenge.sh - Critical thinking and thoughtful disagreement
# Converted from: squad-mcp-server/tools/challenge.py
# Pattern: $PATTERNSJSON#script_over_mcp
# NOTE: This tool does NOT call AI - it wraps prompts for critical evaluation

set -euo pipefail

# ============================================================================
# USAGE
# ============================================================================
usage() {
    cat >&2 << 'EOF'
Usage: challenge.sh "<statement_to_challenge>"

Prevents reflexive agreement by forcing critical thinking and reasoned analysis.
Use when a user critically questions, disagrees, or pushes back on earlier answers.

This tool does NOT call AI - it wraps the statement in critical thinking instructions
for the calling agent to evaluate.

Options:
  -h, --help    Show this help

Examples:
  challenge.sh "React is always better than Vue for large applications"
  challenge.sh "Microservices are the best architecture for all projects"
  challenge.sh "You should always use TypeScript over JavaScript"
EOF
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) PROMPT="$1"; shift ;;
    esac
done

[[ -z "$PROMPT" ]] && { echo "Error: statement required" >&2; usage; }

# ============================================================================
# WRAP PROMPT FOR CHALLENGE
# ============================================================================
CHALLENGE_PROMPT="CRITICAL REASSESSMENT - Do not automatically agree:

\"${PROMPT}\"

Carefully evaluate the statement above. Is it accurate, complete, and well-reasoned?
Investigate if needed before replying, and stay focused. If you identify flaws, gaps, or misleading
points, explain them clearly. Likewise, if you find the reasoning sound, explain why it holds up.
Respond with thoughtful analysis - stay to the point and avoid reflexive agreement."

# ============================================================================
# OUTPUT
# ============================================================================
jq -nc \
    --arg original "$PROMPT" \
    --arg challenge "$CHALLENGE_PROMPT" \
    '{
        "status": "challenge_accepted",
        "original_statement": $original,
        "challenge_prompt": $challenge,
        "instructions": "Present the challenge_prompt to yourself and follow its instructions. Reassess the statement carefully and critically before responding. If, after reflection, you find reasons to disagree or qualify it, explain your reasoning. Likewise, if you find reasons to agree, articulate them clearly and justify your agreement.",
        "metadata": {
            "tool_name": "challenge",
            "requires_ai": false
        }
    }'
