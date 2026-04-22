# claude-code-sahib setup - Windows (PowerShell)
# Installs a character's sounds, spinnerVerbs, and Claude Code hooks.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File setup.ps1
#   powershell -ExecutionPolicy Bypass -File setup.ps1 -Character butler -Language en
#   powershell -ExecutionPolicy Bypass -File setup.ps1 -Character gopnik -Language ru
#   powershell -ExecutionPolicy Bypass -File setup.ps1 -Uninstall

param(
    [string]$Character = "",
    [string]$Language  = "",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$Repo      = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$Sounds    = Join-Path $ClaudeDir "sounds\active"
$Settings  = Join-Path $ClaudeDir "settings.json"
$PlayPs1   = Join-Path $ClaudeDir "sounds\play.ps1"
$TogglePs1 = Join-Path $ClaudeDir "sounds\toggle.ps1"

function Read-Settings {
    if (-not (Test-Path $Settings)) { return [PSCustomObject]@{} }
    $raw = Get-Content $Settings -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return [PSCustomObject]@{} }
    try { return $raw | ConvertFrom-Json } catch {
        Write-Host "  ! settings.json is not valid JSON, starting fresh" -ForegroundColor Yellow
        return [PSCustomObject]@{}
    }
}

function Write-Settings($cfg) {
    $cfg | ConvertTo-Json -Depth 20 | Set-Content $Settings -Encoding UTF8
}

function Select-Character {
    Write-Host ""
    Write-Host "What would you like to do?"
    $dirs = Get-ChildItem (Join-Path $Repo "characters") -Directory | Sort-Object Name
    $items = @()
    for ($i = 0; $i -lt $dirs.Count; $i++) {
        $cj = Get-Content (Join-Path $dirs[$i].FullName "character.json") -Raw | ConvertFrom-Json
        $name = ($cj.name.PSObject.Properties | Select-Object -First 1).Value
        $langs = ($cj.languages -join ", ")
        $marker = if ($cj.content_warning) { " [!]" } else { "" }
        "{0,2}. Install {1,-12} {2} [{3}]{4}" -f ($i+1), $dirs[$i].Name, $name, $langs, $marker | Write-Host
        $items += $dirs[$i].Name
    }
    $uninstallIdx = $items.Count + 1
    "{0,2}. Uninstall" -f $uninstallIdx | Write-Host
    while ($true) {
        $raw = Read-Host "Select [1-$uninstallIdx]"
        if ($raw -match '^\d+$') {
            $n = [int]$raw
            if ($n -eq $uninstallIdx) { return "__uninstall__" }
            if ($n -ge 1 -and $n -le $items.Count) { return $items[$n - 1] }
        }
    }
}

function Select-Language($char) {
    if ($char.languages.Count -eq 1) { return $char.languages[0] }
    Write-Host ""
    Write-Host "Available languages for $($Character):"
    for ($i = 0; $i -lt $char.languages.Count; $i++) {
        "  {0}. {1}" -f ($i+1), $char.languages[$i] | Write-Host
    }
    while ($true) {
        $raw = Read-Host "Select language [1-$($char.languages.Count)]"
        if ($raw -match '^\d+$' -and [int]$raw -ge 1 -and [int]$raw -le $char.languages.Count) {
            return $char.languages[[int]$raw - 1]
        }
    }
}

