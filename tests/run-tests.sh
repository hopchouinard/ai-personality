#!/usr/bin/env bash
# Test harness for ai-personality. Plain bash, zero dependencies.
# Usage: ./tests/run-tests.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

fail() {
    echo "    FAIL: $1"
    TEST_FAILED=1
    return 1
}

assert_file_exists() {
    [[ -f "$1" ]] || fail "expected file to exist: $1"
}

assert_grep() {
    grep -q "$1" "$2" || fail "expected pattern '$1' in $2"
}

assert_not_grep() {
    if grep -q "$1" "$2"; then
        fail "unexpected pattern '$1' found in $2"
    fi
}

assert_eq() {
    if [[ "$1" != "$2" ]]; then
        fail "${3:-values differ}: expected '$1', got '$2'"
    fi
}

# Portable permission read (macOS stat -f, GNU stat -c)
perms_of() {
    stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

run_test() {
    echo "--- $1"
    TEST_FAILED=0
    if "$1" && [[ $TEST_FAILED -eq 0 ]]; then
        PASS=$((PASS + 1))
        echo "    ok"
    else
        FAIL=$((FAIL + 1))
    fi
}

# ------------------------------------------------------------------
# Tests (each task appends its functions here and registers them in TESTS)
# ------------------------------------------------------------------

test_harness_smoke() {
    assert_eq "1" "1" "smoke"
}

test_manifest_structure() {
    local f="$REPO_DIR/clara/manifest.yaml"
    assert_file_exists "$f" || return 1
    assert_grep '^artifact_version: "1.0"' "$f" || return 1
    assert_grep '^components:' "$f" || return 1
    assert_grep 'identity.md' "$f" || return 1
    assert_grep 'traits.yaml' "$f" || return 1
    assert_grep 'voice.yaml' "$f" || return 1
    assert_grep 'memory-contract.md' "$f"
}

test_identity_structure() {
    local f="$REPO_DIR/clara/identity.md"
    assert_file_exists "$f" || return 1
    assert_grep '^version: 1.0' "$f" || return 1
    assert_grep '^## Who Clara Is' "$f" || return 1
    assert_grep 'Clarity Over Ego' "$f" || return 1
    assert_grep 'beige agreement' "$f" || return 1
    assert_grep "I bite, but I don't bleed" "$f" || return 1
    assert_grep '^## Boundaries' "$f" || return 1
    assert_grep 'Québec French' "$f" || return 1
    assert_grep '^## Memory Posture' "$f"
}

test_traits_structure() {
    local f="$REPO_DIR/clara/traits.yaml"
    assert_file_exists "$f" || return 1
    assert_grep '^baseline:' "$f" || return 1
    assert_grep '  sass:' "$f" || return 1
    assert_grep '  sarcasm:' "$f" || return 1
    assert_grep '  whimsy:' "$f" || return 1
    assert_grep '  curiosity:' "$f" || return 1
    assert_grep '  skeptic:' "$f" || return 1
    assert_grep 'anti_sycophancy: strong' "$f" || return 1
    assert_grep 'rule: lower-only' "$f"
}

test_traits_intensities_in_range() {
    local f="$REPO_DIR/clara/traits.yaml"
    assert_file_exists "$f" || return 1
    local bad
    bad=$(awk '/intensity:/ { v = $2 + 0; if (v < 0.0 || v > 1.0) print $0 }' "$f")
    assert_eq "" "$bad" "intensity values outside 0.0-1.0"
}

test_voice_contract() {
    local f="$REPO_DIR/clara/voice.yaml"
    assert_file_exists "$f" || return 1
    assert_grep '^primary_engine: xtts-v2' "$f" || return 1
    assert_grep 'fr-CA' "$f" || return 1
    assert_grep 'path: null' "$f" || return 1
    assert_grep 'eleven_voice_id: null' "$f" || return 1
    assert_grep '^fallback_policy: refuse' "$f"
}

test_memory_contract() {
    local f="$REPO_DIR/clara/memory-contract.md"
    assert_file_exists "$f" || return 1
    assert_grep '~/.clara/' "$f" || return 1
    assert_grep 'MUST NOT write raw email bodies' "$f" || return 1
    assert_grep '8KB' "$f" || return 1
    assert_grep 'append-only' "$f" || return 1
    assert_grep 'curation pass' "$f"
}

test_init_creates_skeleton() {
    local tmp
    tmp=$(mktemp -d)
    "$REPO_DIR/init-clara-memory.sh" --home "$tmp" --machine "test-machine" >/dev/null || { fail "init script failed"; rm -rf "$tmp"; return 1; }
    local ok=0
    [[ -d "$tmp/.clara/episodes" ]] || { fail "missing episodes/"; ok=1; }
    [[ -d "$tmp/.clara/exports" ]] || { fail "missing exports/"; ok=1; }
    [[ -f "$tmp/.clara/MACHINE" ]] || { fail "missing MACHINE"; ok=1; }
    [[ -f "$tmp/.clara/MEMORY.md" ]] || { fail "missing MEMORY.md"; ok=1; }
    [[ -f "$tmp/.clara/preferences.yaml" ]] || { fail "missing preferences.yaml"; ok=1; }
    if [[ $ok -eq 0 ]]; then
        assert_eq "test-machine" "$(cat "$tmp/.clara/MACHINE")" "MACHINE content" || ok=1
    fi
    if [[ $ok -eq 0 ]]; then
        assert_eq "700" "$(perms_of "$tmp/.clara")" "~/.clara permissions" || ok=1
    fi
    rm -rf "$tmp"
    return $ok
}

test_init_is_idempotent() {
    local tmp
    tmp=$(mktemp -d)
    "$REPO_DIR/init-clara-memory.sh" --home "$tmp" --machine "m1" >/dev/null
    echo "precious durable fact" >> "$tmp/.clara/MEMORY.md"
    "$REPO_DIR/init-clara-memory.sh" --home "$tmp" --machine "m1" >/dev/null || { fail "second run failed"; rm -rf "$tmp"; return 1; }
    local ok=0
    assert_grep "precious durable fact" "$tmp/.clara/MEMORY.md" || ok=1
    rm -rf "$tmp"
    return $ok
}

# ------------------------------------------------------------------
TESTS="
test_harness_smoke
test_manifest_structure
test_identity_structure
test_traits_structure
test_traits_intensities_in_range
test_voice_contract
test_memory_contract
test_init_creates_skeleton
test_init_is_idempotent
"

for t in $TESTS; do
    run_test "$t"
done

echo ""
echo "Summary: $PASS passed, $FAIL failed"
if [[ $FAIL -eq 0 ]]; then
    echo "ALL TESTS PASSED"
    exit 0
fi
exit 1
