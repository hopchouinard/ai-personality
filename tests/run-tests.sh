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

# Portable permission read (macOS/BSD stat -f, GNU stat -c).
# Branch on the platform, NOT on one implementation's error behaviour: GNU
# `stat -f` is not an error, it means "filesystem status" and exits 0, so a
# `stat -f ... || stat -c ...` fallback never fires on Linux and silently
# returns filesystem info where a permission mode was expected.
perms_of() {
    case "$(uname -s)" in
        Darwin|*BSD*) stat -f '%Lp' "$1" ;;
        *)            stat -c '%a' "$1" ;;
    esac
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

# perms_of must return an octal mode on every platform the suite runs on.
# Previously it returned GNU `stat -f` filesystem output on Linux, which made
# the 0700 assertion in test_init_creates_skeleton compare a mode against a
# multi-line "File: ..." blob. Caught only when the suite was first run on the
# VM, the artifact's actual deployment target.
test_perms_of_returns_octal_mode() {
    local tmp mode
    tmp=$(mktemp -d)
    chmod 700 "$tmp"
    mode=$(perms_of "$tmp")
    case "$mode" in
        700) ;;
        *) fail "perms_of returned '$mode', expected '700' (uname: $(uname -s))"; rm -rf "$tmp"; return 1 ;;
    esac
    chmod 755 "$tmp"
    mode=$(perms_of "$tmp")
    rm -rf "$tmp"
    assert_eq "755" "$mode" "perms_of after chmod 755"
}

