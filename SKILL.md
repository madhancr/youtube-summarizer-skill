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
Collect candidate links from BOTH the DESCRIPTION and transcript. Scan the transcript for any resource the speaker discusses — projects, repos, libraries, tools, research papers, blog posts, websites, datasets. Speakers often mention these by name without spelling out a URL. Construct candidate URLs, then **verify all of them using the link verification step below** before including them. See link rules and link verification sections below. List only if verified useful links exist.
- [Link title](verified url) — one-line description of what it is

---

## Step 3B: Research mode

### 1. Extract and verify links

Collect candidate links from BOTH the description and transcript (see link rules below). Also scan the transcript for any resource discussed — projects, repos, libraries, tools, research papers, blog posts, websites, datasets. Construct candidate URLs, then **run the link verification step** (see below) to confirm/correct all URLs before proceeding.

### 2. Visit all verified links

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
- [Link title](verified url) — one-line description

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

## Link verification (MANDATORY — apply to BOTH modes)

**Why this step exists:** YouTube auto-captions mangle URLs — punctuation is stripped, words are split or merged, plurals change (e.g., "skills.sh" becomes "skill sh", "shellgame.co" becomes "shell game"). Constructing URLs from transcript text alone produces broken links. Every link MUST be verified before inclusion.

After extracting all candidate links from the description and transcript, spawn a **single subagent** (using the Agent tool) to verify and correct them in one batch. The subagent should:

1. **Receive** the full list of candidate links along with the context of how each was mentioned (e.g., "speaker said 'skill sh' — community skill directory with Snyk trust badges").
2. **For each candidate link:**
   - Use WebSearch to find the correct URL by searching for the project/resource name + key context from the transcript.
   - Use WebFetch to confirm the found URL resolves and matches the described resource (not a parked domain, 404, or unrelated site).
   - If the candidate URL is wrong, replace it with the verified correct one.
   - If no valid URL can be found after searching, drop the link entirely rather than including a broken one.
3. **Return** the verified link list with corrected URLs and brief descriptions.

**Subagent prompt template:**
```
Verify and correct these links extracted from a YouTube video transcript. For each link:
1. Search the web to find the correct URL (transcript captions often mangle domain names).
2. Fetch the URL to confirm it resolves and matches the description.
3. Return the corrected list. Drop any link that can't be verified.

Candidate links:
- [candidate URL or name] — context: [how it was mentioned in the video]
...
```

**Important:** Do NOT skip verification even if a URL "looks right." Parked domains, typosquatted names, and stale URLs are common. The subagent step is mandatory, not optional.
