> **ARCHIVED:** This document is the original brainstorming log. It has been superseded by the design spec at `docs/superpowers/specs/2026-03-23-ai-personality-design.md`. All decisions from this document are captured there.

# AI Personality Spec

> A portable, single-source-of-truth personality and response format specification
> for AI assistants — designed to be distributed across any tool that accepts
> system-level instructions.

## Status: Brainstorming In Progress

**Last updated:** 2026-03-23
**Session origin:** Claude Code session in `/Volumes/NVMe_2TB_Work/Development`

This spec is a living document from an ongoing brainstorming session. The next
session should pick up from the [Next Steps](#next-steps) section below. Everything
above that section represents decisions already made. Everything in Next Steps
represents open questions that must be resolved before implementation begins.

---

## Problem

Every AI tool has its own mechanism for personality/instruction configuration.
Adding a new tool means another manual copy-paste. Updating the spec means
updating N places. This doesn't scale — and new tools are being added frequently.

## Scope

This spec covers **two concerns only**:

1. **Personality & Tone** — How the AI communicates
2. **Response Format** — Structural preferences for how answers are delivered

### Explicitly Out of Scope

- Coding conventions (belongs in `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, etc.)
- Project-specific context (belongs in project config files)
- Tool-specific commands or workflows (belongs in per-tool config)

The boundary is intentional: this repo owns the *human interaction layer* only.
Technical configuration stays in each tool's native config. No overlap, no conflict.

---

## Decisions Made

### Personality Spec (Agreed)

#### Tone

- Cheeky, unapologetically sassy, and delightfully sarcastic
- Expressive and direct — cynicism is welcome when warranted
- Never boring, sterile, or corporate-FAQ-sounding
- This is a performance requirement, not a nice-to-have

#### Honesty

- Give honest opinions even when they're not what the user wants to hear
- Honesty over compliance, always — this is non-negotiable
- Don't sugarcoat bad ideas — call them out, but with flair

#### Collaboration Style

- Ask clarifying questions before diving into complex answers
- This is a collaboration — treat it like one, not a service desk
- Be opinionated; the user values perspective over passivity

### Target Platforms (Inventoried)

| Platform | Config Mechanism | Automatable? | Status |
|----------|-----------------|-------------|--------|
| Claude Code | `~/.claude/CLAUDE.md` | Yes (file) | ✅ Deployed |
| Claude AI (web/desktop) | Project instructions / system prompt | No (manual paste) | ✅ Deployed |
| Claude Co-work | Custom instructions | No (manual paste) | ✅ Deployed |
| Gemini CLI | `GEMINI.md` | Yes (file) | ✅ Deployed |
| Gemini (web) | Custom instructions | No (manual paste) | Needs confirmation |
| ChatGPT | Custom instructions / memory | No (manual paste) | ✅ Deployed |
| OpenAI Codex | `AGENTS.md` | Yes (file) | Needs setup |
| GitHub Copilot CLI | `.github/copilot-instructions.md` | Yes (file) | Needs setup |

### Distribution Strategy (Agreed)

#### Tier 1: File-Based (automatable)

Tools that read from local config files. A sync script can write the personality
section into each tool's config file format automatically.

**Targets:** Claude Code, Gemini CLI, OpenAI Codex, GitHub Copilot CLI

#### Tier 2: Web UI (manual paste)

Tools that only accept instructions via a web interface. The canonical spec
is the paste source — at least it's versioned and consistent.

**Targets:** Claude AI, Claude Co-work, ChatGPT, Gemini web

### Architecture (Proposed, Pending Validation)

```
ai-personality/
├── SPEC.md                  # This file — high-level spec & decisions
├── personality.md           # The canonical personality prompt (paste-ready)
├── adapters/                # Per-tool format adapters
│   ├── claude-code.md       # Formatted for CLAUDE.md injection
│   ├── gemini-cli.md        # Formatted for GEMINI.md injection
│   ├── codex.md             # Formatted for AGENTS.md injection
│   ├── copilot.md           # Formatted for copilot-instructions.md
│   └── web-paste.md         # Generic version for manual paste into web UIs
├── sync.sh                  # Distributes personality to Tier 1 targets
└── README.md                # Usage instructions
```

---

## Next Steps

> **START HERE in the next session.** The following questions are blocking
> implementation. Each one needs a decision before we can write the canonical
> `personality.md` or the sync tooling.

### 1. Define Response Format Rules

The personality/tone spec is solid, but the **response format** half is undefined.
Questions to work through:

- Do you have preferences on verbosity? (e.g., "default to concise, expand when asked")
- Structure preferences? (e.g., "use headers and bullets for complex answers, not walls of text")
- Code example style? (e.g., "always show before/after", "keep examples minimal")
- Any anti-patterns? (e.g., "never start with 'Great question!'", "don't repeat my question back to me")

This is the second pillar of the spec and needs to be fleshed out before the
canonical prompt can be written.

### 2. Decide on Sync Strategy

The sync script needs to inject personality into files that already contain
other content (e.g., `CLAUDE.md` has shell command rules). Two approaches:

- **Option A: Delimited section** — Use markers like `<!-- AI-PERSONALITY-START -->`
  and `<!-- AI-PERSONALITY-END -->`. The sync script replaces everything between
  markers. Re-runnable, idempotent. **Recommended.**
- **Option B: Append-only** — Just append to the end of the file. Simpler but
  creates duplicates on re-run and can't update in place.

Need a decision here. Option A is strongly recommended.

### 3. Decide on Versioning

Should the personality prompt include a version number (e.g., `v1.2`) so you
can audit which version is deployed to which platform? This would help answer
"is my ChatGPT custom instruction current?" at a glance.

- If yes: version lives in the canonical `personality.md` and each adapter inherits it.
- If no: rely on git history alone.

### 4. Decide on Per-Tool Overrides

Some tools may interpret the same wording differently, or have length limits.
Should adapters allow tool-specific tweaks on top of the canonical prompt?

- If yes: adapters = canonical base + optional tool-specific additions/modifications.
- If no: one-size-fits-all, every adapter is just a format wrapper around the
  same canonical text.

### 5. Validate the Architecture

The proposed directory structure above needs a gut-check. Does it feel right?
Too complex? Missing anything? This should be confirmed before creating files.

---

## Context for the Next Session

- The owner adds new AI tools frequently — the deployment surface is growing,
  which is the primary driver for this project.
- The personality spec has been manually deployed to most platforms already via
  copy-paste. This project is about eliminating that manual process.
- The personality spec is intentionally separated from coding/project config.
  It owns the human interaction layer only.
- The owner has strong opinions and values direct, honest collaboration.
  (Meta: this spec is itself an example of the personality it describes.)
