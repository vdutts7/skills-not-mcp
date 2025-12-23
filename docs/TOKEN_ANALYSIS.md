# Token Analysis: MCP Schema Overhead

## Methodology

Token counts estimated using Claude's tokenizer (cl100k_base approximation).

## MCP Tool Schemas (pal-mcp-server)

Each MCP tool registers a schema that gets loaded into the AI's context window.

### Individual Tool Costs

| Tool | Schema Tokens | Description Tokens | Total |
|------|---------------|-------------------|-------|
| chat | ~400 | ~300 | ~700 |
| thinkdeep | ~350 | ~400 | ~750 |
| consensus | ~500 | ~350 | ~850 |
| codereview | ~450 | ~400 | ~850 |
| debug | ~400 | ~350 | ~750 |
| planner | ~400 | ~300 | ~700 |
| precommit | ~450 | ~350 | ~800 |
| analyze | ~400 | ~300 | ~700 |
| refactor | ~350 | ~300 | ~650 |
| testgen | ~400 | ~350 | ~750 |
| secaudit | ~400 | ~400 | ~800 |
| docgen | ~350 | ~300 | ~650 |
| apilookup | ~300 | ~250 | ~550 |
| challenge | ~300 | ~300 | ~600 |
| tracer | ~350 | ~300 | ~650 |
| clink | ~500 | ~400 | ~900 |
| listmodels | ~200 | ~150 | ~350 |
| version | ~150 | ~100 | ~250 |

### Aggregate Costs

| Configuration | Tools Loaded | Token Overhead |
|---------------|--------------|----------------|
| All tools enabled | 18 | ~12,500 |
| Default (pal-mcp-server) | 12 | ~8,500 |
| Minimal (chat only) | 1 | ~700 |

## Shell Script Approach (SQUAD)

| Configuration | Tools Available | Token Overhead |
|---------------|-----------------|----------------|
| All scripts | 18 | **0** |
| Any subset | N | **0** |

Scripts only consume tokens when:
1. You invoke them (command appears in context)
2. Their output returns (response enters context)

## Real-World Impact

### Scenario: Code Review Session

**MCP Approach:**
```
Context budget: 200,000 tokens (Claude Sonnet 4)
- Tool schemas: -12,500 tokens
- System prompt: -2,000 tokens
- Available for code: 185,500 tokens
```

**Shell Approach:**
```
Context budget: 200,000 tokens
- Tool schemas: -0 tokens
- System prompt: -2,000 tokens
- Available for code: 198,000 tokens
```

**Difference: 12,500 tokens = ~6% more context for actual work**

### Scenario: Large Codebase Analysis

When analyzing a 50-file codebase:
- Average file: 200 lines × 4 tokens/line = 800 tokens
- 50 files = 40,000 tokens of code

**MCP:** 40,000 + 12,500 = 52,500 tokens consumed
**Shell:** 40,000 + 0 = 40,000 tokens consumed

**Shell gives you room for 15+ more files in the same context window.**

## Cost Implications

At Claude Sonnet 4 pricing ($3/1M input tokens):

| Session Type | MCP Overhead Cost | Shell Overhead Cost |
|--------------|-------------------|---------------------|
| Single query | $0.0375 | $0.00 |
| 10 queries/day | $0.375 | $0.00 |
| 100 queries/day | $3.75 | $0.00 |
| Monthly (3000 queries) | $112.50 | $0.00 |

**Annual savings for heavy user: ~$1,350**

## The pal-mcp-server Acknowledgment

The pal-mcp-server README explicitly acknowledges this problem:

> "Each tool comes with its own multi-step workflow, parameters, and descriptions that **consume valuable context window space even when not in use**. To optimize performance, some tools are disabled by default."

Their solution: `DISABLED_TOOLS` config to turn off unused tools.

Our solution: Don't load schemas at all. Call scripts directly.

## Conclusion

MCP's schema overhead is a real cost. For power users who:
- Know what tools they need
- Optimize for context efficiency
- Pay per token

Shell scripts eliminate this overhead entirely.
