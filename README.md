<div align="center">

<h1 align="center">SQUAD</h1>
<p align="center"><i><b>Shell scripts > MCP for token efficiency</b></i></p>

[![Github][github]][github-url]

</div>

<br/>

## Table of Contents

<ol>
    <a href="#about">📝 About</a><br/>
    <a href="#how-to-build">💻 How to build</a><br/>
    <a href="#usage">🚀 Usage</a><br/>
    <a href="#tools-used">🔧 Tools used</a><br/>
    <a href="#contact">👤 Contact</a>
</ol>

<br/>

## 📝About

18 MCP tools from [pal-mcp-server](https://github.com/BeehiveInnovations/pal-mcp-server) converted to shell scripts.

**why:** MCP schemas load ~500-2000 tokens per tool into context window whether used or not. 18 tools = 10-30k tokens overhead before you ask anything.

shell scripts = 0 tokens until called.

## 💻How to build

```bash
git clone https://github.com/vdutts/squad.git
cd squad/scripts
```

set API keys:
```bash
export ANTHROPIC_API_KEY="sk-..."
export CEREBRAS_API_KEY="..."
# or use local Ollama (no key needed)
```

## 🚀Usage

```bash
# chat w/ claude
./chat.sh -m claude-sonnet-4-20250514 "structure this API?"

# local ollama (free/private)
./chat.sh -m qwen2.5-coder:7b "review this function"

# file context
./chat.sh -f src/main.py -f src/utils.py "explain data flow"

# multi-turn
./chat.sh -c session123 "design caching layer"
./chat.sh -c session123 "redis vs memcached?"

# code review
./codereview.sh -m llama-3.3-70b -f src/auth.py

# demo
./demo.sh
```

**providers:**

| provider | models | env var |
|----------|--------|---------|
| Anthropic | claude-sonnet-4, opus-4 | `ANTHROPIC_API_KEY` |
| Cerebras | llama-3.3-70b, qwen-3-32b | `CEREBRAS_API_KEY` |
| Ollama | qwen2.5-coder, llama, mistral | (local) |
| OpenAI | gpt-4o, o1, o3 | `OPENAI_API_KEY` |
| Gemini | gemini-2.0-flash | `GEMINI_API_KEY` |
| OpenRouter | any | `OPENROUTER_API_KEY` |

**token overhead:**

| approach | context cost |
|----------|--------------|
| MCP (18 tools) | ~12,500 tokens |
| shell scripts | 0 until called |

see [docs/TOKEN_ANALYSIS.md](docs/TOKEN_ANALYSIS.md) + [docs/COMPARISON.md](docs/COMPARISON.md)

## 🔧Tools Used

[![Zsh][zsh-badge]][zsh-url]
[![jq][jq-badge]][jq-url]
[![curl][curl-badge]][curl-url]

## 👤Contact

[![Email][email]][email-url]
[![Twitter][twitter]][twitter-url]

<!-- BADGES -->
[github]: https://img.shields.io/badge/💻_SQUAD-000000?style=for-the-badge
[github-url]: https://github.com/vdutts/squad
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
