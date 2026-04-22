# claude-code-sahib installer — Windows (PowerShell)
# Run with: powershell -ExecutionPolicy Bypass -File install.ps1
#
# Claude Code settings path on Windows: %APPDATA%\Claude\settings.json
# If yours differs, adjust $ClaudeDir below.

$ErrorActionPreference = "Stop"

$Repo     = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:APPDATA "Claude"
$Sounds   = Join-Path $ClaudeDir "sounds\indian"
$Settings = Join-Path $ClaudeDir "settings.json"
$PlayPs1   = Join-Path $ClaudeDir "sounds\play.ps1"
$TogglePs1 = Join-Path $ClaudeDir "sounds\toggle.ps1"

Write-Host "=== claude-code-sahib installer ===" -ForegroundColor Cyan

# ── Sounds ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Copying sounds → $Sounds"
New-Item -ItemType Directory -Force -Path $Sounds | Out-Null
Copy-Item -Recurse -Force "$Repo\sounds\*" $Sounds
$count = (Get-ChildItem $Sounds -Recurse -Filter "*.mp3").Count
Write-Host "  ✓ $count MP3 files" -ForegroundColor Green

# ── play.ps1 / toggle.ps1 ────────────────────────────────────────────────────
Write-Host "Installing scripts → $(Split-Path $PlayPs1 -Parent)"
Copy-Item -Force "$Repo\scripts\play.ps1"   $PlayPs1
Copy-Item -Force "$Repo\scripts\toggle.ps1" $TogglePs1
Write-Host "  ✓ play.ps1, toggle.ps1" -ForegroundColor Green

# ── Hooks ────────────────────────────────────────────────────────────────────
Write-Host "Wiring Claude Code hooks → $Settings"

New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
if (-not (Test-Path $Settings)) {
    '{}' | Set-Content $Settings -Encoding UTF8
}

$cfg = Get-Content $Settings -Raw | ConvertFrom-Json

if (-not $cfg.hooks) {
    $cfg | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
}

function Add-Hook {
    param([string]$Event, [string]$Command)

    $existing = $cfg.hooks.$Event
    if ($existing) {
        $alreadyWired = $existing | ForEach-Object { $_.hooks } |
            Where-Object { $_.command -like "*play.ps1*" }
        if ($alreadyWired) {
            Write-Host "  ~ $Event already wired, skipping"
            return
        }
    }

    $entry = [PSCustomObject]@{
        hooks = @([PSCustomObject]@{ type = "command"; command = $Command })
    }

    if ($cfg.hooks.$Event) {
        $cfg.hooks.$Event = @($cfg.hooks.$Event) + $entry
    } else {
        $cfg.hooks | Add-Member -NotePropertyName $Event -NotePropertyValue @($entry)
    }
    Write-Host "  + $Event" -ForegroundColor Green
}

$ps = "powershell -WindowStyle Hidden -File `"$PlayPs1`""
Add-Hook "SessionStart"     "$ps start"
Add-Hook "UserPromptSubmit" "$ps acknowledge"
Add-Hook "PreToolUse"       "$ps working"
Add-Hook "Stop"             "$ps done"
Add-Hook "Notification"     "$ps waiting"

$cfg | ConvertTo-Json -Depth 10 | Set-Content $Settings -Encoding UTF8

# ── PowerShell profile alias ──────────────────────────────────────────────────
$profilePath = $PROFILE.CurrentUserAllHosts
$aliasLine   = "function sahib { & `"$TogglePs1`" @args }"
if (-not (Test-Path $profilePath)) { New-Item -Force -Path $profilePath | Out-Null }
if (Select-String -Path $profilePath -Pattern "toggle.ps1" -Quiet) {
    Write-Host "  ~ sahib function already in profile, skipping"
} else {
    Add-Content $profilePath "`n# claude-code-sahib toggle`n$aliasLine"
    Write-Host "  + sahib function → $profilePath" -ForegroundColor Green
}

Write-Host ""
Write-Host "All done, sir. Restart Claude Code to hear Aditya." -ForegroundColor Cyan
Write-Host ""
Write-Host "Toggle the voice anytime (reload your profile or open new terminal first):"
Write-Host "  sahib        # toggle on/off"
Write-Host "  sahib off    # silence"
Write-Host "  sahib on     # back in business"
