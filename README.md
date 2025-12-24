<div align="center">

<img src="assets/icons/terminal.png" alt="terminal" width="80" height="80" />
<img src="assets/icons/mcp.png" alt="mcp" width="80" height="80" />

<h1 align="center">shell-vs-mcp</h1>
<p align="center"><i><b>shell > MCP for tokens</b></i></p>

[![Github][github]][github-url]

</div>

<br/>

## Table of Contents

<ol>
    <a href="#about">📝 About</a><br/>
    <a href="#pattern">⚡ Pattern</a><br/>
    <a href="#how-to-build">💻 How to build</a><br/>
    <a href="#usage">🚀 Usage</a><br/>
    <a href="#tools-used">🔧 Tools</a><br/>
    <a href="#contact">👤 Contact</a>
</ol>

<br/>

## 📝About

18 MCP tools from [pal-mcp-server](https://github.com/BeehiveInnovations/pal-mcp-server) -> shell scripts

MCP schemas = ~500-2k tokens/tool loaded into context whether used or not. 18 tools = 10-30k overhead before asking anything

shell = 0 tokens til called

## ⚡Pattern

**deterministic delegation**

```
┌─────────────────────────────────────────────────────────────┐
│                    MCP APPROACH                             │
│                                                             │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐              │
│  │ tool 1 │ │ tool 2 │ │ tool 3 │ │ ...18  │              │
│  │ ~700   │ │ ~700   │ │ ~700   │ │ tokens │              │
│  └────────┘ └────────┘ └────────┘ └────────┘              │
│                                                             │
│  COST: ~12,500 tokens ALWAYS LOADED                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│               DETERMINISTIC DELEGATION                      │
│                                                             │
│  ┌────────┐                                                 │
│  │/command│ ────> shell script ────> output                │
│  │ ~50 tok│       (external)         (only this)           │
│  └────────┘                                                 │
│                                                             │
│  COST: ~50 tokens + output only                            │
└─────────────────────────────────────────────────────────────┘
```

**flow:**
```
USER                    AI                      SHELL
 │                       │                        │
 │  "/chat review this"  │                        │
 │ ───────────────────>  │                        │
 │                       │  exec chat.sh          │
 │                       │ ────────────────────>  │
 │                       │                        │
 │                       │      ┌─────────────────┤
 │                       │      │ - parse args    │
 │                       │      │ - detect model  │
 │                       │      │ - call API      │
 │                       │      │ - format output │
 │                       │      └─────────────────┤
 │                       │                        │
 │                       │  JSON result           │
 │                       │ <────────────────────  │
 │                       │                        │
 │  formatted response   │                        │
 │ <───────────────────  │                        │
```

**layers:**
```
┌────────────────────────────────────────────────┐
│  LAYER 1: COMMAND (orchestrator)               │
│  commands/*.md                                 │
│  - routing, docs, ~50 tokens each              │
└────────────────────────────────────────────────┘
                    │ delegates to
                    ▼
┌────────────────────────────────────────────────┐
│  LAYER 2: SCRIPT (execution)                   │
│  scripts/*.sh                                  │
│  - actual logic, 0 tokens til called           │
└────────────────────────────────────────────────┘
                    │ calls
                    ▼
┌────────────────────────────────────────────────┐
│  LAYER 3: PROVIDER (external)                  │
│  Anthropic / OpenAI / Ollama / etc             │
└────────────────────────────────────────────────┘
```

| property | MCP | deterministic delegation |
|----------|-----|--------------------------|
| schema loading | always | never |
| execution | probabilistic | deterministic |
| context cost | O(n) tools | O(1) per call |
| debugging | opaque | `bash -x script.sh` |

## 💻How to build

```bash
git clone https://github.com/vdutts/shell-vs-mcp.git
cd shell-vs-mcp/scripts
```

API keys:
```bash
export ANTHROPIC_API_KEY="sk-..."
export CEREBRAS_API_KEY="..."
# or local Ollama (no key)
```

## 🚀Usage

```bash
# claude
./chat.sh -m claude-sonnet-4-20250514 "structure this API?"

# ollama (free/local)
./chat.sh -m qwen2.5-coder:7b "review this"

# file context
./chat.sh -f src/main.py -f src/utils.py "explain flow"

# multi-turn
./chat.sh -c sess1 "design cache"
./chat.sh -c sess1 "redis vs memcached?"

# code review
./codereview.sh -m llama-3.3-70b -f src/auth.py

# demo
./demo.sh
```

| | provider | models | env |
|:---:|----------|--------|-----|
| <img src="assets/icons/providers/anthropic.webp" width="16"> | Anthropic | sonnet-4, opus-4 | `ANTHROPIC_API_KEY` |
| <img src="assets/icons/providers/cerebras.webp" width="16"> | Cerebras | llama-3.3-70b, qwen-3-32b | `CEREBRAS_API_KEY` |
| <img src="assets/icons/providers/ollama.webp" width="16"> | Ollama | qwen2.5-coder, llama, mistral | local |
| <img src="assets/icons/providers/openai.webp" width="16"> | OpenAI | gpt-4o, o1, o3 | `OPENAI_API_KEY` |
| <img src="assets/icons/providers/gemini.webp" width="16"> | Gemini | 2.0-flash | `GEMINI_API_KEY` |
| <img src="assets/icons/providers/openrouter.webp" width="16"> | OpenRouter | any | `OPENROUTER_API_KEY` |

| approach | tokens |
|----------|--------|
| MCP (18 tools) | ~12.5k |
| shell | 0 til called |

## 🔧Tools

[![Zsh][zsh-badge]][zsh-url]
[![jq][jq-badge]][jq-url]
[![curl][curl-badge]][curl-url]

## 👤Contact

[![Email][email]][email-url]
[![Twitter][twitter]][twitter-url]

<!-- BADGES -->
[github]: https://img.shields.io/badge/💻_shell-vs-mcp-000000?style=for-the-badge
[github-url]: https://github.com/vdutts/shell-vs-mcp
[zsh-badge]: https://img.shields.io/badge/Zsh-000000?style=for-the-badge&logo=gnu-bash&logoColor=white
[zsh-url]: https://www.zsh.org/
[jq-badge]: https://img.shields.io/badge/jq-000000?style=for-the-badge
[jq-url]: https://jqlang.github.io/jq/
[curl-badge]: https://img.shields.io/badge/curl-000000?style=for-the-badge&logo=curl&logoColor=white
[curl-url]: https://curl.se/
[email]: https://img.shields.io/badge/Email-000000?style=for-the-badge&logo=Gmail&logoColor=white
[email-url]: mailto:me@vd7.io
[twitter]: https://img.shields.io/badge/Twitter-000000?style=for-the-badge&logo=Twitter&logoColor=white
[twitter-url]: https://x.com/vdutts7
