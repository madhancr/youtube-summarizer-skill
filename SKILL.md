---
name: youtube-summarizer
description: >
  Transcribe, summarize, and research YouTube videos. Read the full skill instructions before taking any action — they contain specific output formats, link extraction rules (including constructing URLs from verbal mentions in transcripts), and link filtering logic that cannot be guessed.
  Two modes:
  (1) Summarize: trigger on "sum URL", "summarize URL", "tldr URL", "what's this video about URL", any YouTube URL with a summary request, or a bare YouTube URL with no other instructions.
  (2) Research: trigger on "re URL", "research URL", or any YouTube URL with a research/deep-dive request.
  Do not activate for non-YouTube URLs or general summarization without a YouTube link.
---

# YouTube Video Summarizer & Researcher

## Step 1: Fetch the transcript (both modes)

Extract the YouTube URL from the user's message. Run the transcript fetcher bundled with this skill (dependencies auto-install via uv):

```
uv run "<SKILL_DIR>/scripts/get_transcript.py" "<YOUTUBE_URL>"
```

If the script is not available but the `youtube-transcript:get_youtube_transcript` MCP tool is,
use that instead — it returns the same format.

The output format:
```
TITLE: <video title>
DESCRIPTION: <video description>
<transcript text>
```

## Step 2: Determine mode

- **"sum"**, **"summarize"**, **"tldr"**, **"what's this video about"** → **Step 3A** (Summarize)
- **"re"**, **"research"** → **Step 3B** (Research)

---

## Step 3A: Summarize mode

**<Video Title>**

**TL;DR**
2-3 sentence overview.

**Topics covered**
- **Topic heading**: Brief description (2-3 sentences per topic)

**Key takeaways**
- 3-5 bullet points of the most important insights

**Links**
Collect links from BOTH the DESCRIPTION and transcript. Crucially, scan the transcript for any resource the speaker discusses — projects, repos, libraries, tools, research papers, blog posts, websites, datasets. Speakers often mention these by name without spelling out a URL. Construct the likely URL: GitHub repos (`https://github.com/<org>/<project>`), project homepages (`<project>.com` or `<project>.app`), arXiv papers (`https://arxiv.org/abs/<id>`), or search for the resource to find the correct URL. For example, if the speaker discusses "the World Monitor project and their GitHub repo", include both `https://worldmonitor.app` and `https://github.com/koala73/worldmonitor`. See link rules below. List only if useful links exist.
- [Link title](url) — one-line description of what it is

---

## Step 3B: Research mode

### 1. Extract links

Collect links from BOTH the description and transcript (see link rules below). Also scan the transcript for any resource discussed — projects, repos, libraries, tools, research papers, blog posts, websites, datasets. Construct likely URLs (GitHub repos, project homepages, arXiv papers, etc.) or search for them to find the correct link.

### 2. Visit all extracted links

For each useful link found, fetch it and extract:
- **GitHub repos**: repo description, star count, what it does, key features from README
- **Blog posts/docs**: main points, code examples, key takeaways
- **Papers**: title, abstract, key findings

If a link fails or is inaccessible, skip it and note it was unavailable.

### 3. Format the research report

**<Video Title> — Research Report**

**TL;DR**
3-4 sentence overview of the video content and key projects/tools discussed.

**Topics covered**
- **Topic heading**: Description with context from both the video and visited links (3-5 sentences per topic). Reference specific findings from the links.

**Projects & tools discussed**
For each project/tool mentioned:
- **[Project name](url)**: What it is, why it was mentioned in the video, key details from the repo/page (stars, language, recent activity if visible). 2-4 sentences.

**Key takeaways**
- 5-8 bullet points combining insights from the video AND the linked resources

**Links & resources**
- [Link title](url) — one-line description

---

## Link rules (apply to BOTH modes)

Extract links from the DESCRIPTION and from the transcript. Pay close attention to verbal mentions of any resource — projects, repos, tools, research papers, blog posts, websites, datasets. Speakers often reference these by name without reading out the full URL (e.g., "the World Monitor project", "their GitHub repo", "the paper by Smith et al.", "check out that blog post on LangChain's site"). When you hear a resource discussed in depth, construct or search for the likely URL:
- GitHub repos: `https://github.com/<org>/<project>`
- Project homepages: `<project>.com`, `<project>.app`, `<project>.dev`
- Research papers: `https://arxiv.org/abs/<id>` or search by title
- Blog posts/docs: search for the article title + site name

These transcript-derived links are just as important as description links — don't skip them.

**KEEP — useful links:**
- GitHub repos, GitLab repos, source code
- Blog posts, technical articles, documentation
- Papers (arXiv, research publications)
- Project homepages for tools/libraries discussed in the video
- Datasets, benchmarks, demos

**IGNORE — promotional/marketing links:**
- The creator's own social media (Twitter/X, Instagram, LinkedIn, Threads)
- Patreon, Buy Me a Coffee, Ko-fi, membership/donation links
- Merch stores
- Sponsor/affiliate links (Amazon affiliate, discount codes, coupon URLs)
- Newsletter signup links
- Podcast links
- "Subscribe" or "like" links
- The creator's own courses or paid products
- Discord/community invite links

**When in doubt:** If a link is to the creator promoting their own service/product rather than a technical resource discussed in the video, ignore it. Always look past the marketing — extract the substance.