test_manifest_structure() {
    local f="$REPO_DIR/clara/manifest.yaml"
    assert_file_exists "$f" || return 1
    assert_grep '^artifact_version: "1.1"' "$f" || return 1
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

# The memory contract is the enforcement instance of the supply-chain rules:
# a surface that reads it at runtime must be bound by them without access to
# any planning document. These tests pin the clauses that obligation requires.
test_contract_episode_format() {
    local f="$REPO_DIR/clara/memory-contract.md"
    assert_file_exists "$f" || return 1
    assert_grep 'YYYY-MM-DD--<machine>--<slug>.md' "$f" || return 1
    assert_grep '^    date: YYYY-MM-DD' "$f" || return 1
    assert_grep '^    surface: <name>' "$f" || return 1
    assert_grep '^    refs: ' "$f" || return 1
    assert_grep '^    privacy: PC3' "$f" || return 1
    assert_grep '^    origin: ' "$f"
}

test_contract_routing_table() {
    local f="$REPO_DIR/clara/memory-contract.md"
    assert_file_exists "$f" || return 1
    # Nine routing rows, each numbered in the leading table cell.
    local rows
    rows=$(grep -c '^| [1-9] | ' "$f")
    assert_eq "9" "$rows" "routing table rows" || return 1
    assert_grep 'NEVER memory' "$f" || return 1
    assert_grep 'curation-only' "$f"
}

test_contract_pressure_policy() {
    local f="$REPO_DIR/clara/memory-contract.md"
    assert_file_exists "$f" || return 1
    assert_grep 'relocate before evict' "$f" || return 1
    assert_grep '90% of its cap' "$f" || return 1
    assert_grep 'leave first' "$f" || return 1
    assert_grep '3+ times become skill candidates' "$f" || return 1
    assert_grep 'no other home' "$f" || return 1
    assert_grep 'last-resort and' "$f"
}

test_contract_conflict_procedures() {
    local f="$REPO_DIR/clara/memory-contract.md"
    assert_file_exists "$f" || return 1
    assert_grep 'Case 1 - contradicted memory' "$f" || return 1
    assert_grep 'Case 2 - stale infrastructure fact' "$f" || return 1
    assert_grep 'Case 3 - personality drift' "$f" || return 1
    assert_grep 'Case 4 - duplicate preferences' "$f" || return 1
    assert_grep 'No inline correction by the observer' "$f" || return 1
    assert_grep 'newest dated observation wins' "$f" || return 1
    assert_grep 'Memory is never the battlefield' "$f" || return 1
    assert_grep 'staleness, not drift' "$f" || return 1
    assert_grep 'latest `since:` date' "$f"
}

test_contract_curation_checklist() {
    local f="$REPO_DIR/clara/memory-contract.md"
    assert_file_exists "$f" || return 1
    assert_grep 'deny-list sanity' "$f" || return 1
    assert_grep 'Relocate before evict' "$f" || return 1
    assert_grep 'Conflict handling' "$f" || return 1
    assert_grep 'fail loudly, never truncate' "$f" || return 1
    # Exports: manifest contents and the pre-bundle scan.
    assert_grep 'file list' "$f" || return 1
    assert_grep 'deny-list scan over the selected files first' "$f"
}

# Regression guard for the marker gate: sync.sh must require whole-line marker
# matches, because its awk replacement does. A substring gate silently reports
# UPDATED while changing nothing (an indented marker in a runbook is the real
# way this happens).
test_sync_marker_gate_is_whole_line() {
    local f="$REPO_DIR/sync.sh"
    assert_file_exists "$f" || return 1
    assert_grep 'grep -qxF' "$f" || return 1
    assert_not_grep 'grep -q "\$MARKER_START"' "$f"
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

# The 0700 parent is the perimeter, so loose modes inside it are unreachable
# and easy to miss - until content LEAVES the perimeter, which is exactly what
# an export bundle is (memory-contract.md, exports). Every file and directory
# the scaffold creates must therefore carry its own tight mode, not inherit
# whatever the invoking umask happened to be.
test_init_locks_down_contents() {
    local tmp
    tmp=$(mktemp -d)
    ( umask 022; "$REPO_DIR/init-clara-memory.sh" --home "$tmp" --machine "m1" >/dev/null ) || { fail "init script failed"; rm -rf "$tmp"; return 1; }
    local ok=0
    assert_eq "700" "$(perms_of "$tmp/.clara")" "~/.clara mode" || ok=1
    assert_eq "700" "$(perms_of "$tmp/.clara/episodes")" "episodes/ mode" || ok=1
    assert_eq "700" "$(perms_of "$tmp/.clara/exports")" "exports/ mode" || ok=1
    assert_eq "600" "$(perms_of "$tmp/.clara/MACHINE")" "MACHINE mode" || ok=1
    assert_eq "600" "$(perms_of "$tmp/.clara/MEMORY.md")" "MEMORY.md mode" || ok=1
    assert_eq "600" "$(perms_of "$tmp/.clara/preferences.yaml")" "preferences.yaml mode" || ok=1
    rm -rf "$tmp"
    return $ok
}

# Both existing installs were scaffolded before the modes were set, so the fix
# is worthless unless the idempotent path RE-ASSERTS them. A run over a loose
# plane must tighten it without touching content.
test_init_retightens_existing_plane() {
    local tmp
    tmp=$(mktemp -d)
    "$REPO_DIR/init-clara-memory.sh" --home "$tmp" --machine "m1" >/dev/null
    echo "precious durable fact" >> "$tmp/.clara/MEMORY.md"
    chmod 755 "$tmp/.clara/episodes"
    chmod 775 "$tmp/.clara/exports"
    chmod 644 "$tmp/.clara/MEMORY.md"
    chmod 664 "$tmp/.clara/MACHINE"
    "$REPO_DIR/init-clara-memory.sh" --home "$tmp" --machine "m1" >/dev/null || { fail "second run failed"; rm -rf "$tmp"; return 1; }
    local ok=0
    assert_eq "700" "$(perms_of "$tmp/.clara/episodes")" "episodes/ re-tightened" || ok=1
    assert_eq "700" "$(perms_of "$tmp/.clara/exports")" "exports/ re-tightened" || ok=1
    assert_eq "600" "$(perms_of "$tmp/.clara/MEMORY.md")" "MEMORY.md re-tightened" || ok=1
    assert_eq "600" "$(perms_of "$tmp/.clara/MACHINE")" "MACHINE re-tightened" || ok=1
    assert_grep "precious durable fact" "$tmp/.clara/MEMORY.md" || ok=1
    rm -rf "$tmp"
    return $ok
}

test_render_outputs() {
    local tmp
    tmp=$(mktemp -d)
    "$REPO_DIR/render-clara.sh" --out "$tmp" >/dev/null || { fail "renderer failed"; rm -rf "$tmp"; return 1; }
    local ok=0
    assert_file_exists "$tmp/clara-soul.md" || ok=1
    assert_file_exists "$tmp/clara-web-paste.md" || ok=1
    if [[ $ok -eq 0 ]]; then
        # The stamp must carry whatever the manifest currently declares, so a
        # version bump does not require editing this test (and a renderer that
        # stamped the wrong version would still fail).
        local mver
        mver=$(grep -m1 '^artifact_version:' "$REPO_DIR/clara/manifest.yaml" | sed 's/artifact_version:[[:space:]]*//; s/"//g')
        assert_grep "clara-identity v$mver" "$tmp/clara-soul.md" || ok=1
        assert_grep '## Who Clara Is' "$tmp/clara-soul.md" || ok=1
        assert_grep '## Trait Dials' "$tmp/clara-soul.md" || ok=1
        assert_grep '^## Memory$' "$tmp/clara-soul.md" || ok=1
        assert_not_grep '^version: 1.0' "$tmp/clara-soul.md" || ok=1
        assert_grep "clara-identity v$mver" "$tmp/clara-web-paste.md" || ok=1
        assert_not_grep '^## Memory$' "$tmp/clara-web-paste.md" || ok=1
    fi
    rm -rf "$tmp"
    return $ok
}

test_render_soul_cap() {
    local tmp src
    tmp=$(mktemp -d)
    src=$(mktemp -d)
    cp "$REPO_DIR/clara/manifest.yaml" "$src/"
    cp "$REPO_DIR/clara/traits.yaml" "$src/"
    cp "$REPO_DIR/clara/memory-contract.md" "$src/"
    {
        printf -- '---\nversion: 1.0\n---\n## Who Clara Is\n'
        local i=0
        while [[ $i -lt 400 ]]; do
            echo "padding line to exceed the soul cap xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
            i=$((i + 1))
        done
    } > "$src/identity.md"
    local ok=0
    if "$REPO_DIR/render-clara.sh" --source "$src" --out "$tmp" >/dev/null 2>&1; then
        fail "renderer should have failed on oversized identity"
        ok=1
    fi
    if [[ -f "$tmp/clara-soul.md" ]]; then
        fail "oversized output file should not exist"
        ok=1
    fi
    rm -rf "$tmp" "$src"
    return $ok
}

_make_sync_fixture() {
    # Creates a temp HOME with a personality target and a clara target.
    # Prints the fixture dir. Caller removes it.
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/.claude"
    cat > "$tmp/.claude/CLAUDE.md" <<'EOF'
# My global instructions
keep-this-line-above
<!-- AI-PERSONALITY-START -->
stale personality content
<!-- AI-PERSONALITY-END -->
keep-this-line-below
EOF
    mkdir -p "$tmp/.hermes"
    cat > "$tmp/.hermes/SOUL.md" <<'EOF'
# Hermes runtime notes
keep-soul-line
<!-- CLARA-IDENTITY-START -->
stock boilerplate to be replaced
<!-- CLARA-IDENTITY-END -->
EOF
    echo "$tmp"
}

# The README and the Hermes runbook both advertise that a machine without a
# rendered build/ skips gracefully rather than erroring. Nothing exercised it.
test_sync_skips_unrendered_build() {
    local tmp proj out ok=0
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    rm -rf "$REPO_DIR/build"
    out=$( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --project-root "$proj" 2>&1 )
    case "$out" in
        *"SKIP: Source not rendered"*) ;;
        *) fail "expected a 'Source not rendered' skip; got: $(printf '%s' "$out" | tail -3)"; ok=1 ;;
    esac
    assert_grep 'stock boilerplate to be replaced' "$tmp/.hermes/SOUL.md" || ok=1
    # The AI-PERSONALITY targets must still be served: one missing source is a
    # skip, not an abort.
    assert_grep 'Cheeky, unapologetically sassy' "$tmp/.claude/CLAUDE.md" || ok=1
    "$REPO_DIR/render-clara.sh" >/dev/null
    rm -rf "$tmp" "$proj"
    return $ok
}

