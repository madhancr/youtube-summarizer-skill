---
name: youtube-summarizer
description: >
  Transcribe, summarize, and research YouTube videos. Read the full skill instructions
  before taking any action — they contain specific output formats, link extraction rules
  (including constructing URLs from verbal mentions in transcripts), and link filtering
  logic that cannot be guessed.
  Two modes:
  (1) Summarize: trigger on "sum URL", "summarize URL", "tldr URL", "what's this video
  about URL", any YouTube URL with a summary request, or a bare YouTube URL with no
  other instructions.
  (2) Research: trigger on "re URL", "research URL", or any YouTube URL with a
  research/deep-dive request.
  Do not activate for non-YouTube URLs or general summarization without a YouTube link.
---

# YouTube Video Summarizer & Researcher

## Step 1: Fetch the transcript (both modes)

Extract the YouTube URL from the user's message.

Use the `youtube-transcript:get_youtube_transcript` MCP tool if available. Otherwise, run the CLI script:
```
uv run "<SKILL_DIR>/scripts/get_transcript.py" "<YOUTUBE_URL>"
```

The output format:
```
TITLE: <video title>
CHANNEL: <name> | DURATION: <length> | PUBLISHED: <date> | VIEWS: <count> | CAPTIONS: <manual|auto-generated>
DESCRIPTION: <video description>
<transcript text>
```

Identify and skip sponsor/ad-read segments in the transcript — exclude them from topic extraction, claims, and key takeaways.

---

## Step 2: Determine mode

- **"sum"**, **"summarize"**, **"tldr"**, **"what's this video about"** → **Step 3A** (Summarize)
- **"re"**, **"research"** → **Step 3B** (Research)

---

## Step 3A: Summarize mode

Output the summary directly in the chat message. Use this format:

**<Video Title>**
`<channel> · <duration> · <published date> · <views> views`

**TL;DR**
2-3 sentence overview.

**Topics covered**
- **Topic heading**: Brief description (2-3 sentences per topic)

**Key takeaways**
- 3-5 bullet points of the most important insights

**Links**
Collect candidate links from BOTH the DESCRIPTION and transcript. Scan the transcript for any resource the speaker discusses — projects, repos, libraries, tools, research papers, blog posts, websites, datasets. Speakers often mention these by name without spelling out a URL. Construct candidate URLs, then **verify all of them using the link verification step below** before including them. See link rules and link verification sections below. List only if verified useful links exist.
- [Link title](verified url) — one-line description of what it is

**Speakers**
- **Host/Channel:** [Name](profile or website URL) — one-line: role, affiliation, relevant expertise
- **Guest(s):** [Name](profile or website URL) — role, affiliation, relevant expertise
Include only if identifiable from the transcript or description. Skip guests line if no guest. Link to their most relevant public profile (personal site > X/Twitter > GitHub > LinkedIn > company page).

**Notable Claims**
Extract 3-5 specific, verifiable claims — concrete assertions that could be checked, not opinions or general statements. One line per claim:
- "The specific assertion" (~MM:SS) — type, confidence, [needs verification] · [[Entity1]], [[Entity2]]

Where type is factual/opinion/prediction/comparison, confidence is high/medium/low. Only add `needs verification` tag if yes.

Example: "MCP server count grew from 200 to 5,700 in 6 months" (~12:30) — factual, medium confidence, needs verification · [[MCP]]

If no notable claims exist (rare for technical content), write "No specific verifiable claims identified."

**Entities mentioned**
List the key projects, tools, models, frameworks, and people discussed. Use `[[wikilink]]` format for each:
- [[Entity Name]] — one-line description of what it is and its role in the video

**Staleness assessment**
End with a one-line staleness tag:
- `Staleness risk: HIGH` — version-specific content, benchmarks with specific numbers, "current state" discussions, pricing/availability claims (stale within weeks)
- `Staleness risk: MEDIUM` — framework tutorials, architecture discussions, comparisons (stale within months)
- `Staleness risk: LOW` — foundational concepts, design principles, historical context (stable for 6+ months)

**Transcript quality:** `clean | noisy | heavily mangled` — If noisy or mangled, list key terms that were likely garbled by auto-captions (e.g., "clothe code" → Claude Code, "bite coding" → vibe coding). This affects confidence in the entire summary.

---

## Step 3B: Research mode

Output the research report directly in the chat message — do NOT create a file or artifact. Use this format:

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
`<channel> · <duration> · <published date> · <views> views`

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

**Speakers**
- **Host/Channel:** [Name](profile or website URL) — role, affiliation, relevant expertise
- **Guest(s):** [Name](profile or website URL) — role, affiliation, relevant expertise
Include only if identifiable. Skip guests line if no guest. Link to their most relevant public profile (personal site > X/Twitter > GitHub > LinkedIn > company page).

**Notable Claims**
Same compact format as summarize mode, but add cross-references when a linked resource supports or contradicts the claim:
- "The specific assertion" (~MM:SS) — type, confidence, [needs verification] · [[Entity1]] · Cross-ref: [source agrees/disagrees]

**Entities mentioned**
Comprehensive list of every notable project, tool, model, framework, person, and organization discussed:
- [[Entity Name]] — description, role in the video, verified URL if available

**Staleness assessment**
- `Staleness risk: HIGH | MEDIUM | LOW` — with brief rationale

**Transcript quality:** `clean | noisy | heavily mangled` — with mangled terms if applicable.

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

## Link verification

**Why this step exists:** YouTube auto-captions mangle URLs — punctuation is stripped, words are split or merged, plurals change (e.g., "skills.sh" becomes "skill sh", "shellgame.co" becomes "shell game"). Constructing URLs from transcript text alone produces broken links.

### Choosing a verification strategy

Pick the strategy based on mode and link count:

| Condition | Strategy |
|-----------|----------|
| **Summarize mode, ≤5 candidate links** | **Inline** — verify yourself, no subagent |
| **Summarize mode, >5 candidate links** | **Subagent** — spawn one subagent |
| **Research mode** (any count) | **Subagent** — spawn one subagent |

### Inline verification (fast path)

For each candidate link, use **WebFetch** to confirm it resolves (HTTP 200) and matches the described resource. If it 404s or redirects to an unrelated page, drop it. Do NOT use WebSearch — just fetch the URL directly. Description links are usually correct; only transcript-derived URLs need extra care.

If a transcript-derived URL fails, try one obvious correction (e.g., fix pluralization, add/remove hyphens) and fetch again. If that also fails, drop it.

### Subagent verification

Spawn a **single subagent** (using the Agent tool) with the candidate list. The subagent should:

1. **Receive** the full list of candidate links with context (e.g., "speaker mentioned 'skill sh' — community skill directory").
2. **For each link:** Use **WebFetch** to confirm it resolves and matches the description. If it fails, try one corrected URL variant. Use **WebSearch** only as a last resort for transcript-derived links that can't be resolved by fetching alone.
3. **Return** the verified list with corrected URLs. Drop anything that can't be verified.

**Subagent prompt template:**
```
Verify these links from a YouTube video. For each link:
1. Fetch the URL to confirm it resolves (HTTP 200) and matches the description.
2. If it fails, try one obvious URL correction. Only use WebSearch as a last resort.
3. Return the corrected list. Drop any link that can't be verified.

Candidate links:
- [candidate URL or name] — context: [how it was mentioned]
...
```
