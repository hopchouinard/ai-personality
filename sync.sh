#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------------------------------------------
# Configuration: adapter filenames and their target paths.
# Paths starting with / are absolute (global targets).
# All other paths resolve relative to --project-root.
# Edit these once per machine if your paths differ from the defaults.
# -------------------------------------------------------------------
ADAPTER_NAMES=(
    "claude-code.md"
    "gemini-cli.md"
    "gemini-cli.md"
    "codex.md"
    "codex.md"
    "copilot.md"
)

ADAPTER_TARGETS=(
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.gemini/GEMINI.md"
    "GEMINI.md"
    "$HOME/.codex/AGENTS.md"
    "AGENTS.md"
    ".github/copilot-instructions.md"
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

for i in "${!ADAPTER_NAMES[@]}"; do
    ADAPTER="${ADAPTER_NAMES[$i]}"
    ADAPTER_FILE="$SCRIPT_DIR/adapters/$ADAPTER"
    TARGET="${ADAPTER_TARGETS[$i]}"

    # Resolve relative paths against project root
    if [[ "$TARGET" != /* ]]; then
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
        # Replace everything between markers (inclusive of content, preserving markers)
        # Uses awk to read adapter content from file, avoiding variable escaping issues
        awk -v start="$MARKER_START" -v end="$MARKER_END" -v afile="$ADAPTER_FILE" '
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
        echo "  UPDATED (v$VERSION)"
        UPDATED=$((UPDATED + 1))
    fi
done

echo ""
echo "Summary: $UPDATED updated, $SKIPPED skipped, $ERRORS errors"