# A machine with no SOUL.md at all (every Mac, today) must skip that entry and
# keep serving the others.
test_sync_skips_missing_soul_target() {
    local tmp proj out ok=0
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    rm -f "$tmp/.hermes/SOUL.md"
    "$REPO_DIR/render-clara.sh" >/dev/null
    out=$( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --project-root "$proj" 2>&1 )
    case "$out" in
        *"SKIP: Target file not found"*) ;;
        *) fail "expected a 'Target file not found' skip"; ok=1 ;;
    esac
    [[ -f "$tmp/.hermes/SOUL.md" ]] && { fail "sync created a SOUL.md that did not exist"; ok=1; }
    assert_grep 'Cheeky, unapologetically sassy' "$tmp/.claude/CLAUDE.md" || ok=1
    rm -rf "$tmp" "$proj"
    return $ok
}

# The harness runs without `set -e`, so a non-zero exit from the sync subshell
# was previously discarded by every other sync test.
test_sync_exit_status() {
    local tmp proj ok=0 rc
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    "$REPO_DIR/render-clara.sh" >/dev/null
    ( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --project-root "$proj" >/dev/null 2>&1 )
    rc=$?
    assert_eq "0" "$rc" "sync.sh exit status on a normal run" || ok=1
    # A markerless target is a skip, not a failure: still exit 0.
    printf '# no markers\n' > "$tmp/.hermes/SOUL.md"
    ( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --project-root "$proj" >/dev/null 2>&1 )
    rc=$?
    assert_eq "0" "$rc" "sync.sh exit status with a markerless target" || ok=1
    rm -rf "$tmp" "$proj"
    return $ok
}

