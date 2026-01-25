<div align="center">

<img src="assets/icons/terminal.png" alt="terminal" width="80" height="80" />
<img src="assets/icons/skills.webp" alt="skills" width="80" height="80" />
<img src="assets/icons/mcp.png" alt="mcp" width="80" height="80" />

<h1 align="center">skills-not-mcp</h1>
<p align="center"><i><b>80-90% fewer tokens with Skills + Shell vs MCP</b></i></p>

[![Github][github]][github-url]

</div>

<br/>

## Table of Contents

<ol>
    <a href="#about">About</a><br/>
    <a href="#conversion-table">Conversion</a><br/>
    <a href="#pattern">Pattern</a><br/>
    <a href="#how-to-build">How to build</a><br/>
    <a href="#usage">Usage</a><br/>
    <a href="#tools-used">Tools</a><br/>
    <a href="#contact">Contact</a>
</ol>

<br/>

## About

**80-90% token savings** by replacing MCP with Skills + Shell scripts.

18 MCP tools from [pal-mcp-server](https://github.com/BeehiveInnovations/pal-mcp-server) converted to:
- **Claude Skills** (`commands/*.md`) - slash command interface
- **Shell scripts** (`scripts/*.sh`) - actual execution

| approach | tokens loaded | savings |
|----------|---------------|---------|
| MCP (18 tools) | ~12,500 always | baseline |
| Skills + Shell | ~50 per call | **80-90%** |

MCP loads all 18 tool schemas (~700 tokens each) into context whether you use them or not.

Skills + Shell loads nothing until called - then only the output.

## Conversion Table

<table>
<tr>
<th>#</th>
<th style="background-color:#ffcccb">MCP (before)</th>
<th style="background-color:#c1e1c1">Skill (after)</th>
<th style="background-color:#c1e1c1">Shell (after)</th>
</tr>
<tr><td>1</td><td style="background-color:#ffcccb"><code>tools/chat.py</code></td><td style="background-color:#c1e1c1"><code>commands/chat.md</code></td><td style="background-color:#c1e1c1"><code>scripts/chat.sh</code></td></tr>
<tr><td>2</td><td style="background-color:#ffcccb"><code>tools/thinkdeep.py</code></td><td style="background-color:#c1e1c1"><code>commands/thinkdeep.md</code></td><td style="background-color:#c1e1c1"><code>scripts/thinkdeep.sh</code></td></tr>
<tr><td>3</td><td style="background-color:#ffcccb"><code>tools/consensus.py</code></td><td style="background-color:#c1e1c1"><code>commands/consensus.md</code></td><td style="background-color:#c1e1c1"><code>scripts/consensus.sh</code></td></tr>
<tr><td>4</td><td style="background-color:#ffcccb"><code>tools/codereview.py</code></td><td style="background-color:#c1e1c1"><code>commands/codereview.md</code></td><td style="background-color:#c1e1c1"><code>scripts/codereview.sh</code></td></tr>
<tr><td>5</td><td style="background-color:#ffcccb"><code>tools/debug.py</code></td><td style="background-color:#c1e1c1"><code>commands/debug.md</code></td><td style="background-color:#c1e1c1"><code>scripts/debug.sh</code></td></tr>
<tr><td>6</td><td style="background-color:#ffcccb"><code>tools/planner.py</code></td><td style="background-color:#c1e1c1"><code>commands/planner.md</code></td><td style="background-color:#c1e1c1"><code>scripts/planner.sh</code></td></tr>
<tr><td>7</td><td style="background-color:#ffcccb"><code>tools/analyze.py</code></td><td style="background-color:#c1e1c1"><code>commands/analyze.md</code></td><td style="background-color:#c1e1c1"><code>scripts/analyze.sh</code></td></tr>
<tr><td>8</td><td style="background-color:#ffcccb"><code>tools/refactor.py</code></td><td style="background-color:#c1e1c1"><code>commands/refactor.md</code></td><td style="background-color:#c1e1c1"><code>scripts/refactor.sh</code></td></tr>
<tr><td>9</td><td style="background-color:#ffcccb"><code>tools/testgen.py</code></td><td style="background-color:#c1e1c1"><code>commands/testgen.md</code></td><td style="background-color:#c1e1c1"><code>scripts/testgen.sh</code></td></tr>
<tr><td>10</td><td style="background-color:#ffcccb"><code>tools/secaudit.py</code></td><td style="background-color:#c1e1c1"><code>commands/secaudit.md</code></td><td style="background-color:#c1e1c1"><code>scripts/secaudit.sh</code></td></tr>
<tr><td>11</td><td style="background-color:#ffcccb"><code>tools/docgen.py</code></td><td style="background-color:#c1e1c1"><code>commands/docgen.md</code></td><td style="background-color:#c1e1c1"><code>scripts/docgen.sh</code></td></tr>
<tr><td>12</td><td style="background-color:#ffcccb"><code>tools/apilookup.py</code></td><td style="background-color:#c1e1c1"><code>commands/apilookup.md</code></td><td style="background-color:#c1e1c1"><code>scripts/apilookup.sh</code></td></tr>
<tr><td>13</td><td style="background-color:#ffcccb"><code>tools/challenge.py</code></td><td style="background-color:#c1e1c1"><code>commands/challenge.md</code></td><td style="background-color:#c1e1c1"><code>scripts/challenge.sh</code></td></tr>
<tr><td>14</td><td style="background-color:#ffcccb"><code>tools/tracer.py</code></td><td style="background-color:#c1e1c1"><code>commands/tracer.md</code></td><td style="background-color:#c1e1c1"><code>scripts/tracer.sh</code></td></tr>
<tr><td>15</td><td style="background-color:#ffcccb"><code>tools/clink.py</code></td><td style="background-color:#c1e1c1"><code>commands/clink.md</code></td><td style="background-color:#c1e1c1"><code>scripts/clink.sh</code></td></tr>
<tr><td>16</td><td style="background-color:#ffcccb"><code>tools/precommit.py</code></td><td style="background-color:#c1e1c1"><code>commands/precommit.md</code></td><td style="background-color:#c1e1c1"><code>scripts/precommit.sh</code></td></tr>
<tr><td>17</td><td style="background-color:#ffcccb"><code>tools/listmodels.py</code></td><td style="background-color:#c1e1c1"><code>commands/listmodels.md</code></td><td style="background-color:#c1e1c1"><code>scripts/listmodels.sh</code></td></tr>
<tr><td>18</td><td style="background-color:#ffcccb"><code>tools/version.py</code></td><td style="background-color:#c1e1c1"><code>commands/version.md</code></td><td style="background-color:#c1e1c1"><code>scripts/version.sh</code></td></tr>
</table>

*Source: [pal-mcp-server](https://github.com/BeehiveInnovations/pal-mcp-server)*

## Pattern

**Deterministic Delegation** - Skills orchestrate, Shell executes

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
│  SAVINGS: 0%                                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│            SKILLS + SHELL (Deterministic Delegation)        │
│                                                             │
│  ┌────────┐                                                 │
│  │ /skill │ ────> shell script ────> output                │
│  │ ~50 tok│       (external)         (only this)           │
│  └────────┘                                                 │
│                                                             │
│  COST: ~50 tokens + output only                            │
│  SAVINGS: 80-90%                                            │
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
│  LAYER 1: SKILL (orchestrator)                 │
│  commands/*.md                                 │
│  - slash commands, routing, ~50 tokens each    │
└────────────────────────────────────────────────┘
                    │ delegates to
                    ▼
┌────────────────────────────────────────────────┐
│  LAYER 2: SHELL (execution)                    │
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

| property | MCP | Skills + Shell |
|----------|-----|----------------|
| schema loading | always (~12.5k) | never |
| token savings | 0% | **80-90%** |
| execution | probabilistic | deterministic |
| debugging | opaque | `bash -x script.sh` |

## How to build

```bash
git clone https://github.com/vdutts7/skills-not-mcp.git
cd skills-not-mcp/scripts
```

API keys:
```bash
export ANTHROPIC_API_KEY="sk-..."
export CEREBRAS_API_KEY="..."
# or local Ollama (no key)
```

## Usage

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

## Tools

[![Zsh][zsh-badge]][zsh-url]
[![jq][jq-badge]][jq-url]
[![curl][curl-badge]][curl-url]
[![Claude][claude-badge]][claude-url]
[![MCP][mcp-badge]][mcp-url]
[![SKILL.md][skill-badge]][skill-url]

## Contact

[![Website][website]][website-url]
[![Twitter][twitter]][twitter-url]

<!-- BADGES -->
[github]: https://img.shields.io/badge/skills--not--mcp-000000?style=for-the-badge&logo=github&logoColor=white
[github-url]: https://github.com/vdutts7/skills-not-mcp
[zsh-badge]: https://img.shields.io/badge/Zsh-000000?style=for-the-badge&logo=gnu-bash&logoColor=white
[zsh-url]: https://www.zsh.org/
[jq-badge]: https://img.shields.io/badge/jq-000000?style=for-the-badge
[jq-url]: https://jqlang.github.io/jq/
[curl-badge]: https://img.shields.io/badge/curl-000000?style=for-the-badge&logo=curl&logoColor=white
[curl-url]: https://curl.se/
[claude-badge]: https://img.shields.io/badge/Claude-000000?style=for-the-badge&logo=anthropic&logoColor=white
[claude-url]: https://claude.ai/
[mcp-badge]: https://img.shields.io/badge/MCP-000000?style=for-the-badge
[mcp-url]: https://modelcontextprotocol.io/
[skill-badge]: https://img.shields.io/badge/SKILL.md-000000?style=for-the-badge
[skill-url]: https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/skills
[website]: https://img.shields.io/badge/vd7.io-000000?style=for-the-badge&logo=Safari&logoColor=white
[website-url]: https://vd7.io
[twitter]: https://img.shields.io/badge//vdutts7-000000?style=for-the-badge&logo=X&logoColor=white
[twitter-url]: https://x.com/vdutts7
