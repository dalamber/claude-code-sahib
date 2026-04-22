# claude-code-sahib setup - Windows (PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File setup.ps1 [-Uninstall]
#
# Claude Code on Windows reads config from %USERPROFILE%\.claude
# (same as ~/.claude on macOS/Linux).

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$Repo      = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$Sounds    = Join-Path $ClaudeDir "sounds\active"
$Settings  = Join-Path $ClaudeDir "settings.json"
$PlayPs1   = Join-Path $ClaudeDir "sounds\play.ps1"
$TogglePs1 = Join-Path $ClaudeDir "sounds\toggle.ps1"

# --- Install ----------------------------------------------------------------
function Invoke-Install {
    Write-Host "=== claude-code-sahib: install ===" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Copying sounds -> $Sounds"
    New-Item -ItemType Directory -Force -Path $Sounds | Out-Null
    Copy-Item -Recurse -Force "$Repo\characters\sahib\en\sounds\*" $Sounds
    $count = (Get-ChildItem $Sounds -Recurse -Filter "*.mp3").Count
    Write-Host "  [ok] $count MP3 files" -ForegroundColor Green

    Write-Host "Installing scripts -> $(Split-Path $PlayPs1 -Parent)"
    Copy-Item -Force "$Repo\scripts\play.ps1"   $PlayPs1
    Copy-Item -Force "$Repo\scripts\toggle.ps1" $TogglePs1
    Write-Host "  [ok] play.ps1, toggle.ps1" -ForegroundColor Green

    Write-Host "Wiring Claude Code hooks -> $Settings"
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    if (-not (Test-Path $Settings)) { '{}' | Set-Content $Settings -Encoding UTF8 }

    try {
        $raw = Get-Content $Settings -Raw
        $cfg = if ([string]::IsNullOrWhiteSpace($raw)) { [PSCustomObject]@{} } else { $raw | ConvertFrom-Json }
    } catch {
        Write-Host "  ! settings.json is not valid JSON, starting fresh" -ForegroundColor Yellow
        $cfg = [PSCustomObject]@{}
    }
    if (-not $cfg.hooks) {
        $cfg | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
    }

    function Add-SahibHook([string]$Event, [string]$Command) {
        $existing = $cfg.hooks.$Event
        if ($existing) {
            $already = $existing | ForEach-Object { $_.hooks } |
                Where-Object { $_.command -like "*play.ps1*" }
            if ($already) { Write-Host "  ~ $Event already wired, skipping"; return }
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

    $ps = "powershell -NoProfile -WindowStyle Hidden -File `"$PlayPs1`""

    Add-SahibHook "SessionStart"     "$ps start"
    Add-SahibHook "UserPromptSubmit" "$ps acknowledge"
    # -Chance 3 = 1-in-3 throttle, matching setup.sh's RANDOM % 3 gate.
    Add-SahibHook "PreToolUse"       "$ps working -Chance 3"
    Add-SahibHook "Stop"             "$ps done"
    Add-SahibHook "Notification"     "$ps waiting"

    $cfg | ConvertTo-Json -Depth 10 | Set-Content $Settings -Encoding UTF8

    $CommandsDir = Join-Path $ClaudeDir "commands"
    New-Item -ItemType Directory -Force -Path $CommandsDir | Out-Null
    $sahibCmd = @"
Toggle Indian voice hooks on or off.

!powershell -ExecutionPolicy Bypass -File "$TogglePs1" `$ARGUMENTS
"@
    Set-Content -Path (Join-Path $CommandsDir "sahib.md") -Value $sahibCmd -Encoding UTF8
    Write-Host "  + /sahib slash command" -ForegroundColor Green

    $profilePath = $PROFILE.CurrentUserAllHosts
    $aliasLine   = 'function sahib { & "' + $TogglePs1 + '" @args }'
    if (-not (Test-Path $profilePath)) { New-Item -Force -Path $profilePath | Out-Null }
    if (Select-String -Path $profilePath -Pattern "toggle.ps1" -Quiet) {
        Write-Host "  ~ sahib function already in profile, skipping"
    } else {
        Add-Content $profilePath "`n# claude-code-sahib toggle`n$aliasLine"
        Write-Host "  + sahib function -> $profilePath" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "All done, sir. Restart Claude Code to hear Aditya." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  sahib / sahib on / sahib off   - toggle the voice"
    Write-Host "  /sahib                         - same from inside Claude Code"
}

# --- Uninstall --------------------------------------------------------------
function Invoke-Uninstall {
    Write-Host "=== claude-code-sahib: uninstall ===" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Removing sounds and scripts..."
    Remove-Item -Recurse -Force $Sounds     -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force (Join-Path $ClaudeDir "sounds\indian") -ErrorAction SilentlyContinue
    Remove-Item -Force $PlayPs1             -ErrorAction SilentlyContinue
    Remove-Item -Force $TogglePs1           -ErrorAction SilentlyContinue
    Write-Host "  [ok] sounds and scripts removed" -ForegroundColor Green

    Remove-Item -Force (Join-Path $ClaudeDir "commands\sahib.md") -ErrorAction SilentlyContinue
    Write-Host "  [ok] /sahib slash command removed" -ForegroundColor Green

    if (Test-Path $Settings) {
        Write-Host "Removing hooks from $Settings..."
        try {
            $raw = Get-Content $Settings -Raw
            $cfg = if ([string]::IsNullOrWhiteSpace($raw)) { [PSCustomObject]@{} } else { $raw | ConvertFrom-Json }
        } catch {
            Write-Host "  ! settings.json is not valid JSON, skipping hook cleanup" -ForegroundColor Yellow
            $cfg = $null
        }
        if ($cfg -and $cfg.hooks) {
            # Rebuild hooks from scratch to avoid the fragile `$cfg.hooks.$name = ...`
            # assignment pattern that errors on some PS 5.1 configurations.
            $newHooks = [PSCustomObject]@{}
            foreach ($prop in $cfg.hooks.PSObject.Properties) {
                $filtered = @($prop.Value | Where-Object {
                    -not ($_.hooks | Where-Object { $_.command -like "*play.ps1*" })
                })
                if ($filtered.Count -gt 0) {
                    $newHooks | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $filtered
                }
            }
            $cfg.hooks = $newHooks
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $Settings -Encoding UTF8
            Write-Host "  [ok] sahib hooks removed" -ForegroundColor Green
        }
    }

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) {
        $content  = Get-Content $profilePath
        $filtered = $content | Where-Object {
            $_ -notmatch "claude-code-sahib toggle" -and $_ -notmatch "toggle\.ps1"
        }
        $filtered | Set-Content $profilePath -Encoding UTF8
        Write-Host "  [ok] sahib function removed from PowerShell profile" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Uninstalled. Restart Claude Code to apply hook changes." -ForegroundColor Cyan
}

# --- Entry point ------------------------------------------------------------
if ($Uninstall) { Invoke-Uninstall } else { Invoke-Install }
