#!/bin/bash
# setup.sh - run after cloning from template

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# 1. Git config
~/.bin/git-set-personal 2>/dev/null || echo "⚠ Run ~/.bin/git-set-personal"

# 2. Hooks
cp .github/hooks/* .git/hooks/ 2>/dev/null && chmod +x .git/hooks/* && echo "✓ Hooks"

# 3. Repo config
if command -v jq &>/dev/null && [[ -f "repo.config.json" ]]; then
    DESC=$(jq -r '.repo.description' repo.config.json)
    HOMEPAGE=$(jq -r '.repo.homepage' repo.config.json)
    TOPICS=$(jq -r '.repo.topics | join(" ")' repo.config.json)
    
    [[ "$DESC" != "null" ]] && gh repo edit --description "$DESC" 2>/dev/null && echo "✓ Description"
    [[ "$HOMEPAGE" != "null" ]] && gh repo edit --homepage "$HOMEPAGE" 2>/dev/null && echo "✓ Homepage"
    for t in $TOPICS; do gh repo edit --add-topic "$t" 2>/dev/null; done && echo "✓ Topics"
    
    OWNER=$(gh repo view --json owner -q '.owner.login' 2>/dev/null)
    MAIN=$(jq -r '.workflows.main_account' repo.config.json)
    [[ "$OWNER" != "$MAIN" ]] && gh-share 2>/dev/null && echo "✓ Shared"
fi

echo "✓ Done"
