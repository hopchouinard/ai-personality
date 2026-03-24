[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# -------------------------------------------------------------------
# Configuration: adapter filenames and their target paths.
# Paths starting with a drive letter are absolute (global targets).
# All other paths resolve relative to -ProjectRoot.
# Edit these once per machine if your paths differ from the defaults.
# -------------------------------------------------------------------
$AdapterNames = @(
    "claude-code.md"
    "gemini-cli.md"
    "codex.md"
    "copilot.md"
)

$AdapterTargets = @(
    (Join-Path $HOME ".claude" "CLAUDE.md")
    "GEMINI.md"
    "AGENTS.md"
    (Join-Path ".github" "copilot-instructions.md")
)

$MarkerStart = "<!-- AI-PERSONALITY-START -->"
$MarkerEnd   = "<!-- AI-PERSONALITY-END -->"

# Read version from personality.md
$PersonalityFile = Join-Path $ScriptDir "personality.md"
if (-not (Test-Path $PersonalityFile)) {
    Write-Error "personality.md not found at $PersonalityFile"
    exit 1
}

$VersionLine = Get-Content $PersonalityFile | Where-Object { $_ -match "^version:" } | Select-Object -First 1
if ($VersionLine -match "^version:\s*(.+)$") {
    $Version = $Matches[1].Trim()
} else {
    Write-Error "Could not parse version from personality.md"
    exit 1
}

Write-Host "AI Personality Sync v$Version"
Write-Host "Project root: $ProjectRoot"
if ($WhatIfPreference) {
    Write-Host "Mode: DRY RUN (no files will be modified)"
}
Write-Host ""

$Updated = 0
$Skipped = 0
$Errors  = 0

for ($i = 0; $i -lt $AdapterNames.Count; $i++) {
    $Adapter = $AdapterNames[$i]
    $AdapterFile = Join-Path $ScriptDir "adapters" $Adapter
    $Target = $AdapterTargets[$i]

    # Resolve relative paths against project root
    if (-not [System.IO.Path]::IsPathRooted($Target)) {
        $Target = Join-Path $ProjectRoot $Target
    }

    Write-Host "--- $Adapter -> $Target"

    # Check adapter file exists
    if (-not (Test-Path $AdapterFile)) {
        Write-Host "  SKIP: Adapter file not found: $AdapterFile"
        $Skipped++
        continue
    }

    # Check target file exists
    if (-not (Test-Path $Target)) {
        Write-Host "  SKIP: Target file not found: $Target"
        $Skipped++
        continue
    }

    # Read target content
    $TargetContent = Get-Content $Target -Raw

    # Check markers exist
    if ($TargetContent -notmatch [regex]::Escape($MarkerStart) -or
        $TargetContent -notmatch [regex]::Escape($MarkerEnd)) {
        Write-Host "  SKIP: Markers not found in target file"
        $Skipped++
        continue
    }

    # Read adapter content
    $AdapterContent = Get-Content $AdapterFile -Raw

    if ($PSCmdlet.ShouldProcess($Target, "Update personality content (v$Version)")) {
        # Replace everything between markers (inclusive)
        # Use (?s) so .* spans newlines; match evaluator avoids $ interpretation issues
        $Pattern = "(?s)" + [regex]::Escape($MarkerStart) + ".*?" + [regex]::Escape($MarkerEnd)
        $NewBlock = $MarkerStart + "`n" + $AdapterContent + "`n" + $MarkerEnd
        $NewContent = [regex]::Replace($TargetContent, $Pattern, { $NewBlock })
        Set-Content -Path $Target -Value $NewContent -NoNewline
        Write-Host "  UPDATED (v$Version)"
        $Updated++
    }
}

Write-Host ""
Write-Host "Summary: $Updated updated, $Skipped skipped, $Errors errors"
