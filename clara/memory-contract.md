---
version: 1.1
last-updated: 2026-07-25
---

# Clara Memory Contract

The memory plane is machine-local, private, and owner-controlled. It lives at
`~/.clara/` (permissions 0700), is NEVER committed to any git repository, and
is NEVER synced continuously to any other machine or service.

This file is the **enforcement instance** of the memory rules: a surface that
reads it at runtime is bound by it, without needing access to any design or
planning document. The rules below are normative.

## Layout

    ~/.clara/
      MACHINE             one line: this machine's identifier (e.g., "mac-studio")
      MEMORY.md           durable distilled facts; HARD CAP 8KB; curated, never appended blindly
      preferences.yaml    evolving structured preferences
      episodes/           append-only entries: YYYY-MM-DD--<machine>--<slug>.md
      exports/            explicit transfer bundles only

## Who may write what

- Automated writers (any Clara surface, scheduled agents) may APPEND episodes
  and update `preferences.yaml`. Episodes are append-only: never rewritten,
  never merged, freely deletable by the owner without breaking anything.
- `MEMORY.md` is edited ONLY by a curation pass: a human, or an agent session
  explicitly asked to curate. The checklist is below.

## Episode format

Every episode is a file at `~/.clara/episodes/YYYY-MM-DD--<machine>--<slug>.md`.
Filenames embed the machine identifier, which is what makes episodes
collision-free across machines by construction.

Frontmatter:

    ---
    date: YYYY-MM-DD          # required
    surface: <name>           # required - which surface wrote it
    refs: [<id>, ...]         # required - may be empty; stable identifiers only
    privacy: PC3              # required - private-personal; the only class
                              #   permitted for episode content
    origin: [<id>, ...]       # optional - evidence identifiers this episode
                              #   was derived from
    ---

Episodes are append-only. No tool edits an existing episode. A correction is a
new episode, never an edit to the old one.

## Routing: what goes where

Every "this should be remembered" signal routes by WHAT it is, not by where it
surfaced. The router - a curation session, an analysis agent, or the owner -
consults this table. A signal has exactly one route; two stores never both
partly own it.

| # | Signal type | Durable outcome | Home | Route | Decided by |
|---|---|---|---|---|---|
| 1 | Durable personal fact (relationships, history, standing context) | `MEMORY.md` entry | `~/.clara/MEMORY.md` | episode first, distilled at the next curation pass | human (curation diff reviewed) |
| 2 | Preference (how the owner wants things) | `preferences.yaml` entry | `~/.clara/preferences.yaml` | direct structured write by a Clara surface, or proposal to episode to curation | automated may write the entry; human owns the curated file |
| 3 | Identity change (who Clara is: voice, boundaries, traits) | new artifact version | this repo's `clara/` | pull request; drift evidence recorded as an episode | human (merge; MAJOR/MINOR per the manifest) |
| 4 | Episode (an event worth being able to recall) | episode file | `~/.clara/episodes/` | append, machine-stamped filename | automated (sanctioned direct write) |
| 5 | Skill candidate (a procedure observed 3+ times) | draft skill, then installed skill | the surface's skill directory | proposal; installation is a separate human act | human approves, human installs |
| 6 | Production prompt found ungoverned | versioned prompt in a skill or repo | the owning system's git repo | relocation PR; the ungoverned copy dies | human (reviewed commit) |
| 7 | Capability idea / project seed | issue in the project intake tracker | that tracker | drafted by any surface, posted via its publisher | human (triage) |
| 8 | Infrastructure or operational fact | inventory row or infrastructure doc | the infrastructure authority store | **NEVER memory** - memory keeps at most one pointer line | human (reviewed commit) |
| 9 | Review item / policy observation | review record, then a catalog entry if actioned | the review's own store | the reviewer protocol | human (lands by PR) |

An approved memory-type proposal is applied by writing an **episode file**. It
is NEVER applied by editing `MEMORY.md` directly - that file is curation-only.

## Memory pressure: relocate before evict

Standing law for EVERY capped or curated memory store, including `MEMORY.md`.

1. **Trigger:** a store past **90% of its cap** - or a curator report saying
   eviction is imminent - makes pressure handling MANDATORY at the next
   curation pass. It is not optional hygiene.
2. **Relocate before evicting**, in this order:
   a. **Facts with a better authority home leave first.** Infrastructure
      endpoints, ports and paths go to the infrastructure authority;
      operational policies go to their versioned policy files; production
      prompts go to versioned skills. The memory store keeps at most ONE
      pointer line per relocated cluster.
   b. **Procedures observed 3+ times become skill candidates.** Emit the
      proposal; the memory entry survives only until the skill exists.
   c. **Personal and preference context distills into this plane.** This is
      the content with **no other home** - it moves last, and only to a real
      substrate, never to a store of convenience.
3. **A working-memory store converges to a single pointer line** to this plane.
   Every curation pass moves it monotonically toward that state; space freed by
   relocation is consumed by the pointer, not by new payloads.
4. **Evicting personal context that has no home yet is last-resort and
   human-only.** A curator may NOT silently evict personal entries to make
   room: it flags the pressure and the owner decides. Relocatable facts have
   loss-free exits; personal context does not.
5. **No new durable writers** into a working-memory store beyond the pointer.

The eviction order is deliberately inverted from the obvious one: things WITH
homes leave first, and the homeless are protected by a human gate.

## The Google rule

