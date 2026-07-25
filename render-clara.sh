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
    echo "Durable memory lives in ~/.clara/ on this machine, governed by the memory"
    echo "contract (clara/memory-contract.md, artifact v$VERSION). Read MEMORY.md when"
    echo "personal context matters; write episodes; never edit MEMORY.md outside a"
    echo "curation pass. Never write raw Google-sourced content into memory."
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
