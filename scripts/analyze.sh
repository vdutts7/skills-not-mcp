#!/usr/bin/env zsh
# analyze.sh - Holistic code and architecture analysis
# Converted from: squad-mcp-server/tools/analyze.py
# Pattern: $PATTERNSJSON#script_over_mcp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

# ============================================================================
# SYSTEM PROMPT
# ============================================================================
ANALYZE_PROMPT='ROLE
You are a senior software analyst performing a holistic technical audit. Your mission is to help engineers understand how a codebase aligns with long-term goals, architectural soundness, scalability, and maintainability.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

IF MORE INFORMATION IS NEEDED respond with:
{
  "status": "files_required_to_continue",
  "mandatory_instructions": "<instructions>",
  "files_needed": ["[file]"]
}

SCOPE & FOCUS
- Understand the code'\''s purpose and architecture
- Identify strengths, risks, and strategic improvement areas
- Avoid line-by-line bug hunts - those are for CodeReview
- Recommend practical, proportional changes
- Flag overengineered solutions - excessive abstraction without clear need

ANALYSIS STRATEGY
1. Map the tech stack, frameworks, deployment model
2. Determine how well architecture serves business/scaling goals
3. Surface systemic risks (tech debt, brittle modules, bottlenecks)
4. Highlight strategic refactor opportunities with high ROI
5. Provide clear, actionable insights

KEY DIMENSIONS
- Architectural Alignment: layering, domain boundaries, micro-vs-monolith fit
- Scalability & Performance: data flow, caching, concurrency model
- Maintainability & Tech Debt: cohesion, coupling, documentation health
- Security Posture: exposure points, secrets management
- Operational Readiness: observability, deployment pipeline
- Future Proofing: ease of feature addition, roadmap

DELIVERABLE FORMAT

## Executive Overview
One paragraph summarizing architecture fitness, key risks, and strengths.

## Strategic Findings (Ordered by Impact)

### 1. [FINDING NAME]
**Insight:** What matters and why
**Evidence:** Specific modules/files illustrating the point
**Impact:** How this affects scalability, maintainability, or goals
**Recommendation:** Actionable next step
**Effort vs. Benefit:** Low/Medium/High effort; Low/Medium/High payoff

## Quick Wins
Bullet list of low-effort changes offering immediate value.

## Long-Term Roadmap Suggestions
High-level guidance for phased improvements.'

# ============================================================================
# USAGE
# ============================================================================
usage() {
    cat >&2 << 'EOF'
Usage: analyze.sh [OPTIONS] -f <file_or_dir> [<context>]

Holistic code and architecture analysis tool.

Options:
  -m, --model MODEL           Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE             File or directory to analyze (required, can repeat)
  -t, --temperature T         Temperature 0-1 (default: 0.5)
  --type TYPE                 Analysis type: architecture|performance|security|quality|general
  --format FMT                Output format: summary|detailed|actionable
  -c, --continuation ID       Continuation ID for multi-turn
  -h, --help                  Show this help

Examples:
  analyze.sh -f src/
  analyze.sh -f api.py --type architecture "Focus on scalability"
  analyze.sh -f services/ --type performance
  analyze.sh -m qwen2.5-coder:7b -f main.py
EOF
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
FILES=()
ANALYSIS_TYPE="general"
OUTPUT_FORMAT="detailed"
CONTINUATION_ID=""
CONTEXT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        -t|--temperature) TEMPERATURE="$2"; shift 2 ;;
        --type) ANALYSIS_TYPE="$2"; shift 2 ;;
        --format) OUTPUT_FORMAT="$2"; shift 2 ;;
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
FULL_PROMPT="CODE ANALYSIS REQUEST\n\nAnalysis Type: ${ANALYSIS_TYPE}\nOutput Format: ${OUTPUT_FORMAT}"

if [[ -n "$CONTEXT" ]]; then
    FULL_PROMPT+="\nAdditional Context: ${CONTEXT}"
fi

# Add file context
file_context=$(build_file_context "${FILES[@]}") || exit 1
FULL_PROMPT+="\n\nFILES TO ANALYZE:\n${file_context}"

FULL_PROMPT+="\n\nPlease provide a comprehensive analysis following the deliverable format specified."

# ============================================================================
# CALL MODEL
# ============================================================================
content=$(call_model "$ANALYZE_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "$CONTINUATION_ID")

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

AGENT'S TURN: Analysis complete. Review the strategic findings and quick wins above. Prioritize improvements based on effort vs. benefit ratio."

extra_metadata=$(jq -nc \
    --argjson file_count "${#FILES[@]}" \
    --arg analysis_type "$ANALYSIS_TYPE" \
    --arg output_format "$OUTPUT_FORMAT" \
    '{files_analyzed: $file_count, analysis_type: $analysis_type, output_format: $output_format}')

format_output "$final_content" "analyze" "$MODEL" "$PROVIDER" "$extra_metadata"
