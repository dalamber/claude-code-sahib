# Usage: toggle.ps1 [on|off]   (no args = toggle)
param([string]$Action = "")

$flag = Join-Path $env:USERPROFILE ".claude\sounds\active\.disabled"

$resolved = if ($Action -ne "") { $Action } `
            elseif (Test-Path $flag) { "on" } `
            else { "off" }

switch ($resolved) {
    "on"  { Remove-Item -Force $flag -ErrorAction SilentlyContinue
            Write-Host "sahib: ON  - Namaste sir, I am at your service" }
    "off" { New-Item -ItemType File -Force -Path $flag | Out-Null
            Write-Host "sahib: OFF - Going silent, boss" }
    default { Write-Host "Usage: toggle.ps1 [on|off]" }
}
