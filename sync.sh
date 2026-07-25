#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------------------------------------------
# Configuration: one entry per sync target.
#   Format: "<source path, repo-relative>|<BLOCK>|<target path>"
# Markers are derived from BLOCK: <!-- BLOCK-START --> / <!-- BLOCK-END -->
# Target paths starting with / are absolute (global targets); all others
# resolve relative to --project-root. Sources under build/ are rendered
# artifacts: run ./render-clara.sh first (missing source = graceful skip).
# Edit these once per machine if your paths differ from the defaults.
# -------------------------------------------------------------------
SYNC_ENTRIES=(
    "adapters/claude-code.md|AI-PERSONALITY|$HOME/.claude/CLAUDE.md"
    "adapters/gemini-cli.md|AI-PERSONALITY|$HOME/.gemini/GEMINI.md"
    "adapters/gemini-cli.md|AI-PERSONALITY|GEMINI.md"
    "adapters/codex.md|AI-PERSONALITY|$HOME/.codex/AGENTS.md"
    "adapters/codex.md|AI-PERSONALITY|AGENTS.md"
    "adapters/copilot.md|AI-PERSONALITY|$HOME/.copilot/copilot-instructions.md"
    "adapters/copilot.md|AI-PERSONALITY|.github/copilot-instructions.md"
    "build/clara-soul.md|CLARA-IDENTITY|$HOME/.hermes/SOUL.md"
)

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

# Per-block version lookup.
version_for_block() {
    case "$1" in
        AI-PERSONALITY)
            grep -m1 '^version:' "$SCRIPT_DIR/personality.md" | sed 's/version:[[:space:]]*//'
            ;;
        CLARA-IDENTITY)
            grep -m1 '^artifact_version:' "$SCRIPT_DIR/clara/manifest.yaml" | sed 's/artifact_version:[[:space:]]*//; s/"//g'
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

PERSONALITY_VERSION=$(version_for_block AI-PERSONALITY)
if [[ -z "$PERSONALITY_VERSION" ]]; then
    echo "ERROR: Could not parse version from personality.md" >&2
    exit 1
fi

echo "AI Personality Sync v$PERSONALITY_VERSION"
echo "Project root: $PROJECT_ROOT"
if $DRY_RUN; then
    echo "Mode: DRY RUN (no files will be modified)"
fi
echo ""

UPDATED=0
SKIPPED=0
ERRORS=0

for entry in "${SYNC_ENTRIES[@]}"; do
    SOURCE_REL="${entry%%|*}"
    rest="${entry#*|}"
    BLOCK="${rest%%|*}"
    TARGET="${rest#*|}"

    SOURCE_FILE="$SCRIPT_DIR/$SOURCE_REL"
    MARKER_START="<!-- ${BLOCK}-START -->"
    MARKER_END="<!-- ${BLOCK}-END -->"
    BLOCK_VERSION=$(version_for_block "$BLOCK")

    # Resolve relative target paths against project root
    if [[ "$TARGET" != /* ]]; then
        TARGET="$PROJECT_ROOT/$TARGET"
    fi

    echo "--- [$BLOCK] $SOURCE_REL -> $TARGET"

    if [[ ! -f "$SOURCE_FILE" ]]; then
        if [[ "$SOURCE_REL" == build/* ]]; then
            echo "  SKIP: Source not rendered: $SOURCE_REL (run ./render-clara.sh first)"
        else
            echo "  SKIP: Source file not found: $SOURCE_FILE"
        fi
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [[ ! -f "$TARGET" ]]; then
        echo "  SKIP: Target file not found: $TARGET"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if ! grep -q "$MARKER_START" "$TARGET" || ! grep -q "$MARKER_END" "$TARGET"; then
        echo "  SKIP: Markers not found in target file"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if $DRY_RUN; then
        echo "  WOULD UPDATE (v$BLOCK_VERSION)"
        UPDATED=$((UPDATED + 1))
    else
        # Replace everything between markers (preserving the markers)
        awk -v start="$MARKER_START" -v end="$MARKER_END" -v afile="$SOURCE_FILE" '
            $0 == start {
                print
                while ((getline line < afile) > 0) print line
                close(afile)
                skip = 1
                next
            }
            $0 == end {
                skip = 0
                print
                next
            }
            skip { next }
            { print }
        ' "$TARGET" > "${TARGET}.tmp"
        mv "${TARGET}.tmp" "$TARGET"
        echo "  UPDATED (v$BLOCK_VERSION)"
        UPDATED=$((UPDATED + 1))
    fi
done

echo ""
echo "Summary: $UPDATED updated, $SKIPPED skipped, $ERRORS errors"
