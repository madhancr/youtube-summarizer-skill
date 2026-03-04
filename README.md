# youtube-summarizer

A Claude skill that transcribes, summarizes, and researches YouTube videos. Works with Claude Code, Claude Desktop, and as a standalone CLI.

**Two modes:**
- **Summarize** (`sum <url>`) — TL;DR, topics, key takeaways, and extracted links
- **Research** (`re <url>`) — Deep dive that visits every linked project, repo, and paper, then compiles a research report

The skill extracts links from both the video description *and* verbal mentions in the transcript — if the speaker talks about a GitHub repo, it constructs and includes the URL.

## Prerequisites

- [**uv**](https://docs.astral.sh/uv/getting-started/installation/) — Python package runner (handles all dependencies automatically)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Quick Install

```bash
git clone https://github.com/madhancr/youtube-summarizer.git
cd youtube-summarizer
./install.sh
```

This installs for all three Claude platforms. Use flags to install selectively:

```bash
./install.sh --claude-code      # Claude Code skill only
./install.sh --claude-desktop   # Claude Desktop MCP server only
./install.sh --chat-zip         # Create zip for Claude Desktop Chat tab
```

## Installation

### Claude Code (skill)

**Automated:**
```bash
./install.sh --claude-code
```

**Manual:**
```bash
mkdir -p ~/.claude/skills
ln -s /path/to/youtube-summarizer ~/.claude/skills/youtube-summarizer
```

Restart Claude Code. Then use it:
```
sum https://youtu.be/VIDEO_ID
research https://youtu.be/VIDEO_ID
```

### Claude Desktop — Code tab (MCP server)

**Automated:**
```bash
./install.sh --claude-desktop
```

**Manual:** Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS, `~/.config/Claude/claude_desktop_config.json` on Linux):

```json
{
  "mcpServers": {
    "youtube-transcript": {
      "command": "uv",
      "args": ["run", "/absolute/path/to/youtube-summarizer/scripts/get_transcript.py"]
    }
  }
}
```

Restart Claude Desktop. The `get_youtube_transcript` tool will be available in the Code tab.

### Claude Desktop — Chat tab (zip upload)

**Automated:**
```bash
./install.sh --chat-zip
```

Then upload the generated `youtube-summarizer-chat.zip`:
1. Open Claude Desktop → Chat tab
2. Open or create a Project
3. Add the zip to the project knowledge

Note: The MCP server (`--claude-desktop`) is also needed for the Chat tab to fetch transcripts.

## Standalone CLI

Fetch any YouTube transcript directly:

```bash
uv run scripts/get_transcript.py "https://youtu.be/VIDEO_ID"
```

Output format:
```
TITLE: <video title>
DESCRIPTION: <video description>
<transcript text>
```

No install needed — `uv` handles dependencies automatically via [PEP 723](https://peps.python.org/pep-0723/) inline metadata.

## How It Works

- **Dual-mode script** — `get_transcript.py` runs as a CLI tool (with args) or an MCP server (without args)
- **PEP 723 inline metadata** — Dependencies (`yt-dlp`, `mcp[cli]`) are declared in the script header; `uv` auto-installs them
- **yt-dlp subtitles** — Fetches English captions (auto-generated or manual) without downloading video/audio
- **SRT stripping** — Removes timestamps and formatting to produce clean text
- **SKILL.md** — Defines the two output modes (summarize/research) and link extraction rules that Claude follows

## Evals

The `evals/` directory contains test cases that verify the skill produces correct output — proper link extraction from transcripts, correct section formatting, and filtering of promotional links.

Run evals with the [skill-creator](https://github.com/anthropics/claude-code/tree/main/plugins/skill-creator) plugin:
```
/skill-creator eval youtube-summarizer
```

## License

MIT