# The runbook tells a human to copy these two lines into a live SOUL.md. If they
# are ever indented again, sync.sh's whole-line gate skips the file and reports
# nothing wrong. The bash side is guarded by test_sync_marker_gate_is_whole_line;
# this guards the document that feeds it.
test_runbook_markers_at_column_zero() {
    local f="$REPO_DIR/docs/clara-integration.md"
    assert_file_exists "$f" || return 1
    assert_grep '^<!-- CLARA-IDENTITY-START -->$' "$f" || return 1
    assert_grep '^<!-- CLARA-IDENTITY-END -->$' "$f"
}

# The rendered soul restates the contract's rules in digest form; the two are
# maintained by hand. This fails when the soul teaches something the contract
# no longer says.
test_soul_rules_match_contract() {
    local tmp contract ok=0
    tmp=$(mktemp -d)
    contract="$REPO_DIR/clara/memory-contract.md"
    "$REPO_DIR/render-clara.sh" --out "$tmp" >/dev/null || { fail "renderer failed"; rm -rf "$tmp"; return 1; }
    local phrase
    for phrase in \
        'YYYY-MM-DD--<machine>--<slug>.md' \
        'append-only' \
        'curation pass' \
        '8KB' \
        'preferences.yaml' \
        'best-effort'
    do
        grep -qF "$phrase" "$tmp/clara-soul.md" || { fail "soul lost the rule: $phrase"; ok=1; }
        grep -qF "$phrase" "$contract" || { fail "soul teaches '$phrase' but the contract does not say it"; ok=1; }
    done
    rm -rf "$tmp"
    return $ok
}

# A repo copy the test may mutate, so version-lookup failures can be induced
# without touching the real working tree. Prints the copy's path.
_copy_repo() {
    local dst
    dst=$(mktemp -d)/rep
    mkdir -p "$dst"
    cp -R "$REPO_DIR/clara" "$REPO_DIR/adapters" "$dst/"
    cp "$REPO_DIR/personality.md" "$REPO_DIR/sync.sh" "$REPO_DIR/render-clara.sh" "$dst/"
    echo "$dst"
}

