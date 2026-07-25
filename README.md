# AI Personality

A portable, single-source-of-truth personality and response format spec for AI assistants. One canonical file, per-tool adapters, and sync scripts that distribute the personality to every tool's config automatically.

## Quick Start

**macOS / Linux:**

```bash
./sync.sh
```

**Windows (PowerShell):**

```powershell
./sync.ps1
```

**Options:**

```bash
# Preview what would change without writing
./sync.sh --dry-run

# Sync to a specific project's config files
./sync.sh --project-root /path/to/project
```

## How It Works

`personality.md` is the canonical personality prompt. Adapters in `adapters/` format it for each platform. The sync scripts inject adapter content between HTML comment markers in target config files.

### Target Platforms

| Platform | Config File | Tier | Sync |
|----------|------------|------|------|
| Claude Code | `~/.claude/CLAUDE.md` | 1 | Automatic (global) |
| Gemini CLI | `GEMINI.md` | 1 | Automatic (per-project) |
| OpenAI Codex | `AGENTS.md` | 1 | Automatic (per-project) |
| GitHub Copilot | `.github/copilot-instructions.md` | 1 | Automatic (per-project) |
| Claude AI (web) | Custom instructions | 2 | Manual paste from `adapters/web-paste.md` |
| Claude Co-work | Custom instructions | 2 | Manual paste from `adapters/web-paste.md` |
| ChatGPT | Custom instructions | 2 | Manual paste from `adapters/web-paste.md` |
| Gemini (web) | Custom instructions | 2 | Manual paste from `adapters/web-paste.md` |

**Tier 1** targets sync automatically via scripts. **Tier 2** targets require manual paste; open `adapters/web-paste.md` and copy its content into the platform's settings.

## Clara Identity Artifact

`clara/` holds the versioned Clara identity (design: Patchou-plan task 04):

- `clara/manifest.yaml`: artifact version (stamped into every rendered output)
- `clara/identity.md`: the canonical prose identity
- `clara/traits.yaml`: machine-readable trait dials (lower-only modulation)
- `clara/voice.yaml`: audio identity bindings (uncast voice = consumers refuse)
- `clara/memory-contract.md`: the rules for the private, machine-local memory plane

Commands:

```bash
# Render surface blocks (build/ is gitignored; sources are the truth)
./render-clara.sh

# Distribute: personality to tool configs, Clara to Clara surfaces (SOUL.md)
./sync.sh

# Scaffold the private memory plane on this machine (~/.clara, idempotent)
./init-clara-memory.sh

# Run the test suite
./tests/run-tests.sh
```

The `CLARA-IDENTITY` block only reaches targets that carry its markers; coding-tool
configs keep receiving only the personality block. Memory (`~/.clara/`) never
enters this or any repo. Integration runbooks per surface: `docs/clara-integration.md`.

## Adding Markers to a Target File

Before sync can update a file, it needs markers to know where to inject. Add these to your config file where you want the personality block:

```markdown
<!-- AI-PERSONALITY-START -->
<!-- AI-PERSONALITY-END -->
```

The sync script replaces everything between the markers (inclusive of content, preserving markers). Existing content outside the markers is untouched.

## Adding a New Platform

1. Create a new file in `adapters/` (start by copying an existing adapter)
2. If the platform has character limits, compress as needed and add an HTML comment explaining what changed: `<!-- OVERRIDE: reason -->`
3. For Tier 1 (file-based): add the adapter name and target path to both `sync.sh` and `sync.ps1`
4. For Tier 2 (web paste): no script changes needed

## Updating the Personality

1. Edit `personality.md`
2. Bump the `version:` in the frontmatter
3. Update any adapters that have constrained overrides
4. Run `./sync.sh` (or `./sync.ps1`)
5. For Tier 2 platforms, manually paste from `adapters/web-paste.md`

## Configuration

Edit the target path arrays at the top of `sync.sh` / `sync.ps1` if your file locations differ from the defaults. The Claude Code target (`~/.claude/CLAUDE.md`) is global; all others resolve relative to `--project-root` (defaults to current directory).
