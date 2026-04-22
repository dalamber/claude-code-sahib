# claude-code-sahib uninstaller — Windows (PowerShell)
# Run with: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = "Stop"

$ClaudeDir = Join-Path $env:APPDATA "Claude"
$Settings  = Join-Path $ClaudeDir "settings.json"

Write-Host "=== claude-code-sahib uninstaller ===" -ForegroundColor Cyan

# ── Sounds & scripts ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Removing sounds and scripts..."
$soundsDir = Join-Path $ClaudeDir "sounds\indian"
Remove-Item -Recurse -Force $soundsDir -ErrorAction SilentlyContinue
Remove-Item -Force (Join-Path $ClaudeDir "sounds\play.ps1")   -ErrorAction SilentlyContinue
Remove-Item -Force (Join-Path $ClaudeDir "sounds\toggle.ps1") -ErrorAction SilentlyContinue
Write-Host "  ✓ sounds and scripts removed" -ForegroundColor Green

# ── Slash command ─────────────────────────────────────────────────────────────
Remove-Item -Force (Join-Path $ClaudeDir "commands\sahib.md") -ErrorAction SilentlyContinue
Write-Host "  ✓ /sahib slash command removed" -ForegroundColor Green

# ── Hooks ────────────────────────────────────────────────────────────────────
if (Test-Path $Settings) {
    Write-Host "Removing hooks from $Settings..."
    $cfg = Get-Content $Settings -Raw | ConvertFrom-Json

    if ($cfg.hooks) {
        $events = $cfg.hooks.PSObject.Properties.Name
        foreach ($event in $events) {
            $cfg.hooks.$event = @(
                $cfg.hooks.$event | Where-Object {
                    $_.hooks -notmatch "play\.ps1"
                }
            )
            if ($cfg.hooks.$event.Count -eq 0) {
                $cfg.hooks.PSObject.Properties.Remove($event)
            }
        }
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $Settings -Encoding UTF8
        Write-Host "  ✓ sahib hooks removed" -ForegroundColor Green
    }
}

# ── PowerShell profile ────────────────────────────────────────────────────────
$profilePath = $PROFILE.CurrentUserAllHosts
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath
    $filtered = $content | Where-Object {
        $_ -notmatch "claude-code-sahib toggle" -and $_ -notmatch "toggle\.ps1"
    }
    $filtered | Set-Content $profilePath -Encoding UTF8
    Write-Host "  ✓ sahib function removed from PowerShell profile" -ForegroundColor Green
}

Write-Host ""
Write-Host "Uninstalled. Restart Claude Code to apply hook changes." -ForegroundColor Cyan
