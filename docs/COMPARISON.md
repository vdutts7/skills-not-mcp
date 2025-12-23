# MCP vs Shell Scripts: Side-by-Side Comparison

## The Source: pal-mcp-server

[BeehiveInnovations/pal-mcp-server](https://github.com/BeehiveInnovations/pal-mcp-server) - 10.9k stars, 18 tools, Python-based MCP server.

## Architecture Comparison

### MCP Approach (pal-mcp-server)

```
User → AI Agent (Cursor/Claude Code)
         ↓
    MCP Protocol (JSON-RPC)
         ↓
    Python MCP Server (server.py)
         ↓
    Tool Class (tools/chat.py)
         ↓
    Provider Abstraction (providers/*.py)
         ↓
    HTTP API Call
```

**Files involved for `chat` tool:**
- `server.py` - MCP server entry point
- `tools/chat.py` - Tool implementation (390 lines)
- `tools/simple/base.py` - Base class (~500 lines)
- `tools/shared/base_models.py` - Pydantic models
- `systemprompts/chat_prompt.py` - System prompts
- `providers/shared.py` - Provider abstraction
- `providers/anthropic.py`, `providers/openai.py`, etc.

**Total: ~2000+ lines across 10+ files**

### Shell Approach (SQUAD)

```
User → AI Agent (Cursor/Claude Code)
         ↓
    Shell Tool Call
         ↓
    chat.sh (self-contained)
         ↓
    curl → HTTP API
```

**Files involved for `chat` tool:**
- `chat.sh` - Complete implementation (726 lines)
- `_base.sh` - Shared functions (463 lines, optional)

**Total: 726 lines in 1 file (or 1189 with shared base)**

## Feature Parity

| Feature | MCP (chat.py) | Shell (chat.sh) |
|---------|---------------|-----------------|
| Multi-provider | ✅ 7 providers | ✅ 6 providers |
| File context | ✅ `absolute_file_paths` | ✅ `-f` flag |
| Line numbers in context | ✅ | ✅ |
| Conversation continuation | ✅ `continuation_id` | ✅ `-c` flag |
| Code generation mode | ✅ `GENERATE_CODE_PROMPT` | ✅ `--code-gen` |
| Artifact extraction | ✅ `pal_generated.code` | ✅ `squad_generated.code` |
| Temperature control | ✅ | ✅ `-t` flag |
| Thinking modes | ✅ | ✅ `--thinking` |
| Image/vision support | ✅ | ❌ Not implemented |
| Provider fallback | ✅ | ✅ via `models.json` |

## Context Window Cost

### MCP Tool Schema (loaded into context)

```json
{
  "name": "chat",
  "description": "General chat and collaborative thinking partner for brainstorming...",
  "inputSchema": {
    "type": "object",
    "properties": {
      "prompt": {
        "type": "string",
        "description": "Your question or idea for collaborative thinking..."
      },
      "absolute_file_paths": {
        "type": "array",
        "items": {"type": "string"},
        "description": "Full, absolute file paths to relevant code..."
      },
      "images": {...},
      "working_directory_absolute_path": {...},
      "model": {...},
      "temperature": {...},
      "thinking_mode": {...},
      "continuation_id": {...}
    },
    "required": ["prompt", "working_directory_absolute_path"]
  }
}
```

**Estimated tokens: ~800-1200 per tool**

With 18 tools enabled: **~15,000-22,000 tokens** just for schemas.

### Shell Script (loaded into context)

```
(nothing until called)
```

**Tokens: 0**

When called, only the output enters context - typically 500-2000 tokens of actual response.

## Debugging Comparison

### MCP Debugging

```bash
# Enable debug logging
LOG_LEVEL=DEBUG python server.py

# Trace JSON-RPC messages
# (requires MCP inspector or custom logging)

# Check tool registration
# (requires understanding MCP protocol)
```

### Shell Debugging

```bash
# Trace execution
bash -x chat.sh -m claude-sonnet-4-20250514 "test"

# See exact curl command
# (visible in trace output)

# Test API directly
curl -sS "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":100,"messages":[{"role":"user","content":"hi"}]}'
```

## Dependency Comparison

### MCP (pal-mcp-server)

```
# requirements.txt
mcp>=1.1.0
pydantic>=2.0
httpx>=0.27
aiohttp>=3.9
python-dotenv>=1.0
# ... plus transitive dependencies
```

**Total: ~50+ packages after resolution**

### Shell (SQUAD)

```
# System tools (pre-installed on macOS/Linux)
curl
jq
zsh/bash
```

**Total: 2-3 tools, already installed**

## When to Use Which

### Use MCP When:

1. **Building for others** - They need discoverability, schemas, documentation
2. **IDE integration** - Want autocomplete, parameter hints, validation
3. **Tool marketplace** - Publishing tools for ecosystem consumption
4. **Enterprise** - Need audit trails, permissions, standardization
5. **Non-technical users** - Need guided tool discovery

### Use Shell Scripts When:

1. **You're the user** - You know what tools exist
2. **Token efficiency matters** - Paying per token, optimizing context
3. **Debugging** - Need to trace exactly what's happening
4. **Minimal dependencies** - Don't want Python/Node runtime
5. **Scripting/automation** - Chaining tools in pipelines
6. **Offline/air-gapped** - Can't install packages

## The Bottom Line

MCP is infrastructure for **tool ecosystems**. It's the "app store" model.

Shell scripts are **direct tool invocation**. It's "compiling from source."

Both are valid. Choose based on your use case, not hype.
