---
id: tracer
type: tool
script: scripts/tracer.sh
---

# /tracer

call flow tracing

## usage

```
/tracer -f src/main.py "trace handleRequest"
/tracer -f file.py -fn functionName
```

## execution

```bash
./scripts/tracer.sh "$@"
```
