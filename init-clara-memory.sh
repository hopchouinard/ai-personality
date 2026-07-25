#!/usr/bin/env bash
# Scaffold the Clara memory plane on this machine, per clara/memory-contract.md.
# Idempotent: existing files are never overwritten.
# Usage: ./init-clara-memory.sh [--home DIR] [--machine NAME]
set -euo pipefail

HOME_DIR="$HOME"
MACHINE_NAME="$(hostname -s 2>/dev/null || echo unknown-machine)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --home)
            HOME_DIR="$2"
            shift 2
            ;;
        --machine)
            MACHINE_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: init-clara-memory.sh [--home DIR] [--machine NAME]" >&2
            exit 1
            ;;
    esac
done

CLARA_DIR="$HOME_DIR/.clara"

make_dir() {
    if [[ -d "$1" ]]; then
        echo "kept:    $1"
    else
        mkdir -p "$1"
        echo "created: $1"
    fi
}

make_dir "$CLARA_DIR"
make_dir "$CLARA_DIR/episodes"
make_dir "$CLARA_DIR/exports"
chmod 700 "$CLARA_DIR"

if [[ -f "$CLARA_DIR/MACHINE" ]]; then
    echo "kept:    $CLARA_DIR/MACHINE ($(cat "$CLARA_DIR/MACHINE"))"
else
    printf '%s\n' "$MACHINE_NAME" > "$CLARA_DIR/MACHINE"
    echo "created: $CLARA_DIR/MACHINE ($MACHINE_NAME)"
fi

if [[ -f "$CLARA_DIR/MEMORY.md" ]]; then
    echo "kept:    $CLARA_DIR/MEMORY.md"
else
    cat > "$CLARA_DIR/MEMORY.md" <<'EOF'
# Clara Durable Memory

HARD CAP: 8KB. Edited only by a curation pass (see clara/memory-contract.md in
the ai-personality repo). Automated writers append episodes instead.

<!-- curated-against: clara-identity v1.0 | last-curation: never -->
EOF
    echo "created: $CLARA_DIR/MEMORY.md"
fi

if [[ -f "$CLARA_DIR/preferences.yaml" ]]; then
    echo "kept:    $CLARA_DIR/preferences.yaml"
else
    cat > "$CLARA_DIR/preferences.yaml" <<'EOF'
# Patrick's evolving preferences. Structured entries; automated writers may update.
# Format per entry: key, value, source (episode filename or "manual"), updated (date).
version: "1.0"
preferences: []
EOF
    echo "created: $CLARA_DIR/preferences.yaml"
fi

echo "Memory plane ready at $CLARA_DIR (machine: $(cat "$CLARA_DIR/MACHINE"))"
