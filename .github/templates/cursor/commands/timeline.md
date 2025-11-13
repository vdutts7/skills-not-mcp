# timeline

Append-only project memory. Each project gets its own `*.timeline.json`.

## usage

```
/timeline add <type> <content>
```

**Types:** milestone, note, decision, blocker, resolution

## examples

```
/timeline add milestone "completed auth refactor"
/timeline add decision "chose postgres over sqlite"
/timeline add blocker "waiting on API access"
```

## rules

- Never modify or delete existing entries
- Each project has its own timeline file
- Entries are timestamped automatically
