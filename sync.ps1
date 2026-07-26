[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# -------------------------------------------------------------------
# Configuration: one entry per sync target.
#   Format: "<source path, repo-relative>|<BLOCK>|<target path>"
# Markers are derived from BLOCK: <!-- BLOCK-START --> / <!-- BLOCK-END -->
# Rooted target paths are absolute (global targets); all others resolve
# relative to -ProjectRoot. Sources under build/ are rendered artifacts.
# Edit these once per machine if your paths differ from the defaults.
# -------------------------------------------------------------------
$SyncEntries = @(
    ("adapters/claude-code.md|AI-PERSONALITY|" + (Join-Path $HOME ".claude" "CLAUDE.md"))
    ("adapters/gemini-cli.md|AI-PERSONALITY|" + (Join-Path $HOME ".gemini" "GEMINI.md"))
    "adapters/gemini-cli.md|AI-PERSONALITY|GEMINI.md"
    ("adapters/codex.md|AI-PERSONALITY|" + (Join-Path $HOME ".codex" "AGENTS.md"))
    "adapters/codex.md|AI-PERSONALITY|AGENTS.md"
    ("adapters/copilot.md|AI-PERSONALITY|" + (Join-Path $HOME ".copilot" "copilot-instructions.md"))
    ("adapters/copilot.md|AI-PERSONALITY|" + (Join-Path ".github" "copilot-instructions.md"))
    ("build/clara-soul.md|CLARA-IDENTITY|" + (Join-Path $HOME ".hermes" "SOUL.md"))
)

function Get-BlockVersion {
    param([string]$Block)
    switch ($Block) {
        "AI-PERSONALITY" {
            $line = Get-Content (Join-Path $ScriptDir "personality.md") | Where-Object { $_ -match "^version:" } | Select-Object -First 1
            if ($line -match "^version:\s*(.+)$") { return $Matches[1].Trim() }
            return $null
        }
        "CLARA-IDENTITY" {
            $manifest = Join-Path $ScriptDir "clara" "manifest.yaml"
            if (-not (Test-Path $manifest)) { return $null }
            $line = Get-Content $manifest | Where-Object { $_ -match "^artifact_version:" } | Select-Object -First 1
            if ($line -match "^artifact_version:\s*(.+)$") { return $Matches[1].Trim().Trim('"') }
            return $null
        }
        default { return "unknown" }
    }
}

$PersonalityVersion = Get-BlockVersion "AI-PERSONALITY"
if (-not $PersonalityVersion) {
    Write-Error "Could not parse version from personality.md"
    exit 1
}

Write-Host "AI Personality Sync v$PersonalityVersion"
Write-Host "Project root: $ProjectRoot"
if ($WhatIfPreference) {
    Write-Host "Mode: DRY RUN (no files will be modified)"
}
Write-Host ""

$Updated = 0
$Skipped = 0
$Errors  = 0

foreach ($Entry in $SyncEntries) {
    $Parts = $Entry -split '\|', 3
    $SourceRel = $Parts[0]
    $Block     = $Parts[1]
    $Target    = $Parts[2]

    $SourceFile  = Join-Path $ScriptDir $SourceRel
    $MarkerStart = "<!-- $Block-START -->"
    $MarkerEnd   = "<!-- $Block-END -->"
    $BlockVersion = Get-BlockVersion $Block

    if (-not [System.IO.Path]::IsPathRooted($Target)) {
        $Target = Join-Path $ProjectRoot $Target
    }

    Write-Host "--- [$Block] $SourceRel -> $Target"

    if (-not (Test-Path $SourceFile)) {
        if ($SourceRel -like "build/*") {
            Write-Host "  SKIP: Source not rendered: $SourceRel (run ./render-clara.sh first)"
        } else {
            Write-Host "  SKIP: Source file not found: $SourceFile"
        }
        $Skipped++
        continue
    }

    if (-not (Test-Path $Target)) {
        Write-Host "  SKIP: Target file not found: $Target"
        $Skipped++
        continue
    }

    $TargetContent = Get-Content $Target -Raw

    # Markers must match a WHOLE LINE, exactly as sync.sh's awk requires
    # ($0 == start). A substring test would accept an indented or trailing-text
    # marker that the replacement below then fails to find, reporting UPDATED
    # while changing nothing. (?m) makes ^/$ line anchors.
    $StartLine = "(?m)^" + [regex]::Escape($MarkerStart) + "$"
    $EndLine   = "(?m)^" + [regex]::Escape($MarkerEnd) + "$"

    if ($TargetContent -notmatch $StartLine -or
        $TargetContent -notmatch $EndLine) {
        Write-Host "  SKIP: Markers not found in target file"
        $Skipped++
        continue
    }

    $SourceContent = Get-Content $SourceFile -Raw

    if ($PSCmdlet.ShouldProcess($Target, "Update $Block content (v$BlockVersion)")) {
        # (?s) so .*? spans newlines, (?m) so the markers anchor to whole lines.
        $Pattern = "(?sm)^" + [regex]::Escape($MarkerStart) + "$.*?^" + [regex]::Escape($MarkerEnd) + "$"
        # -Raw keeps the source's own trailing newline; strip it and add exactly
        # one, so the block is byte-identical to what sync.sh's awk emits
        # (start marker, source lines, end marker - one newline between each).
        $SourceBody = $SourceContent -replace '(\r?\n)+$', ''
        $NewBlock = $MarkerStart + "`n" + $SourceBody + "`n" + $MarkerEnd
        # The ScriptBlock overload makes this a MatchEvaluator, NOT a replacement
        # string: $1, $&, $$ inside the identity content are therefore left alone
        # instead of being interpreted as regex substitution tokens. Do not
        # "simplify" this to the string overload.
        $NewContent = [regex]::Replace($TargetContent, $Pattern, { $NewBlock })
        Set-Content -Path $Target -Value $NewContent -NoNewline
        Write-Host "  UPDATED (v$BlockVersion)"
        $Updated++
    } else {
        # -WhatIf: mirror sync.sh, which prints WOULD UPDATE and counts it.
        Write-Host "  WOULD UPDATE (v$BlockVersion)"
        $Updated++
    }
}

Write-Host ""
Write-Host "Summary: $Updated updated, $Skipped skipped, $Errors errors"
