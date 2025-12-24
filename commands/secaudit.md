---
id: secaudit
type: tool
script: scripts/secaudit.sh
---

# /secaudit

security audit

## usage

```
/secaudit -f src/auth.py
/secaudit -f api.py "check for vulns"
```

## execution

```bash
./scripts/secaudit.sh "$@"
```