# THE regression guard for FU-14. With the version lookup resolved before the
# skip gates, a renamed key in clara/manifest.yaml aborted the whole run at the
# CLARA-IDENTITY entry -- AFTER every AI-PERSONALITY target in $HOME had been
# rewritten, with no Summary line and no error text. The operator saw output
# that simply stopped. The run must now complete, report, and exit non-zero.
test_sync_bad_version_does_not_abort_midrun() {
    local tmp proj rep out rc ok=0
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    rep=$(_copy_repo)
    "$REPO_DIR/render-clara.sh" --out "$rep/build" >/dev/null
    sed 's/^artifact_version:/artifactVersion_RENAMED:/' "$rep/clara/manifest.yaml" > "$rep/clara/manifest.tmp"
    mv "$rep/clara/manifest.tmp" "$rep/clara/manifest.yaml"

    out=$( cd "$rep" && HOME="$tmp" ./sync.sh --project-root "$proj" 2>&1 )
    rc=$?

    # 1. The run completed: a Summary line proves it reached the end.
    case "$out" in
        *"Summary:"*) ;;
        *) fail "run aborted mid-loop: no Summary line"; ok=1 ;;
    esac
    # 2. It said why, rather than dying silently.
    case "$out" in
        *"cannot determine the CLARA-IDENTITY version"*) ;;
        *) fail "no diagnostic for the unreadable version"; ok=1 ;;
    esac
    # 3. It counted the error and exited non-zero.
    case "$out" in
        *"1 errors"*) ;;
        *) fail "error not counted in the summary"; ok=1 ;;
    esac
    [[ "$rc" -ne 0 ]] || { fail "exit status was 0 despite an error"; ok=1; }
    # 4. The unrelated block was still served -- one bad entry is not fatal.
    assert_grep 'Cheeky, unapologetically sassy' "$tmp/.claude/CLAUDE.md" || ok=1
    # 5. The block whose version could not be read was NOT stamped.
    assert_grep 'stock boilerplate to be replaced' "$tmp/.hermes/SOUL.md" || ok=1

    rm -rf "$tmp" "$proj" "$(dirname "$rep")"
    return $ok
}

# A missing personality.md must fail before any write, naming the file, rather
# than surfacing a raw `grep: ... No such file` from inside a substitution.
test_sync_missing_personality_fails_clean() {
    local tmp proj rep out rc ok=0
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    rep=$(_copy_repo)
    rm -f "$rep/personality.md"

    out=$( cd "$rep" && HOME="$tmp" ./sync.sh --project-root "$proj" 2>&1 )
    rc=$?

    case "$out" in
        *"personality.md not found"*) ;;
        *) fail "expected a named 'personality.md not found' error"; ok=1 ;;
    esac
    case "$out" in
        *"grep:"*) fail "leaked a raw grep error to the operator"; ok=1 ;;
    esac
    [[ "$rc" -ne 0 ]] || { fail "exit status was 0 with personality.md missing"; ok=1; }
    # Fails closed: nothing was written before the check.
    assert_grep 'stale personality content' "$tmp/.claude/CLAUDE.md" || ok=1

    rm -rf "$tmp" "$proj" "$(dirname "$rep")"
    return $ok
}

# render-clara.sh's own guard was equally dead: the assignment died first.
test_render_bad_version_reports_clean() {
    local src out rc ok=0
    src=$(mktemp -d)
    cp "$REPO_DIR/clara/identity.md" "$REPO_DIR/clara/traits.yaml" \
       "$REPO_DIR/clara/memory-contract.md" "$src/"
    sed 's/^artifact_version:/artifactVersion_RENAMED:/' "$REPO_DIR/clara/manifest.yaml" > "$src/manifest.yaml"

    out=$( "$REPO_DIR/render-clara.sh" --source "$src" --out "$src/out" 2>&1 )
    rc=$?

    [[ "$rc" -ne 0 ]] || { fail "renderer exited 0 with an unreadable version"; ok=1; }
    case "$out" in
        *"artifact_version"*) ;;
        *) fail "renderer failed without naming artifact_version; got: '$out'"; ok=1 ;;
    esac
    [[ -f "$src/out/clara-soul.md" ]] && { fail "wrote a soul despite the failure"; ok=1; }

    rm -rf "$src"
    return $ok
}