function Invoke-Install {
    if ([string]::IsNullOrEmpty($Character)) {
        $script:Character = Select-Character
        if ($Character -eq "__uninstall__") {
            Invoke-Uninstall
            return
        }
    }
    $charJson = Join-Path $Repo "characters\$Character\character.json"
    if (-not (Test-Path $charJson)) {
        Write-Host "ERROR: unknown character '$Character'. Available:" -ForegroundColor Red
        Get-ChildItem (Join-Path $Repo "characters") -Directory | ForEach-Object { "  $($_.Name)" }
        exit 1
    }
    $char = Get-Content $charJson -Raw | ConvertFrom-Json

    if ([string]::IsNullOrEmpty($Language)) {
        $script:Language = Select-Language $char
    }
    $langDir = Join-Path $Repo "characters\$Character\$Language"
    if (-not (Test-Path $langDir)) {
        Write-Host "ERROR: language '$Language' not available for '$Character'. Have:" -ForegroundColor Red
        $char.languages | ForEach-Object { "  $_" }
        exit 1
    }

    if ($char.content_warning) {
        Write-Host ""
        Write-Host "CONTENT WARNING: $($char.content_warning)" -ForegroundColor Yellow
        $ans = Read-Host "Proceed? [y/N]"
        if ($ans -notmatch "^[Yy]") { Write-Host "Aborted."; exit 0 }
    }

    Write-Host "=== claude-code-sahib: install $Character ($Language) ===" -ForegroundColor Cyan

    # --- Sounds ---
    Write-Host ""
    Write-Host "Copying sounds -> $Sounds"
    if (Test-Path $Sounds) { Remove-Item -Recurse -Force $Sounds }
    New-Item -ItemType Directory -Force -Path $Sounds | Out-Null
    $srcSounds = Join-Path $langDir "sounds"
    if (Test-Path $srcSounds) {
        Copy-Item -Recurse -Force "$srcSounds\*" $Sounds
        Get-ChildItem -Path $Sounds -Recurse -Filter ".gitkeep" -Force | Remove-Item -Force
    }
    $count = (Get-ChildItem $Sounds -Recurse -Filter "*.mp3" -ErrorAction SilentlyContinue).Count
    Write-Host "  [ok] $count MP3 files" -ForegroundColor Green
    if ($count -eq 0) {
        Write-Host "  ! No MP3s for $Character/$Language. Generate with:" -ForegroundColor Yellow
        Write-Host "    python scripts\generate_elevenlabs.py --character $Character --language $Language"
    }

    Write-Host "Installing scripts -> $(Split-Path $PlayPs1 -Parent)"
    Copy-Item -Force "$Repo\scripts\play.ps1"   $PlayPs1
    Copy-Item -Force "$Repo\scripts\toggle.ps1" $TogglePs1
    Write-Host "  [ok] play.ps1, toggle.ps1" -ForegroundColor Green

    # --- Settings: backup, spinnerVerbs, hooks ---
    Write-Host "Wiring settings -> $Settings"
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    if (-not (Test-Path $Settings)) { '{}' | Set-Content $Settings -Encoding UTF8 }
    $backup = "$Settings.backup.$([int][double]::Parse((Get-Date -UFormat %s)))"
    Copy-Item -Force $Settings $backup
    Write-Host "  [ok] backup -> $backup"

    $cfg = Read-Settings

    $verbsJson = Join-Path $langDir "spinner-verbs.json"
    if (Test-Path $verbsJson) {
        $verbs = (Get-Content $verbsJson -Raw | ConvertFrom-Json).spinnerVerbs
        if ($cfg.PSObject.Properties.Match("spinnerVerbs").Count -gt 0) {
            $cfg.spinnerVerbs = $verbs
        } else {
            $cfg | Add-Member -NotePropertyName spinnerVerbs -NotePropertyValue $verbs
        }
        Write-Host "  [ok] spinnerVerbs" -ForegroundColor Green
    }

    if (-not $cfg.hooks) {
        $cfg | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
    }

    function Add-VoiceHook([string]$Event, [string]$Command) {
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
    Add-VoiceHook "SessionStart"     "$ps start"
    Add-VoiceHook "UserPromptSubmit" "$ps acknowledge"
    Add-VoiceHook "PreToolUse"       "$ps working -Chance 3"
    Add-VoiceHook "Stop"             "$ps done"
    Add-VoiceHook "Notification"     "$ps waiting"

    Write-Settings $cfg

    $CommandsDir = Join-Path $ClaudeDir "commands"
    New-Item -ItemType Directory -Force -Path $CommandsDir | Out-Null
    $sahibCmd = @"
Toggle voice hooks on or off.

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
    Write-Host "Installed $Character ($Language). Restart Claude Code to apply." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  sahib / sahib on / sahib off   - toggle the voice"
    Write-Host "  /sahib                         - same from inside Claude Code"
}

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
        Write-Host "Removing hooks and spinnerVerbs from $Settings..."
        $cfg = Read-Settings
        if ($cfg -and $cfg.hooks) {
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
        }
        if ($cfg -and $cfg.PSObject.Properties.Match("spinnerVerbs")) {
            $cfg.PSObject.Properties.Remove("spinnerVerbs")
        }
        Write-Settings $cfg
        Write-Host "  [ok] hooks and spinnerVerbs removed" -ForegroundColor Green
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
    Write-Host "Uninstalled. Restart Claude Code." -ForegroundColor Cyan
}

if ($Uninstall) { Invoke-Uninstall } else { Invoke-Install }
