# Clara Integration Runbooks

How each surface consumes the Clara identity artifact. The design of record is
Patchou-plan `tasks/04-clara-identity-memory/2026-07-02-clara-identity-memory-design.md`.

## Hermes (the VM assistant) — SOUL.md

One-time setup, on the hermes VM:

1. Clone this repo on the VM (read-only consumption): `git clone <ai-personality remote> ~/ai-personality`
2. Edit `~/.hermes/SOUL.md`: delete the stock boilerplate and leave (only) any
   Hermes-runtime mechanics you need to keep, plus the two marker lines where
   Clara goes. Copy them from the fenced block below **exactly, at column 0**:
   `sync.sh` matches whole lines, so any leading or trailing whitespace makes it
   skip the file rather than install Clara.

```text
<!-- CLARA-IDENTITY-START -->
<!-- CLARA-IDENTITY-END -->
```

3. Render and sync (from `~/ai-personality`): `./render-clara.sh` then `./sync.sh`
4. Scaffold the memory plane: `./init-clara-memory.sh --machine hermes-vm`
5. Replace the persona lines in Honcho memory with the single pointer:
   `Clara identity is versioned: see SOUL.md (clara-identity vX.Y); durable memory lives in ~/.clara/ per its memory-contract.`
   Substitute the real `X.Y`: read `artifact_version` from `clara/manifest.yaml`,
   or the stamp line at the top of the rendered `~/.hermes/SOUL.md`. Do not
   hardcode a version that the artifact may have moved past.

Updates: `git -C ~/ai-personality pull` then render + sync. Staleness check:
`grep clara-identity ~/.hermes/SOUL.md` and compare to `clara/manifest.yaml`.
This belongs in the same governed maintenance lane as other VM update jobs.

## Web Clara projects (ChatGPT / Claude projects)

Render, then paste `build/clara-web-paste.md` into the project's custom
instructions. The stamp line records which version is deployed.

## ClaraVoice (conditional; see design D14)

Consumes `clara/traits.yaml` and `clara/voice.yaml` directly from a checkout.
The loader work lives in ClaraVoice (injection seam:
`ProduceService.__init__(personas=...)`); the sass-quota literal is replaced by
artifact-derived data. Until `voice.yaml` carries a cast xtts-v2 reference
sample, ClaraVoice MUST refuse to synthesize as Clara (fallback_policy: refuse);
stock-voice substitution and silence-as-success are both forbidden.

## ClaraNews stage 5 (conditional; see design D14)

If kept by the portfolio audit: a per-run persona YAML generated from the
artifact (name, `eleven_voice_id` from `voice.yaml` bindings, style from
traits) slots into the `personas[]` array of `POST /podcast-runs`. Casting an
ElevenLabs voice ships Clara's voice to a cloud provider: deliberate,
separately-consented act, never a default.

## What no surface may do

- Write to `clara/` outside a PR to this repo.
- Move memory-plane content into any repo, sync service, or another machine
  outside an explicit export bundle (`clara/memory-contract.md`).
- Raise a trait intensity above baseline, add traits, or touch the locked block.
- Synthesize audio "as Clara" without a cast, verified voice binding.
