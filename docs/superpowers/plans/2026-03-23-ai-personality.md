# AI Personality System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a portable personality spec with adapters and sync scripts that distribute it to all AI tool config files.

**Architecture:** A canonical `personality.md` file is the single source of truth. Per-tool adapters derive from it. Two sync scripts (Bash + PowerShell) inject adapter content between HTML comment markers in target config files.

**Tech Stack:** Markdown, Bash, PowerShell. No external dependencies.

**Spec:** `docs/superpowers/specs/2026-03-23-ai-personality-design.md`

---

### Task 1: Repository scaffolding

**Files:**
- Create: `.gitignore`
- Create: `adapters/` (directory)

- [ ] **Step 1: Create .gitignore**

```
# OS
.DS_Store
Thumbs.db
Desktop.ini

# Editors
*.swp
*.swo
*~
.idea/
.vscode/
*.sublime-workspace
*.sublime-project
```

- [ ] **Step 2: Create adapters directory**

```bash
mkdir -p adapters
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore adapters/.gitkeep
git commit -m "chore: scaffold repo with .gitignore and adapters directory"
```

Note: Create an empty `.gitkeep` in `adapters/` so git tracks the directory. This file gets removed once real adapters are added.

---

### Task 2: Canonical personality prompt

**Files:**
- Create: `personality.md`

- [ ] **Step 1: Write personality.md**

The file must begin with YAML frontmatter, then contain the exact Personality & Tone, Response Format, and Anti-Patterns sections from the design spec. Reference the spec at `docs/superpowers/specs/2026-03-23-ai-personality-design.md` lines 35-71 for the exact content.

```markdown
---
version: 1.0
last-updated: 2026-03-23
---

## Personality & Tone

- Cheeky, unapologetically sassy, and delightfully sarcastic. Never boring, sterile, or corporate-FAQ-sounding. This is a performance requirement, not a nice-to-have.
- Give honest opinions even when they're not what the user wants to hear. Honesty over compliance, always. Non-negotiable.
- Don't sugarcoat bad ideas. Call them out, but with flair.
- Ask clarifying questions before diving into complex answers. This is a collaboration, not a service desk.
- Be opinionated. The user values perspective over passivity.
- Dry wit and cynical humor are welcome as seasoning, not the main course. Think "well-placed sarcasm," not "knock-knock jokes."

## Response Format

- **Scale verbosity to complexity.** Simple question = tight answer. Complex problem = structured deep-dive. No manual toggle needed; read the room.
- **Structure is context-dependent.** Technical and instructional answers get headers and bullets for scannability. Conversational and opinion answers stay as natural prose. The personality should never sound trapped inside rigid formatting.
- **Lead with the answer, not the reasoning.** Get to the point. Expand if the topic warrants it.

## Anti-Patterns (Never Do These)

1. **Patronizing openers** - "Great question!" and anything in that family.
2. **Restating the question back** - "So what you're asking is..." when it's obvious what was asked.
3. **Hedging qualifiers** - "It's worth noting that..." / "It should be mentioned that..." / "To be fair..."
4. **Filler affirmations** - "Absolutely!" / "Of course!" / "Sure thing!" before actually answering.
5. **Apologetic preambles** - "I apologize for any confusion" when there was no confusion.
6. **Summary repetition** - Restating everything at the end as a "recap."
7. **Service-desk sign-offs** - "Let me know if you need anything else!" and variants.
8. **Em dash overuse** - Prefer commas, semicolons, colons, periods, or parentheses. Em dashes have become an AI fingerprint; find another way.
9. **Unsolicited emoji** - Only use emoji if the user explicitly requests it.
```

- [ ] **Step 2: Verify frontmatter parses correctly**

```bash
head -3 personality.md
```

Expected output:
```
---
version: 1.0
last-updated: 2026-03-23
```

- [ ] **Step 3: Commit**

```bash
git add personality.md
git commit -m "feat: add canonical personality prompt v1.0"
```

---

### Task 3: Adapters

**Files:**
- Create: `adapters/claude-code.md`
- Create: `adapters/gemini-cli.md`
- Create: `adapters/codex.md`
- Create: `adapters/copilot.md`
- Create: `adapters/web-paste.md`
- Remove: `adapters/.gitkeep`

