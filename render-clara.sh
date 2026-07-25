#!/usr/bin/env bash
# Render surface-ready Clara blocks from the identity components.
# Outputs (derived; gitignored): build/clara-soul.md, build/clara-web-paste.md
# Usage: ./render-clara.sh [--source DIR] [--out DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/clara"
OUT_DIR="$SCRIPT_DIR/build"
SOUL_CAP_BYTES=8192

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --out)
            OUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: render-clara.sh [--source DIR] [--out DIR]" >&2
            exit 1
            ;;
    esac
done

for f in manifest.yaml identity.md traits.yaml memory-contract.md; do
    if [[ ! -f "$SOURCE_DIR/$f" ]]; then
        echo "ERROR: missing component: $SOURCE_DIR/$f" >&2
        exit 1
    fi
done

VERSION=$(grep -m1 '^artifact_version:' "$SOURCE_DIR/manifest.yaml" | sed 's/artifact_version:[[:space:]]*//; s/"//g')
if [[ -z "$VERSION" ]]; then
    echo "ERROR: could not parse artifact_version from $SOURCE_DIR/manifest.yaml" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

# Strip YAML frontmatter (first --- ... --- block) from a markdown file.
strip_frontmatter() {
    awk '
        NR == 1 && /^---$/ { infm = 1; next }
        infm && /^---$/    { infm = 0; next }
        infm               { next }
                           { print }
    ' "$1"
}

STAMP="<!-- clara-identity v$VERSION | rendered; do not hand-edit -->"

# ---- build/clara-soul.md (Hermes SOUL.md payload) ----
SOUL="$OUT_DIR/clara-soul.md"
{
    echo "$STAMP"
    echo ""
    strip_frontmatter "$SOURCE_DIR/identity.md"
    echo ""
    echo "## Trait Dials (canonical baseline; lower-only modulation)"
    echo ""
    echo '```yaml'
    cat "$SOURCE_DIR/traits.yaml"
    echo '```'
    echo ""
    echo "## Memory"
    echo ""
    echo "Durable memory is machine-local, at ~/.clara/ on this machine. It is governed"
    echo "by the Clara memory contract (clara/memory-contract.md in the ai-personality"
    echo "repo, artifact v$VERSION). These rules are normative:"
    echo ""
    echo "- Read ~/.clara/MEMORY.md when personal context matters."
    echo "- Write new episodes into ~/.clara/episodes/, named exactly:"
    echo "  YYYY-MM-DD--<machine>--<slug>.md  (<machine> = contents of ~/.clara/MACHINE)."
    echo "  The machine ID in the filename is what makes cross-machine imports"
    echo "  collision-free. Do not invent a different naming scheme."
    echo "- Episodes are append-only: never rewrite one, never merge two."
    echo "- Episode frontmatter: date, surface, refs (required); privacy: PC3 (required);"
    echo "  origin (optional, evidence identifiers)."
    echo "- NEVER correct a memory store in place. If new evidence contradicts a stored"
    echo "  fact, record the contradiction as a new episode citing origin, and leave the"
    echo "  resolution to the curation pass. Two stores agreeing is not evidence."
    echo "- An infrastructure or operational fact does not belong in memory at all; it"
    echo "  belongs in the infrastructure authority, with at most one pointer line here."
    echo "- Identity NEVER changes by memory write, prompt patch, or surface edit - only"
    echo "  by a pull request to clara/ in this repo."
    echo "- MEMORY.md is edited ONLY by an explicit curation pass, and has a hard 8KB cap."
    echo "- preferences.yaml may be updated by automated writers."
    echo "- Never write raw Google-sourced content into memory: no email bodies, calendar"
    echo "  descriptions, document content, or verbatim quotes from them. Summaries and"
    echo "  stable identifiers (message ID, event ID, document title) only."
    echo "- Memory is best-effort context, never load-bearing. Behave correctly, if less"
    echo "  personally, when ~/.clara/ is absent or empty."
} > "$SOUL"

SOUL_SIZE=$(wc -c < "$SOUL" | tr -d ' ')
if [[ "$SOUL_SIZE" -gt "$SOUL_CAP_BYTES" ]]; then
    rm -f "$SOUL"
    echo "ERROR: clara-soul.md is ${SOUL_SIZE} bytes, over the ${SOUL_CAP_BYTES}-byte cap." >&2
    echo "Trim clara/identity.md or clara/traits.yaml; never raise the cap casually." >&2
    exit 1
fi

# ---- build/clara-web-paste.md (Clara-designated web projects) ----
PASTE="$OUT_DIR/clara-web-paste.md"
{
    echo "$STAMP"
    echo ""
    strip_frontmatter "$SOURCE_DIR/identity.md"
    echo ""
    echo "## Trait Dials (canonical baseline; lower-only modulation)"
    echo ""
    echo '```yaml'
    cat "$SOURCE_DIR/traits.yaml"
    echo '```'
} > "$PASTE"

echo "Rendered clara-identity v$VERSION:"
echo "  $SOUL (${SOUL_SIZE} bytes, cap ${SOUL_CAP_BYTES})"
echo "  $PASTE ($(wc -c < "$PASTE" | tr -d ' ') bytes)"
