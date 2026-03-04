# youtube-summarizer

A skill that transcribes, summarizes, and researches YouTube videos. Works with Claude Code, Claude Desktop, [OpenClaw](https://github.com/openclaw/openclaw), and as a standalone CLI.

**Two modes:**
- **Summarize** (`summarize <url>`) — TL;DR, topics, key takeaways, and extracted links
- **Research** (`research <url>`) — Deep dive that visits every linked project, repo, and paper, then compiles a research report

The skill extracts links from both the video description *and* verbal mentions in the transcript — if the speaker talks about a GitHub repo, it constructs and includes the URL.

## Skills and Tools

A **tool** gives Claude the ability to take action — fetch data, call an API, read a file. Tools define *what operations are available*.

A **skill** teaches Claude *what to do* with those tools — workflows, output formats, decision logic, domain knowledge. A skill can use any combination of built-in tools (Bash, Read, Write), MCP tools, and bundled scripts.

```
Tool  = capability (fetch a transcript, search the web, read a file)
Skill = expertise  (when to fetch, how to format, what to extract)
```

This skill uses one bundled tool (`get_transcript.py`) but a skill can orchestrate many — for example, the Research mode uses the transcript tool, then web fetch to visit every extracted link, then synthesizes findings across all of them.

### Project structure

```
youtube-summarizer/
├── SKILL.md                    # Skill instructions (the expertise)
├── scripts/
│   └── get_transcript.py       # Bundled tool (the capability)
├── evals/
│   └── evals.json              # Test cases and assertions
├── install.sh                  # Installer for Claude Code / Desktop / OpenClaw
└── README.md
```

No `requirements.txt`, no `venv`, no `setup.py`. The script declares its own dependencies inline using [PEP 723](https://peps.python.org/pep-0723/):

```python
# /// script
# requires-python = ">=3.10"
# dependencies = ["yt-dlp", "mcp[cli]"]
# ///
```

[`uv`](https://docs.astral.sh/uv/) reads these inline metadata headers and auto-installs dependencies on first run into an isolated cache. This keeps the project structure minimal — the skill is just a SKILL.md and a script. No environment setup, no activation steps, no dependency conflicts. Anyone with `uv` installed can run the tool immediately.

### Why skills matter

Without this skill, Claude can fetch a transcript and write a summary on its own. But it won't extract links from verbal mentions, filter out promotional links, or follow a consistent output format. Our evals showed a **57% → 100%** improvement in assertion pass rate with the skill vs without. The tool is the same — the *instructions* make the difference.

### SKILL.md

A markdown file with YAML frontmatter. The frontmatter (`name`, `description`) is loaded into context at session start so Claude knows when to trigger the skill. The body is loaded when the skill activates.

The file is the same across platforms — only the *container* differs:

| Platform | Where SKILL.md lives |
|----------|---------------------|
| Claude Code | `~/.claude/skills/youtube-summarizer/SKILL.md` |
| Claude Desktop Chat tab | Uploaded as a ZIP via Customize → Skill |
| OpenClaw | `~/.openclaw/workspace/skills/youtube-summarizer/SKILL.md` |

### The tool: `get_transcript.py`

A Python script that fetches YouTube transcripts via yt-dlp. It runs in two modes — as a CLI (with args) or as an MCP server (without args) — from the same file. See [One Tool, Two Transports](#one-tool-two-transports-cli-vs-mcp) below.

## CLI vs MCP : One Tool, Two Transports

This is the interesting design decision. The same `get_transcript.py` script can be invoked two ways:

**CLI** — The skill tells Claude to run the script directly via Bash. Simple, self-contained, easy to debug. The skill carries its own tool.

**MCP** — The script runs as a persistent stdio server. Claude calls it through the MCP protocol. Requires config and a restart, but works on platforms that can't execute code directly.

### When to use which

| | CLI | MCP |
|---|---|---|
| **Setup** | None — skill runs the script directly | Config file + restart required |
| **Self-contained** | Yes — skill carries its own tool | No — depends on external config |
| **Debugging** | Normal stdout/stderr | Opaque — MCP errors are harder to trace |
| **Works in sandboxed environments** | No | Yes |
| **Best for** | Claude Code, OpenClaw | Claude Desktop Chat tab |

**The rule:** Use CLI on platforms that can execute code. Use MCP where they can't.

Claude Code and OpenClaw can run scripts directly — no MCP needed.

**The Claude Desktop Chat tab is sandboxed and requires MCP as a bridge.** The sandbox can't execute arbitrary code or make network calls — it can't run `yt-dlp`, `curl`, or any script that reaches out to the internet. MCP tools run *outside* the sandbox on your local machine, so they can make network calls on Claude's behalf and pass the results back in.

A dual-mode script lets you serve both transports from the same file. Write the tool once, deploy it as CLI or MCP depending on the platform.

## Prerequisites

- [**uv**](https://docs.astral.sh/uv/getting-started/installation/) — Python package runner (handles all dependencies automatically)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Quick Install

```bash
git clone https://github.com/madhancr/youtube-summarizer-skill.git
cd youtube-summarizer
./install.sh   # interactive menu — select one or more platforms
```

Or use flags directly:
```bash
./install.sh --claude-code      # Claude Code (symlink)
./install.sh --claude-desktop   # Claude Desktop Chat tab (MCP server + zip)
./install.sh --all              # Both
./install.sh --uninstall        # Remove all installations
```

## Installation

### OpenClaw

Copy the skill to your [OpenClaw](https://github.com/openclaw/openclaw) workspace:

```bash
cp -r /path/to/youtube-summarizer ~/.openclaw/workspace/skills/youtube-summarizer
```

The SKILL.md for OpenClaw uses an `exec` command instead of MCP to fetch transcripts. You'll need to adapt it for your server:

1. **Script path** — Update the `exec` command in SKILL.md to point to your copy of `scripts/get_transcript.py` (or `scripts/transcribe_video.py` if using local Whisper)
2. **Python environment** — If your server doesn't have `uv`, activate the appropriate venv before the script call
3. **Timeout** — Set `timeoutMs: 600000` (10 minutes) since transcript fetching can be slow for long videos

See the [OpenClaw skills documentation](https://docs.openclaw.ai/tools/skills) for more on workspace skills.

### Claude Desktop — Chat tab

The Chat tab can't execute code directly, so it needs **two things**:

1. **MCP server** — gives Claude the `get_youtube_transcript` tool to fetch transcripts
2. **ZIP upload** — gives Claude the skill instructions (SKILL.md) that define the summarize/research output formats

```bash
./install.sh --claude-desktop
```

This installs the MCP server config and creates the ZIP. Upload the generated `youtube-summarizer-chat.zip` to Claude Desktop via **Customize → Skill**.

> **Why both?** The MCP config gives Claude the *tool* to fetch transcripts, but the Chat tab can't read MCP config for instructions. The ZIP provides the *skill instructions* that tell Claude how to format summaries and research reports.

### Claude Code

```bash
./install.sh --claude-code
```

Restart Claude Code after installing. Then use it:
```
summarize https://youtu.be/VIDEO_ID
research https://youtu.be/VIDEO_ID
```

## Standalone CLI

Fetch any YouTube transcript directly:

```bash
uv run scripts/get_transcript.py "https://youtu.be/VIDEO_ID"
```

No install needed — `uv` handles dependencies automatically via PEP 723 inline metadata.

## Evals

Skills are only as good as their instructions. Evals measure what the skill actually adds by comparing **with-skill vs without-skill** output on the same prompts.

The `evals/` directory contains test cases that check link extraction from transcripts, output formatting, and filtering of promotional links. The delta matters more than absolute scores — without the skill, Claude still produces a summary, but misses verbal link mentions and includes promotional links.

Run evals with the [skill-creator](https://github.com/anthropics/claude-code/tree/main/plugins/skill-creator) plugin:
```
/skill-creator eval youtube-summarizer
```

The skill-creator can also generate new eval cases:
```
/skill-creator create-evals youtube-summarizer
```

## License

MIT
