---
id: chat
type: tool
script: scripts/chat.sh
---

# /chat

multi-provider AI chat

## usage

```
/chat "prompt"
/chat -m claude-sonnet-4-20250514 "prompt"
/chat -m qwen2.5-coder:7b "local"
/chat -f file.py "with context"
/chat -c session1 "multi-turn"
```

## execution

```bash
./scripts/chat.sh "$@"
```
