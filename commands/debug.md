---
id: debug
type: tool
script: scripts/debug.sh
---

# /debug

debugging assistant

## usage

```
/debug -f broken.py "why is this failing?"
/debug -f file.py -e "TypeError: cannot read property"
```

## execution

```bash
./scripts/debug.sh "$@"
```