All five adapters start as the exact content of `personality.md` (the body after frontmatter, not the frontmatter itself). No constrained overrides are needed for v1.0 since none of the current platforms have known character limits that would require compression.

- [ ] **Step 1: Extract body from personality.md**

The frontmatter is exactly 4 lines (`---`, `version: ...`, `last-updated: ...`, `---`). Extract everything after line 4:

```bash
tail -n +5 personality.md > adapters/claude-code.md
```

- [ ] **Step 2: Create remaining adapters**

All adapters are identical for v1.0. Copy from the first:

```bash
cp adapters/claude-code.md adapters/gemini-cli.md
cp adapters/claude-code.md adapters/codex.md
cp adapters/claude-code.md adapters/copilot.md
cp adapters/claude-code.md adapters/web-paste.md
```

- [ ] **Step 3: Remove .gitkeep**

```bash
rm adapters/.gitkeep
```

- [ ] **Step 4: Verify all adapters exist and have identical content**

```bash
ls -la adapters/
# Should show: claude-code.md, codex.md, copilot.md, gemini-cli.md, web-paste.md

# Verify all files are identical
md5sum adapters/*.md
# All checksums should match (or use md5 on macOS)
md5 adapters/*.md
```

- [ ] **Step 5: Commit**

```bash
git add adapters/
git commit -m "feat: add adapters for all target platforms"
```

---

### Task 4: Bash sync script

**Files:**
- Create: `sync.sh`

- [ ] **Step 1: Write sync.sh**

The script must:

1. Parse the `version:` line from `personality.md` frontmatter
2. Define a config map of adapter names to target file paths (with comments showing defaults)
3. Accept an optional `--project-root <path>` argument (defaults to current working directory)
4. Accept a `--dry-run` flag
5. For each Tier 1 adapter:
   - Resolve the target path (absolute for global targets like claude-code, relative to project root for others)
   - Check if the target file exists (skip with warning if not)
   - Check if markers `<!-- AI-PERSONALITY-START -->` and `<!-- AI-PERSONALITY-END -->` exist in the target (skip with warning if not)
   - Replace everything between markers with the adapter file content
   - In dry-run mode: print what would change instead of writing
6. Print a summary: updated count, skipped count, errors

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------------------------------------------
# Configuration: map adapter filenames to target paths.
# Paths starting with ~ or / are absolute (global targets).
# All other paths resolve relative to --project-root.
# Edit these once per machine if your paths differ from the defaults.
# -------------------------------------------------------------------
declare -A TARGETS=(
    ["claude-code.md"]="$HOME/.claude/CLAUDE.md"
    ["gemini-cli.md"]="GEMINI.md"
    ["codex.md"]="AGENTS.md"
    ["copilot.md"]=".github/copilot-instructions.md"
)

MARKER_START="<!-- AI-PERSONALITY-START -->"
MARKER_END="<!-- AI-PERSONALITY-END -->"

# Defaults
DRY_RUN=false
PROJECT_ROOT="$(pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --project-root)
            PROJECT_ROOT="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: sync.sh [--dry-run] [--project-root <path>]" >&2
            exit 1
            ;;
    esac
done

# Read version from personality.md frontmatter
PERSONALITY_FILE="$SCRIPT_DIR/personality.md"
if [[ ! -f "$PERSONALITY_FILE" ]]; then
    echo "ERROR: personality.md not found at $PERSONALITY_FILE" >&2
    exit 1
fi

VERSION=$(grep -m1 '^version:' "$PERSONALITY_FILE" | sed 's/version:[[:space:]]*//')
if [[ -z "$VERSION" ]]; then
    echo "ERROR: Could not parse version from personality.md" >&2
    exit 1
fi

echo "AI Personality Sync v$VERSION"
echo "Project root: $PROJECT_ROOT"
if $DRY_RUN; then
    echo "Mode: DRY RUN (no files will be modified)"
fi
echo ""

UPDATED=0
SKIPPED=0
ERRORS=0

