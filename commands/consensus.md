---
id: consensus
type: tool
script: scripts/consensus.sh
---

# /consensus

multi-model debate

## usage

```
/consensus "should we use redis or memcached?"
/consensus -m claude-sonnet-4-20250514,llama-3.3-70b "compare approaches"
```

## execution

```bash
./scripts/consensus.sh "$@"
```
