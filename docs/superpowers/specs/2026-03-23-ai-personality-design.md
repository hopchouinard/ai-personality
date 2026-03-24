# AI Personality System Design

**Date:** 2026-03-23
**Status:** Approved
**Version:** 1.0

---

## Problem

Every AI tool has its own mechanism for personality/instruction configuration. Adding a new tool means another manual copy-paste. Updating the spec means updating N places. This doesn't scale, and new tools are being added frequently.

## Scope

This system covers **two concerns only**:

1. **Personality & Tone** - How the AI communicates
2. **Response Format** - Structural preferences for how answers are delivered

### Explicitly Out of Scope

- Coding conventions (belongs in project-specific config like `CLAUDE.md`, `AGENTS.md`, `.cursorrules`)
- Project-specific context (belongs in project config files)
- Tool-specific commands or workflows (belongs in per-tool config)
- Code example style or formatting (belongs in per-project coding standards; originally considered as part of response format but intentionally moved out of scope since it varies by project, language, and tool)

The boundary is intentional: this repo owns the *human interaction layer* only.

---

## Canonical Personality Prompt

The file `personality.md` is the single source of truth. Every adapter derives from it. It uses YAML frontmatter for metadata:

```yaml
---
version: 1.0
last-updated: 2026-03-23
---
```

The version uses two-part numbering (`MAJOR.MINOR`). Bump MAJOR for personality overhauls, MINOR for tweaks and additions. The sync scripts parse the `version:` line from frontmatter.

The Personality & Tone, Response Format, and Anti-Patterns sections below are the exact content of `personality.md` (after the frontmatter header). Adapters start with this text verbatim and apply constrained overrides only if needed.

### Personality & Tone

- Cheeky, unapologetically sassy, and delightfully sarcastic. Never boring, sterile, or corporate-FAQ-sounding. This is a performance requirement, not a nice-to-have.
- Give honest opinions even when they're not what the user wants to hear. Honesty over compliance, always. Non-negotiable.
- Don't sugarcoat bad ideas. Call them out, but with flair.
- Ask clarifying questions before diving into complex answers. This is a collaboration, not a service desk.
- Be opinionated. The user values perspective over passivity.
- Dry wit and cynical humor are welcome as seasoning, not the main course. Think "well-placed sarcasm," not "knock-knock jokes."

### Response Format

- **Scale verbosity to complexity.** Simple question = tight answer. Complex problem = structured deep-dive. No manual toggle needed; read the room.
- **Structure is context-dependent.** Technical and instructional answers get headers and bullets for scannability. Conversational and opinion answers stay as natural prose. The personality should never sound trapped inside rigid formatting.
- **Lead with the answer, not the reasoning.** Get to the point. Expand if the topic warrants it.

### Anti-Patterns (Never Do These)

1. **Patronizing openers** - "Great question!" and anything in that family.
2. **Restating the question back** - "So what you're asking is..." when it's obvious what was asked.
3. **Hedging qualifiers** - "It's worth noting that..." / "It should be mentioned that..." / "To be fair..."
4. **Filler affirmations** - "Absolutely!" / "Of course!" / "Sure thing!" before actually answering.
5. **Apologetic preambles** - "I apologize for any confusion" when there was no confusion.
6. **Summary repetition** - Restating everything at the end as a "recap."
7. **Service-desk sign-offs** - "Let me know if you need anything else!" and variants.
8. **Em dash overuse** - Prefer commas, semicolons, colons, periods, or parentheses. Em dashes have become an AI fingerprint; find another way.
9. **Unsolicited emoji** - Only use emoji if the user explicitly requests it.

---

## Adapter System

### What Adapters Are

Each adapter is a standalone markdown file in `adapters/` that contains the full personality prompt, formatted for its target platform. Adapters start as the canonical text from `personality.md`.

### Constrained Override Rules

Adapters may apply constrained modifications to fit platform requirements:

- **Allowed:** Compression or omission of sections (e.g., for character limits)
- **Forbidden:** Adding personality traits not in the canonical source
- **Forbidden:** Contradicting the canonical source
- **Required:** If an adapter differs from canonical, it must include an HTML comment at the top noting what was changed and why, e.g., `<!-- OVERRIDE: Anti-patterns section omitted to fit 1500-char limit -->`

### Initial Adapter Set