for ADAPTER in "${!TARGETS[@]}"; do
    ADAPTER_FILE="$SCRIPT_DIR/adapters/$ADAPTER"
    TARGET="${TARGETS[$ADAPTER]}"

    # Resolve relative paths against project root
    if [[ "$TARGET" != /* ]] && [[ "$TARGET" != ~* ]]; then
        TARGET="$PROJECT_ROOT/$TARGET"
    fi

    echo "--- $ADAPTER -> $TARGET"

    # Check adapter file exists
    if [[ ! -f "$ADAPTER_FILE" ]]; then
        echo "  SKIP: Adapter file not found: $ADAPTER_FILE"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Check target file exists
    if [[ ! -f "$TARGET" ]]; then
        echo "  SKIP: Target file not found: $TARGET"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Check markers exist in target
    if ! grep -q "$MARKER_START" "$TARGET" || ! grep -q "$MARKER_END" "$TARGET"; then
        echo "  SKIP: Markers not found in target file"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if $DRY_RUN; then
        echo "  WOULD UPDATE (v$VERSION)"
        UPDATED=$((UPDATED + 1))
    else
        # Replace everything between markers using sed + cat
        # Avoids awk -v issues with multi-line content and backslashes
        {
            sed -n "1,/$MARKER_START/p" "$TARGET"
            cat "$ADAPTER_FILE"
            sed -n "/$MARKER_END/,\$p" "$TARGET"
        } > "${TARGET}.tmp"
        mv "${TARGET}.tmp" "$TARGET"
        echo "  UPDATED (v$VERSION)"
        UPDATED=$((UPDATED + 1))
    fi
done

echo ""
echo "Summary: $UPDATED updated, $SKIPPED skipped, $ERRORS errors"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x sync.sh
```

- [ ] **Step 3: Verify script runs without errors (dry-run, no targets yet)**

```bash
./sync.sh --dry-run
```

Expected: prints version, skips all targets (none have markers yet), shows summary.

- [ ] **Step 4: Commit**

```bash
git add sync.sh
git commit -m "feat: add bash sync script with dry-run and project-root support"
```

---

### Task 5: PowerShell sync script

**Files:**
- Create: `sync.ps1`

- [ ] **Step 1: Write sync.ps1**

Mirror the exact logic from `sync.sh` in PowerShell syntax. The script must:

1. Parse `version:` from `personality.md` frontmatter
2. Define the same target mapping as sync.sh
3. Accept `-ProjectRoot <path>` parameter (defaults to current directory)
4. Support `-WhatIf` (PowerShell's native dry-run via `[CmdletBinding(SupportsShouldProcess)]`)
5. Same safety rules: skip missing files, skip missing markers, print summary

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# -------------------------------------------------------------------
# Configuration: map adapter filenames to target paths.
# Paths starting with a drive letter or ~ are absolute (global targets).
# All other paths resolve relative to -ProjectRoot.
# Edit these once per machine if your paths differ from the defaults.
# -------------------------------------------------------------------
$Targets = @{
    "claude-code.md" = Join-Path $HOME ".claude" "CLAUDE.md"
    "gemini-cli.md"  = "GEMINI.md"
    "codex.md"       = "AGENTS.md"
    "copilot.md"     = Join-Path ".github" "copilot-instructions.md"
}

$MarkerStart = "<!-- AI-PERSONALITY-START -->"
$MarkerEnd   = "<!-- AI-PERSONALITY-END -->"

# Read version from personality.md
$PersonalityFile = Join-Path $ScriptDir "personality.md"
if (-not (Test-Path $PersonalityFile)) {
    Write-Error "personality.md not found at $PersonalityFile"
    exit 1
}

$VersionLine = Get-Content $PersonalityFile | Where-Object { $_ -match "^version:" } | Select-Object -First 1
if ($VersionLine -match "^version:\s*(.+)$") {
    $Version = $Matches[1].Trim()
} else {
    Write-Error "Could not parse version from personality.md"
    exit 1
}

Write-Host "AI Personality Sync v$Version"
Write-Host "Project root: $ProjectRoot"
if ($WhatIfPreference) {
    Write-Host "Mode: DRY RUN (no files will be modified)"
}
Write-Host ""

$Updated = 0
$Skipped = 0
$Errors  = 0

foreach ($Adapter in $Targets.Keys) {
    $AdapterFile = Join-Path $ScriptDir "adapters" $Adapter
    $Target = $Targets[$Adapter]

    # Resolve relative paths against project root
    if (-not [System.IO.Path]::IsPathRooted($Target)) {
        $Target = Join-Path $ProjectRoot $Target
    }

    Write-Host "--- $Adapter -> $Target"

    # Check adapter file exists
    if (-not (Test-Path $AdapterFile)) {
        Write-Host "  SKIP: Adapter file not found: $AdapterFile"
        $Skipped++
        continue
    }

    # Check target file exists
    if (-not (Test-Path $Target)) {
        Write-Host "  SKIP: Target file not found: $Target"
        $Skipped++
        continue
    }

    # Read target content
    $TargetContent = Get-Content $Target -Raw

    # Check markers exist
    if ($TargetContent -notmatch [regex]::Escape($MarkerStart) -or
        $TargetContent -notmatch [regex]::Escape($MarkerEnd)) {
        Write-Host "  SKIP: Markers not found in target file"
        $Skipped++
        continue
    }

    # Read adapter content
    $AdapterContent = Get-Content $AdapterFile -Raw

    if ($PSCmdlet.ShouldProcess($Target, "Update personality content (v$Version)")) {
        # Replace everything between markers (inclusive)
        # Use (?s) so .* spans newlines; match evaluator avoids $ interpretation issues
        $Pattern = "(?s)" + [regex]::Escape($MarkerStart) + ".*?" + [regex]::Escape($MarkerEnd)
        $NewBlock = $MarkerStart + "`n" + $AdapterContent + "`n" + $MarkerEnd
        $NewContent = [regex]::Replace($TargetContent, $Pattern, { $NewBlock })
        Set-Content -Path $Target -Value $NewContent -NoNewline
        Write-Host "  UPDATED (v$Version)"
        $Updated++
    }
}

Write-Host ""
Write-Host "Summary: $Updated updated, $Skipped skipped, $Errors errors"
```

- [ ] **Step 2: Verify script parses without errors**

If on a machine with PowerShell available:
```bash
pwsh -Command "Get-Help ./sync.ps1"
```

If PowerShell is not available, verify the file was written correctly by checking the first and last lines.

- [ ] **Step 3: Commit**

```bash
git add sync.ps1
git commit -m "feat: add PowerShell sync script for Windows support"
```

---

### Task 6: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

The README should cover:

1. What this repo is (one paragraph)
2. Quick start: how to run `sync.sh` or `sync.ps1`
3. How to add markers to a target config file
4. How to add a new platform adapter
5. How to update the personality and re-sync
6. The target platform table from the spec
7. Note about Tier 2 (web paste) being manual

Keep it concise and practical. No badges, no contributing guide, no license section. This is a personal tool.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with usage instructions"
```

---

### Task 7: Add markers to existing CLAUDE.md and verify sync

**Files:**
- Modify: `~/.claude/CLAUDE.md`

This task verifies the full pipeline works end-to-end by adding markers to the existing global CLAUDE.md and running sync.

- [ ] **Step 1: Examine current CLAUDE.md**

Read `~/.claude/CLAUDE.md` and identify the existing "Personality & Communication Style" section (lines 8-16 based on current content).

- [ ] **Step 2: Replace the manual personality section with markers**

Replace the existing `## Personality & Communication Style` section and its content with:

```markdown
<!-- AI-PERSONALITY-START -->
<!-- AI-PERSONALITY-END -->
```

Keep the `## Shell Command Style` section and any other non-personality content intact.

- [ ] **Step 3: Run sync in dry-run mode**

```bash
cd /Volumes/NVMe_2TB_Work/Development/ai-personality
./sync.sh --dry-run
```

Expected: shows "WOULD UPDATE" for claude-code.md target, skips all per-project targets (no project root with markers).

- [ ] **Step 4: Run sync for real**

```bash
./sync.sh
```

Expected: shows "UPDATED (v1.0)" for claude-code.md, skips per-project targets.

- [ ] **Step 5: Verify CLAUDE.md content**

Read `~/.claude/CLAUDE.md` and verify:
- Shell Command Style section is untouched
- Personality content is between the markers
- Content matches `adapters/claude-code.md`

- [ ] **Step 6: Archive SPEC.md**

Add an archival notice at the top of `SPEC.md`, before the existing `# AI Personality Spec` heading:

```markdown
> **ARCHIVED:** This document is the original brainstorming log. It has been superseded by the design spec at `docs/superpowers/specs/2026-03-23-ai-personality-design.md`. All decisions from this document are captured there.
```

- [ ] **Step 7: Commit SPEC.md and docs**

```bash
git add SPEC.md docs/
git commit -m "chore: archive SPEC.md, add design spec and implementation plan"
```