The Gmail/Calendar/Drive-connected surface MUST NOT write raw email bodies,
calendar descriptions, document content, or verbatim quotes from them into any
memory file. It records summaries and references by stable identifier (message
ID, event ID, document title) only.

## Conflict procedures

### Case 1 - contradicted memory

Trigger: new evidence contradicts an entry in a memory store.

1. **No inline correction by the observer.** The agent that notices MUST NOT
   edit the memory store in place. It records the contradiction as an
   **episode**, citing the evidence identifiers in `origin:`.
2. **Classify at the next curation pass.** If the fact has a non-memory
   authority (infrastructure, policy, schedule, identity), this is case 2 or
   case 3 - route there; the entry was misfiled to begin with.
3. **Genuinely personal fact:** verify against evidence at origin. The
   **newest dated observation wins**; the curation diff replaces the entry with
   a `since:` date, and the episode from step 1 preserves the history.
4. **Irreconcilable** (contemporaneous contradictions, or ambiguous evidence):
   keep both statements marked `disputed:` and surface the question to the
   owner at curation review. Never silently pick a winner.
5. **Never resolved by vote of stores.** Two stores agreeing is not evidence;
   only the authority store or fresh origin evidence counts.

### Case 2 - stale infrastructure fact

1. **Memory is never the battlefield.** An infrastructure fact in a memory
   store is misfiled by definition: the resolution is relocation, not
   correction. At the next curation the entry becomes a pointer line to the
   authority, regardless of which value was right.
2. **Authority vs runtime:** if the authority store itself disagrees with
   observed reality, reconcile toward observed reality through that store's
   own governed write path, with audit. No memory store, doc, or digest is
   ever the reconciliation source.
3. **Projections** (generated docs, wikis, diagrams) are regenerated from the
   authority, never hand-patched.
4. **Check the stale value's blast radius once:** grep the memory stores and
   skills for the same stale fact, so one correction does not leave two copies
   behind.

### Case 3 - personality drift

1. **Detect mechanically first:** compare the surface's stamp line
   (`<!-- clara-identity vX.Y ... -->`) against `clara/manifest.yaml`. A stale
   stamp is **staleness, not drift** - re-render and re-sync. Never hand-edit
   the projection.
2. **Un-stamped persona fragments** found anywhere (prompt openings, memory
   persona lines, hardcoded persona objects) are drift debt: relocate them into
   the artifact by PR, or delete them, leaving the pointer convention.
3. **Substantive drift** (behavior diverges with a current stamp, or the change
   is wanted): record the observation as an episode with dated, paraphrased
   examples; route the change itself as a **PR to `clara/`**, versioned
   MAJOR/MINOR. Identity NEVER changes by memory write, prompt patch, or
   surface edit.
4. **Surface-local modulation stays legal within bounds:** intensities
   down-only, no added traits, no contradictions. Anything beyond that is drift
   by definition.
5. **Voice:** an uncast or unavailable voice binding refuses. A fallback voice
   impersonating Clara is an identity failure, not an audio bug.

### Case 4 - duplicate preferences

1. **One home:** per machine, `~/.clara/preferences.yaml` is the preference
   authority. Every other occurrence is a projection, to be pointer-ized or
   deleted at its next touch.
2. **In-store duplicates:** at curation, normalize to a topic key; one entry
   survives, with the **latest `since:` date**. The superseded value lives in
   the episode trail, not in the file.
3. **Cross-machine:** machine planes never auto-merge. A preference travels
   only inside an explicit export bundle, and the IMPORTING machine's curation
   dedups against its own file. Divergent per-machine preferences are legal -
   mark machine-scoped entries `scope: <machine>`.
4. **Proposed duplicates:** fingerprint dedup prevents re-proposing an
   already-approved or already-rejected preference. An approved proposal
   becomes an episode, distilled ONCE at curation; the curation pass checks
   `preferences.yaml` before adding.
5. **Conflicting values from different surfaces in the same window:** treat as
   case 1 step 4 - disputed, ask the owner.

## The curation checklist

`MEMORY.md` is rewritten only by a curation pass, and the pass runs these steps
**in order**:

1. **Secret and deny-list sanity** on any imported material.
2. **Relocate before evict**, in the order above: authority-homed facts out
   first, procedures seen 3+ times to skill candidates, personal context
   distilled last.
3. **Conflict handling** per the four cases above.
4. **Dedupe, evict superseded facts, and verify** each retained fact is still
   true.
5. **Stamp** the artifact version and the date.
6. **Confirm `MEMORY.md` is within its 8KB cap - fail loudly, never truncate
   silently.**

## Transfer between machines

The only sanctioned movement is an explicit export bundle: a tar of selected
episodes plus a manifest, placed in `exports/`, created and imported
deliberately.

- The manifest carries the **artifact version, machine, date range, and the
  file list**.
- Bundle creation runs the **deny-list scan over the selected files first**.
- Import places episodes verbatim (filenames are collision-proof by
  construction: they embed the machine ID) and NEVER touches the target
  machine's `MEMORY.md`. Distilling an imported episode is a curation act.

## Encryption and threat model

Full-disk encryption is REQUIRED on portable machines (FileVault).

## Consumers

Memory is best-effort context, never load-bearing state. Any consumer must
behave correctly (if less personally) when `~/.clara/` is absent or empty. A
deleted episode, an empty `MEMORY.md`, or a missing plane never breaks a
surface - deletion is a feature.
