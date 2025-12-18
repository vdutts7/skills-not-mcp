#!/usr/bin/env zsh
# apilookup.sh - API/SDK documentation lookup
# Converted from: squad-mcp-server/tools/apilookup.py
# NOTE: This tool provides guidance for web search - it doesn't search itself

set -euo pipefail

usage() {
    cat >&2 << 'EOF'
Usage: apilookup.sh "<api_or_sdk_query>"

API/SDK documentation lookup guidance tool.

This tool provides structured guidance for looking up API documentation.
It does NOT perform web searches itself - use your web search tool.

Examples:
  apilookup.sh "React 19 new hooks"
  apilookup.sh "Python asyncio best practices"
  apilookup.sh "iOS 18 SwiftUI changes"
EOF
    exit 1
}

QUERY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) QUERY="$1"; shift ;;
    esac
done

[[ -z "$QUERY" ]] && { echo "Error: query required" >&2; usage; }

# Get current date for search guidance
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_YEAR=$(date +"%Y")

jq -nc \
    --arg query "$QUERY" \
    --arg date "$CURRENT_DATE" \
    --arg year "$CURRENT_YEAR" \
    '{
        "status": "lookup_guidance",
        "query": $query,
        "instructions": {
            "step_1": "Use your web search tool to research this query",
            "step_2": ("Include the current year (" + $year + ") in searches for latest info"),
            "step_3": "For OS-specific APIs, first search for the latest OS version",
            "step_4": "Prioritize official documentation sources",
            "step_5": "Verify version compatibility with your project"
        },
        "search_suggestions": [
            ($query + " documentation " + $year),
            ($query + " latest version"),
            ($query + " migration guide"),
            ($query + " breaking changes " + $year)
        ],
        "priority_sources": [
            "Official documentation sites",
            "GitHub repositories",
            "Release notes and changelogs",
            "Stack Overflow (recent answers)"
        ],
        "metadata": {
            "tool_name": "apilookup",
            "current_date": $date,
            "note": "This tool provides search guidance - use your web search tool to perform the actual lookup"
        }
    }'