test_sync_updates_both_blocks() {
    local tmp proj ok=0
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    "$REPO_DIR/render-clara.sh" >/dev/null
    ( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --project-root "$proj" >/dev/null )
    assert_grep 'Cheeky, unapologetically sassy' "$tmp/.claude/CLAUDE.md" || ok=1
    assert_not_grep 'stale personality content' "$tmp/.claude/CLAUDE.md" || ok=1
    assert_grep 'keep-this-line-above' "$tmp/.claude/CLAUDE.md" || ok=1
    assert_grep 'keep-this-line-below' "$tmp/.claude/CLAUDE.md" || ok=1
    assert_grep '## Who Clara Is' "$tmp/.hermes/SOUL.md" || ok=1
    assert_not_grep 'stock boilerplate to be replaced' "$tmp/.hermes/SOUL.md" || ok=1
    assert_grep 'keep-soul-line' "$tmp/.hermes/SOUL.md" || ok=1
    assert_not_grep '## Who Clara Is' "$tmp/.claude/CLAUDE.md" || ok=1
    rm -rf "$tmp" "$proj"
    return $ok
}

test_sync_is_idempotent() {
    local tmp proj ok=0
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    "$REPO_DIR/render-clara.sh" >/dev/null
    ( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --project-root "$proj" >/dev/null )
    cp "$tmp/.claude/CLAUDE.md" "$tmp/first-claude"
    cp "$tmp/.hermes/SOUL.md" "$tmp/first-soul"
    ( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --project-root "$proj" >/dev/null )
    cmp -s "$tmp/first-claude" "$tmp/.claude/CLAUDE.md" || { fail "CLAUDE.md changed on second run"; ok=1; }
    cmp -s "$tmp/first-soul" "$tmp/.hermes/SOUL.md" || { fail "SOUL.md changed on second run"; ok=1; }
    rm -rf "$tmp" "$proj"
    return $ok
}

test_sync_dry_run_writes_nothing() {
    local tmp proj ok=0
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    "$REPO_DIR/render-clara.sh" >/dev/null
    ( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --dry-run --project-root "$proj" >/dev/null )
    assert_grep 'stale personality content' "$tmp/.claude/CLAUDE.md" || ok=1
    assert_grep 'stock boilerplate to be replaced' "$tmp/.hermes/SOUL.md" || ok=1
    rm -rf "$tmp" "$proj"
    return $ok
}

test_sync_skips_target_without_markers() {
    local tmp proj ok=0
    tmp=$(_make_sync_fixture)
    proj=$(mktemp -d)
    printf '# no markers here\nprecious content\n' > "$tmp/.hermes/SOUL.md"
    "$REPO_DIR/render-clara.sh" >/dev/null
    ( cd "$REPO_DIR" && HOME="$tmp" ./sync.sh --project-root "$proj" >/dev/null )
    assert_eq "$(printf '# no markers here\nprecious content\n')" "$(cat "$tmp/.hermes/SOUL.md")" "markerless file must be untouched" || ok=1
    rm -rf "$tmp" "$proj"
    return $ok
}

# ------------------------------------------------------------------
TESTS="
test_harness_smoke
test_perms_of_returns_octal_mode
test_manifest_structure
test_identity_structure
test_traits_structure
test_traits_intensities_in_range
test_voice_contract
test_memory_contract
test_contract_episode_format
test_contract_routing_table
test_contract_pressure_policy
test_contract_conflict_procedures
test_contract_curation_checklist
test_init_creates_skeleton
test_init_is_idempotent
test_init_locks_down_contents
test_init_retightens_existing_plane
test_render_outputs
test_render_soul_cap
test_sync_updates_both_blocks
test_sync_is_idempotent
test_sync_dry_run_writes_nothing
test_sync_skips_target_without_markers
test_sync_marker_gate_is_whole_line
test_sync_skips_unrendered_build
test_sync_skips_missing_soul_target
test_sync_exit_status
test_runbook_markers_at_column_zero
test_soul_rules_match_contract
test_sync_bad_version_does_not_abort_midrun
test_sync_missing_personality_fails_clean
test_render_bad_version_reports_clean
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
