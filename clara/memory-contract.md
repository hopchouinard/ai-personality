---
version: 1.0
last-updated: 2026-07-02
---

# Clara Memory Contract

The memory plane is machine-local, private, and owner-controlled. It lives at
`~/.clara/` (permissions 0700), is NEVER committed to any git repository, and
is NEVER synced continuously to any other machine or service.

## Layout

    ~/.clara/
      MACHINE             one line: this machine's identifier (e.g., "mac-studio")
      MEMORY.md           durable distilled facts; HARD CAP 8KB; curated, never appended blindly
      preferences.yaml    evolving structured preferences
      episodes/           append-only entries: YYYY-MM-DD--<machine>--<slug>.md
      exports/            explicit transfer bundles only

## Who may write what

- Automated writers (Hermes, scheduled agents, any surface) may APPEND episodes
  and update `preferences.yaml`. Episodes are append-only: never rewritten,
  never merged, freely deletable by Patrick without breaking anything.
- `MEMORY.md` is edited ONLY by a curation pass: a human, or an agent session
  explicitly asked to curate. The curation checklist: distill new episodes into
  durable facts; dedupe; evict superseded facts; verify each retained fact is
  still true; keep the file under its 8KB cap; stamp the artifact version and date.

## The Google rule

The Gmail/Calendar/Drive-connected surface MUST NOT write raw email bodies,
calendar descriptions, document content, or verbatim quotes from them into any
memory file. It records summaries and references by stable identifier (message
ID, event ID, document title) only.

## Transfer between machines

The only sanctioned movement is an explicit export bundle: a tar of selected
episodes plus a manifest (artifact version, machine, date range) placed in
`exports/`, created and imported deliberately. Import places episodes verbatim
(filenames are collision-proof by construction: they embed the machine ID) and
NEVER touches the target machine's `MEMORY.md`.

## Encryption and threat model

Full-disk encryption is REQUIRED on portable machines (FileVault). LAN-only
homelab VMs are accepted under the homelab's existing threat model, documented
as residual risk; a VM holding Google-derived episodes SHOULD gain disk
encryption at the hypervisor layer.

## Consumers

Memory is best-effort context, never load-bearing state. Any consumer must
behave correctly (if less personally) when `~/.clara/` is absent or empty.
