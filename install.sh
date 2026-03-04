#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_NAME="youtube-summarizer"
SYMLINK_DIR="$HOME/.claude/skills"
SYMLINK_PATH="$SYMLINK_DIR/$SKILL_NAME"

# ── Colors ──────────────────────────────────────────────
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
red()    { printf '\033[31m%s\033[0m\n' "$1"; }

# ── Parse flags ─────────────────────────────────────────
do_cc=false
do_cd=false
do_zip=false

if [[ $# -eq 0 ]] ; then
    do_cc=true; do_cd=true; do_zip=true
fi

for arg in "$@"; do
    case "$arg" in
        --claude-code)    do_cc=true ;;
        --claude-desktop) do_cd=true ;;
        --chat-zip)       do_zip=true ;;
        --all)            do_cc=true; do_cd=true; do_zip=true ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options (default: all three):"
            echo "  --claude-code      Install as Claude Code skill (symlink)"
            echo "  --claude-desktop   Install as Claude Desktop MCP server"
            echo "  --chat-zip         Create zip for Claude Desktop Chat tab"
            echo "  --all              All of the above (same as no args)"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
        *)
            red "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# ── Prerequisites ───────────────────────────────────────
if ! command -v uv &>/dev/null; then
    red "Error: 'uv' is not installed."
    echo "Install it with:  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# ── Claude Code skill ──────────────────────────────────
if $do_cc; then
    echo ""
    echo "▸ Claude Code skill"
    mkdir -p "$SYMLINK_DIR"

    if [[ -L "$SYMLINK_PATH" ]]; then
        current_target="$(readlink "$SYMLINK_PATH")"
        if [[ "$current_target" == "$SKILL_DIR" ]]; then
            green "  ✓ Symlink already correct → $SKILL_DIR"
        else
            ln -sfn "$SKILL_DIR" "$SYMLINK_PATH"
            green "  ✓ Symlink updated → $SKILL_DIR (was $current_target)"
        fi
    elif [[ -e "$SYMLINK_PATH" ]]; then
        red "  ✗ $SYMLINK_PATH exists and is not a symlink. Remove it manually first."
        exit 1
    else
        ln -s "$SKILL_DIR" "$SYMLINK_PATH"
        green "  ✓ Symlink created → $SKILL_DIR"
    fi
    yellow "  ↻ Restart Claude Code to pick up the skill."
fi

# ── Claude Desktop MCP server ──────────────────────────
if $do_cd; then
    echo ""
    echo "▸ Claude Desktop MCP server"

    case "$(uname -s)" in
        Darwin) cd_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
        Linux)  cd_config="$HOME/.config/Claude/claude_desktop_config.json" ;;
        *)      red "  ✗ Unsupported OS for Claude Desktop config"; exit 1 ;;
    esac

    script_path="$SKILL_DIR/scripts/get_transcript.py"

    python3 -c "
import json, os, sys

config_path = sys.argv[1]
script_path = sys.argv[2]

# Read existing config or start fresh
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
else:
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    config = {}

config.setdefault('mcpServers', {})
config['mcpServers']['youtube-transcript'] = {
    'command': 'uv',
    'args': ['run', script_path],
}

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print(f'  Updated: {config_path}')
" "$cd_config" "$script_path"

    green "  ✓ MCP server 'youtube-transcript' configured"
    yellow "  ↻ Restart Claude Desktop to pick up the MCP server."
fi

# ── Chat tab zip ────────────────────────────────────────
if $do_zip; then
    echo ""
    echo "▸ Claude Desktop Chat tab zip"
    zip_path="$SKILL_DIR/youtube-summarizer-chat.zip"
    (cd "$SKILL_DIR" && zip -j "$zip_path" SKILL.md) >/dev/null
    green "  ✓ Created $zip_path"
    echo "  Upload instructions:"
    echo "    1. Open Claude Desktop → Chat tab"
    echo "    2. Open or create a Project"
    echo "    3. Add the zip to the project knowledge"
    echo "    4. The MCP server (--claude-desktop) is also needed for full functionality"
fi

echo ""
green "Done!"
