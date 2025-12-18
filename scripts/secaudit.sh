#!/usr/bin/env zsh
# secaudit.sh - Comprehensive security audit
# Converted from: squad-mcp-server/tools/secaudit.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "$SCRIPT_DIR/_base.sh"

SECAUDIT_PROMPT='You are an expert security auditor performing comprehensive security assessment. Focus on OWASP Top 10, authentication, authorization, input validation, cryptography, and configuration security.

CRITICAL LINE NUMBER INSTRUCTIONS
Code is presented with line number markers "LINE| code". Reference specific line numbers but NEVER include "LINE|" markers in generated code.

IF MORE INFORMATION IS NEEDED respond with:
{"status": "files_required_to_continue", "mandatory_instructions": "<instructions>", "files_needed": ["[file]"]}

SECURITY AUDIT AREAS:
- Authentication & Authorization: Session management, access control, privilege escalation
- Input Validation: SQL injection, XSS, command injection, path traversal
- Cryptography: Weak algorithms, key management, secure random
- Configuration: Hardcoded secrets, debug modes, insecure defaults
- Data Protection: Sensitive data exposure, logging, encryption at rest/transit

SEVERITY DEFINITIONS:
🔴 CRITICAL: Exploitable vulnerabilities with immediate risk
🟠 HIGH: Significant security weaknesses requiring urgent attention
🟡 MEDIUM: Security concerns that should be addressed
🟢 LOW: Minor security improvements

OUTPUT FORMAT:
## Executive Summary
Brief overview of security posture and critical findings.

## Vulnerabilities Found
[SEVERITY] File:Line - Vulnerability description
→ Risk: Impact explanation
→ Fix: Remediation steps

## Security Recommendations
Prioritized list of security improvements.

## Compliance Notes
Relevant compliance considerations (OWASP, PCI-DSS, etc.).'

usage() {
    cat >&2 << 'EOF'
Usage: secaudit.sh [OPTIONS] -f <file>

Comprehensive security audit tool.

Options:
  -m, --model MODEL    Model to use (default: claude-sonnet-4-20250514)
  -f, --file FILE      File to audit (required, can repeat)
  --focus AREA         Focus: owasp|auth|crypto|injection|config
  -h, --help           Show this help

Examples:
  secaudit.sh -f src/auth.py
  secaudit.sh -f api/ --focus injection
EOF
    exit 1
}

MODEL="claude-sonnet-4-20250514"
TEMPERATURE=0.5
FILES=()
FOCUS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -f|--file) FILES+=("$2"); shift 2 ;;
        --focus) FOCUS="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) shift ;;
    esac
done

[[ ${#FILES[@]} -eq 0 ]] && { echo "Error: at least one file required (-f)" >&2; usage; }

PROVIDER=$(detect_provider "$MODEL")

FULL_PROMPT="SECURITY AUDIT REQUEST"
[[ -n "$FOCUS" ]] && FULL_PROMPT+="\nFocus Area: ${FOCUS}"

file_context=$(build_file_context "${FILES[@]}") || exit 1
FULL_PROMPT+="\n\nFILES TO AUDIT:\n${file_context}"
FULL_PROMPT+="\n\nPerform a comprehensive security audit following the format specified."

content=$(call_model "$SECAUDIT_PROMPT" "$FULL_PROMPT" "$MODEL" "$TEMPERATURE" "")

if [[ $? -ne 0 ]] || echo "$content" | grep -q '"status".*:.*"files_required'; then
    echo "$content"
    exit $([[ $? -ne 0 ]] && echo 1 || echo 0)
fi

final_content="${content}\n\n---\n\nAGENT'S TURN: Security audit complete. Address CRITICAL and HIGH severity issues immediately."

extra_metadata=$(jq -nc --argjson fc "${#FILES[@]}" --arg focus "$FOCUS" '{files_audited: $fc, focus: $focus}')
format_output "$final_content" "secaudit" "$MODEL" "$PROVIDER" "$extra_metadata"
