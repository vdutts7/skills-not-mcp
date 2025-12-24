---
id: clink
type: tool
script: scripts/clink.sh
---

# /clink

CLI bridging

## usage

```
/clink "run npm test and explain output"
/clink -cmd "docker ps" "what containers are running?"
```

## execution

```bash
./scripts/clink.sh "$@"
```
