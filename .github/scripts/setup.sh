#!/bin/bash
# setup.sh - run after cloning from template
# Works on ANY machine - no external dependencies

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# 1. Install hooks (the ONLY thing that matters)
mkdir -p .git/hooks
cp .github/hooks/* .git/hooks/ 2>/dev/null
chmod +x .git/hooks/* 2>/dev/null
echo "✓ Hooks installed"

# 2. Prompt user to set email (they pick which one)
echo ""
echo "Set your git email:"
echo "  git config user.email 'github.relock416@passmail.net'  # vdutts"
echo "  git config user.email 'me@vd7.io'                      # vdutts7"
echo ""
