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
    "adapters/claude-code.md|AI-PERSONALITY|$HOME/.claude/output-styles/house-voice.md"
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

# Per-block version lookup. Returns non-zero when the version cannot be read,
# so callers can react; it never lets `set -e` kill the run from inside a
# command substitution. (A bare `VAR=$(grep ... | sed ...)` does exactly that:
# under `pipefail` a non-matching grep makes the whole pipeline non-zero, the
# assignment trips `set -e`, and the script dies before reaching any guard.)
version_for_block() {
    local file pattern strip line
    case "$1" in
        AI-PERSONALITY)
            file="$SCRIPT_DIR/personality.md"
            pattern='^version:'
            strip='s/version:[[:space:]]*//'
            ;;
        CLARA-IDENTITY)
            file="$SCRIPT_DIR/clara/manifest.yaml"
            pattern='^artifact_version:'
            strip='s/artifact_version:[[:space:]]*//; s/"//g'
            ;;
        *)
            echo "unknown"
            return 0
            ;;
    esac

    [[ -r "$file" ]] || return 1
    line=$(grep -m1 "$pattern" "$file") || return 1
    line=$(printf '%s\n' "$line" | sed "$strip")
    [[ -n "$line" ]] || return 1
    printf '%s\n' "$line"
}

if [[ ! -f "$SCRIPT_DIR/personality.md" ]]; then
    echo "ERROR: personality.md not found at $SCRIPT_DIR/personality.md" >&2
    exit 1
fi

if ! PERSONALITY_VERSION=$(version_for_block AI-PERSONALITY); then
    echo "ERROR: Could not parse version from $SCRIPT_DIR/personality.md" >&2
    echo "       Expected a line starting with 'version:'." >&2
    exit 1
fi

echo "AI Personality Sync v$PERSONALITY_VERSION"
echo "Project root: $PROJECT_ROOT"
if $DRY_RUN; then
    echo "Mode: DRY RUN (no files will be modified)"
fi
echo ""

# What the stamp records: the tag or commit this block was synced from.
REVISION=$(git -C "$SCRIPT_DIR" describe --tags --always --dirty 2>/dev/null) || REVISION=unknown

# Backups stay out of the targets' own trees, so a project-root target never
# leaves a stray copy for someone to commit. Each run gets its own directory,
# made on the first write: mktemp keeps two runs in the same second from sharing
# one (the second would overwrite the recovery copy) and creates it 0700, since
# a backup holds the whole target, private text outside the block included.
BACKUP_BASE="${AI_PERSONALITY_BACKUP_DIR:-$HOME/.local/state/ai-personality/backups}"
BACKUP_ROOT=""

make_backup_root() {
    [[ -n "$BACKUP_ROOT" ]] && return 0
    ( umask 077; mkdir -p "$BACKUP_BASE" ) || return 1
    BACKUP_ROOT=$(mktemp -d "$BACKUP_BASE/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX") || return 1
}

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

    # Whole-line (-x), fixed-string (-F) match: this is exactly what the awk
    # replacement below requires ($0 == start). A substring test would accept an
    # indented or trailing-comment marker that the awk then never matches,
    # reporting UPDATED while rewriting the file byte-identically. Skip loudly
    # instead of lying.
    if ! grep -qxF "$MARKER_START" "$TARGET" || ! grep -qxF "$MARKER_END" "$TARGET"; then
        echo "  SKIP: Markers not found in target file"
        echo "  Need both of the next two lines verbatim in $TARGET,"
        echo "  each alone on its own line with no leading or trailing whitespace:"
        echo "$MARKER_START"
        echo "$MARKER_END"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Version lookup happens AFTER the skip gates, deliberately. Resolved up
    # front, a bad lookup on a late entry aborted the run once the earlier
    # targets had already been rewritten - a half-synced $HOME with no summary
    # line and no error text. Here the worst case is one entry skipped loudly
    # while every other entry is still served, and the run reports it.
    if ! BLOCK_VERSION=$(version_for_block "$BLOCK"); then
        echo "  SKIP: cannot determine the $BLOCK version; refusing to stamp this block" >&2
        case "$BLOCK" in
            AI-PERSONALITY) echo "  Check the 'version:' line in $SCRIPT_DIR/personality.md" >&2 ;;
            CLARA-IDENTITY) echo "  Check the 'artifact_version:' line in $SCRIPT_DIR/clara/manifest.yaml" >&2 ;;
        esac
        ERRORS=$((ERRORS + 1))
        continue
    fi

    if $DRY_RUN; then
        echo "  WOULD UPDATE (v$BLOCK_VERSION)"
        UPDATED=$((UPDATED + 1))
    else
        # No backup, no write: an identity file is not worth risking to save a run.
        if ! make_backup_root \
            || ! TARGET_DIR=$(cd "$(dirname "$TARGET")" && pwd -P) \
            || ! BACKUP_FILE="$BACKUP_ROOT/${TARGET_DIR#/}/$(basename "$TARGET")" \
            || ! mkdir -p "$(dirname "$BACKUP_FILE")" \
            || ! cp -p "$TARGET" "$BACKUP_FILE"; then
            echo "  SKIP: could not back up $TARGET; left unchanged" >&2
            ERRORS=$((ERRORS + 1))
            continue
        fi

        # Replace everything between markers (preserving the markers)
        STAMP="<!-- ${BLOCK}-VERSION: ${BLOCK_VERSION} (${REVISION}) -->"
        awk -v start="$MARKER_START" -v end="$MARKER_END" -v afile="$SOURCE_FILE" -v stamp="$STAMP" '
            $0 == start {
                print
                print stamp
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

# The counter is load-bearing: a run that could not stamp a block completed the
# other entries, so the summary above is the full picture -- but the caller must
# still learn that something went wrong. A skip (target absent, markers absent,
# source unrendered) is normal and stays exit 0.
if [[ "$ERRORS" -gt 0 ]]; then
    exit 1
fi
