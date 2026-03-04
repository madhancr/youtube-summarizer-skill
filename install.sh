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
do_uninstall=false

for arg in "$@"; do
    case "$arg" in
        --claude-code)    do_cc=true ;;
        --claude-desktop) do_cd=true ;;
        --all)            do_cc=true; do_cd=true ;;
        --uninstall)      do_uninstall=true ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --claude-code      Claude Code skill"
            echo "  --claude-desktop   Claude Desktop Chat tab (MCP server + zip)"
            echo "  --all              Both of the above"
            echo "  --uninstall        Remove all installations"
            echo "  -h, --help         Show this help"
            echo ""
            echo "With no flags, an interactive menu is shown."
            exit 0
            ;;
        *)
            red "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# ── Uninstall ──────────────────────────────────────────
if $do_uninstall; then
    echo ""
    echo "▸ Uninstalling youtube-summarizer"

    # Remove skill symlink
    if [[ -L "$SYMLINK_PATH" ]]; then
        rm "$SYMLINK_PATH"
        green "  ✓ Removed symlink $SYMLINK_PATH"
    elif [[ -e "$SYMLINK_PATH" ]]; then
        red "  ✗ $SYMLINK_PATH exists but is not a symlink. Remove it manually."
    else
        echo "  · No symlink found at $SYMLINK_PATH"
    fi

    # Remove MCP server from Claude Desktop config
    case "$(uname -s)" in
        Darwin) cd_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
        Linux)  cd_config="$HOME/.config/Claude/claude_desktop_config.json" ;;
        *)      cd_config="" ;;
    esac

    if [[ -n "$cd_config" && -f "$cd_config" ]]; then
        python3 -c "
import json, sys

config_path = sys.argv[1]
with open(config_path) as f:
    config = json.load(f)

if 'mcpServers' in config and 'youtube-transcript' in config['mcpServers']:
    del config['mcpServers']['youtube-transcript']
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    print('  ✓ Removed youtube-transcript from Claude Desktop config')
else:
    print('  · No youtube-transcript MCP server found in Claude Desktop config')
" "$cd_config"
    fi

    # Remove generated zip
    zip_path="$SKILL_DIR/youtube-summarizer-chat.zip"
    if [[ -f "$zip_path" ]]; then
        rm "$zip_path"
        green "  ✓ Removed $zip_path"
    fi

    echo ""
    yellow "  ↻ Restart Claude Code / Claude Desktop to apply changes."
    yellow "  Note: You'll need to manually remove the zip from Claude Desktop (Customize → Skill) if uploaded."
    echo ""
    green "Done!"
    exit 0
fi

# ── Interactive selection if no flags ──────────────────
if ! $do_cc && ! $do_cd; then
    echo "Select what to install (space-separated, e.g. 1 2):"
    echo ""
    echo "  1) Claude Code         — skill symlink"
    echo "  2) Claude Desktop Chat — MCP server + zip for Chat tab"
    echo ""
    printf "Choice: "
    read -r choices
    for c in $choices; do
        case "$c" in
            1) do_cc=true ;;
            2) do_cd=true ;;
            *) red "Unknown choice: $c"; exit 1 ;;
        esac
    done
    if ! $do_cc && ! $do_cd; then
        red "No selection made."
        exit 1
    fi
fi

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

# ── Claude Desktop Chat tab (MCP server + zip) ────────
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

    echo ""
    echo "▸ Claude Desktop Chat tab zip"
    zip_path="$SKILL_DIR/youtube-summarizer-chat.zip"
    (cd "$SKILL_DIR" && zip -j "$zip_path" SKILL.md) >/dev/null
    green "  ✓ Created $zip_path"
    yellow "  Upload this zip to Claude Desktop via Customize → Skill."
    yellow "  ↻ Restart Claude Desktop to pick up the MCP server."
fi

echo ""
green "Done!"
