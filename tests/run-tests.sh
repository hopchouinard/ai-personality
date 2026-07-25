#!/usr/bin/env bash
# Test harness for ai-personality. Plain bash, zero dependencies.
# Usage: ./tests/run-tests.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

fail() {
    echo "    FAIL: $1"
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
    if "$1"; then
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

# ------------------------------------------------------------------
TESTS="
test_harness_smoke
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