| Adapter | Target | Tier | Notes |
|---------|--------|------|-------|
| `claude-code.md` | `~/.claude/CLAUDE.md` | 1 (file) | Global (absolute path) |
| `gemini-cli.md` | `GEMINI.md` | 1 (file) | Per-project (relative to project root) |
| `codex.md` | `AGENTS.md` | 1 (file) | Per-project (relative to project root) |
| `copilot.md` | `.github/copilot-instructions.md` | 1 (file) | Per-project (relative to project root) |
| `web-paste.md` | Manual paste | 2 (web) | Claude AI, Claude Co-work, ChatGPT, Gemini web |

**Path resolution:** Claude Code's target (`~/.claude/CLAUDE.md`) is a global file at a fixed absolute path. All other Tier 1 targets are per-project files. The sync script accepts an optional project root argument (defaults to the current working directory). Global targets are always synced; per-project targets resolve relative to the project root.

### Adding a New Adapter

1. Create a new file in `adapters/`
2. Start with the canonical `personality.md` content
3. Apply constrained modifications if needed (with comments explaining why)
4. For Tier 1: add the target path mapping to both sync scripts
5. For Tier 2: no script changes needed; the file is used for manual paste

---

## Sync System

### Marker Format

Target config files must contain these HTML comment markers where the personality content should be injected:

```markdown
<!-- AI-PERSONALITY-START -->
... personality content here ...
<!-- AI-PERSONALITY-END -->
```

### Scripts

Two scripts with identical logic, no external dependencies:

- **`sync.sh`** - Bash (macOS, Linux)
- **`sync.ps1`** - PowerShell (Windows)

### Script Behavior

1. Read the version number from `personality.md`
2. For each Tier 1 adapter, read the adapter file content
3. Locate the target config file on disk
4. Find the markers in the target file
5. Replace everything between the markers with the adapter content
6. Report what was updated (file path, version stamped)

### Configuration

Each script contains a config section at the top mapping adapter names to target file paths. Edit once per machine.

### Safety Rules

- If the target file doesn't exist: skip with a warning (never create files that aren't there)
- If markers aren't found in an existing target: warn and skip (never blindly append)
- Dry-run mode (`--dry-run` for bash, `-WhatIf` for PowerShell): show what would change without writing
- Exit with a summary: targets updated, targets skipped, any errors

### What Scripts Don't Do

- No git operations (no auto-commit, no auto-push)
- No network calls
- No dependency installation
- No Tier 2 handling (web paste is manual by design)

---

## Versioning

- The canonical `personality.md` carries a two-part version number (e.g., `1.0`) in YAML frontmatter
- Each adapter inherits the version from the canonical source
- Version is visible in the output so any platform can be spot-checked for staleness
- Version bumps happen manually when editing `personality.md`
- Git history provides the detailed changelog

---

## Repository Structure

```
ai-personality/
├── personality.md           # Canonical prompt (single source of truth)
├── adapters/
│   ├── claude-code.md       # For ~/.claude/CLAUDE.md
│   ├── gemini-cli.md        # For GEMINI.md
│   ├── codex.md             # For AGENTS.md
│   ├── copilot.md           # For .github/copilot-instructions.md
│   └── web-paste.md         # For manual paste into web UIs
├── sync.sh                  # Bash sync script (macOS/Linux)
├── sync.ps1                 # PowerShell sync script (Windows)
├── SPEC.md                  # Archived brainstorming log (superseded by this design spec)
├── README.md                # Usage: how to run sync, how to add adapters
└── .gitignore               # .DS_Store, editor files, OS cruft
```

### Intentionally Absent

- No CI/CD (nothing to build or test automatically)
- No Makefile or task runner (two scripts cover the only operation)
- No package.json or requirements.txt (no dependencies)
- No tests directory (scripts are simple enough to verify by running them)

---

## Workflow

### Updating the Personality

1. Edit `personality.md`
2. Bump the version number
3. If any adapter needs a constrained override update, edit it too
4. Run `sync.sh` (or `sync.ps1` on Windows)
5. For Tier 2 platforms, open `web-paste.md` and paste manually
6. Commit

### Adding a New Platform

1. Create a new adapter file in `adapters/`
2. If Tier 1: add the target path mapping to both sync scripts
3. Run sync
4. Commit
