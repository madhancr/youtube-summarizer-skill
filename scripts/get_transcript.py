#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "yt-dlp",
#   "mcp[cli]",
# ]
# ///
"""YouTube transcript fetcher — CLI tool and MCP server.

CLI:  uv run get_transcript.py "https://youtu.be/VIDEO_ID"
MCP:  uv run get_transcript.py  (starts stdio server for Claude Desktop)
"""

import logging
import re
import sys
import tempfile
from pathlib import Path

import yt_dlp

# All logging to stderr — stdout is reserved for MCP JSON-RPC / CLI output
logging.basicConfig(stream=sys.stderr, level=logging.INFO)
logger = logging.getLogger("youtube-transcript")


def fetch_subtitles(url: str) -> tuple[str, str, str]:
    """Fetch English subtitles via yt-dlp.

    Returns (srt_text, title, description).
    Raises RuntimeError on failure.
    """
    with tempfile.TemporaryDirectory(prefix="subs_") as tmpdir:
        opts = {
            "quiet": True,
            "no_warnings": True,
            "noprogress": True,
            "skip_download": True,
            "writesubtitles": True,
            "writeautomaticsub": True,
            "subtitleslangs": ["en", "en-US", "en-GB"],
            "subtitlesformat": "srt",
            "outtmpl": str(Path(tmpdir) / "%(id)s.%(ext)s"),
        }
        try:
            with yt_dlp.YoutubeDL(opts) as ydl:
                info = ydl.extract_info(url, download=True)
                title = info.get("title", "Unknown")
                description = info.get("description", "")
                video_id = info.get("id", "video")
        except yt_dlp.utils.DownloadError as e:
            raise RuntimeError(f"Could not fetch video info: {e}")

        for lang in ["en", "en-US", "en-GB"]:
            srt_path = Path(tmpdir) / f"{video_id}.{lang}.srt"
            if srt_path.exists():
                return srt_path.read_text(encoding="utf-8"), title, description

    raise RuntimeError(
        "No English subtitles found. This tool only works with videos "
        "that have English captions (auto-generated or manual)."
    )


def strip_srt(srt_text: str) -> str:
    """Strip SRT formatting (sequence numbers, timestamps, HTML tags) to clean text."""
    lines = []
    for line in srt_text.splitlines():
        line = line.strip()
        if not line or line.isdigit() or "-->" in line:
            continue
        line = re.sub(r"<[^>]+>", "", line)
        if line:
            lines.append(line)
    return "\n".join(lines)


def get_transcript(url: str) -> str:
    """Fetch transcript for a YouTube video.

    Returns "TITLE: <title>\nDESCRIPTION: <description>\n<transcript>"
    or "ERROR: <message>" on failure.
    """
    logger.info("Fetching transcript for: %s", url)
    try:
        srt_text, title, description = fetch_subtitles(url)
        transcript = strip_srt(srt_text)
        logger.info("Success: %s (%d chars)", title, len(transcript))
        return f"TITLE: {title}\nDESCRIPTION: {description}\n{transcript}"
    except RuntimeError as e:
        logger.error("Failed: %s", e)
        return f"ERROR: {e}"
    except Exception as e:
        logger.error("Unexpected error: %s", e)
        return f"ERROR: Unexpected failure: {e}"


# --- MCP server registration (conditional) ---
try:
    from mcp.server.fastmcp import FastMCP

    mcp = FastMCP("youtube-transcript")

    @mcp.tool()
    def get_youtube_transcript(url: str) -> str:
        """Fetch the English transcript and description of a YouTube video.

        Takes a YouTube URL (any format) and returns the video title,
        description, and full transcript text. Uses subtitles/captions
        (auto-generated or manual) — no audio processing needed.

        Args:
            url: YouTube video URL (e.g. https://youtu.be/VIDEO_ID)

        Returns:
            "TITLE: <title>\nDESCRIPTION: <description>\n<transcript text>" on success,
            or an error message string on failure.
        """
        return get_transcript(url)

except ImportError:
    mcp = None


if __name__ == "__main__":
    if len(sys.argv) > 1:
        # CLI mode: print transcript to stdout
        print(get_transcript(sys.argv[1]))
    elif mcp:
        # MCP server mode (no args): start stdio server
        mcp.run()
    else:
        print("Usage: python get_transcript.py <YouTube URL>")
        print("(MCP mode unavailable — install mcp[cli] for server mode)")
        sys.exit(1)
