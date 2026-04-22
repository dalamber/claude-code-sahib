param(
    [Parameter(Mandatory)][string]$Category,
    [int]$Chance = 1
)

# Throttle: when -Chance N > 1, only play 1 out of N invocations.
if ($Chance -gt 1 -and (Get-Random -Maximum $Chance) -ne 0) { exit 0 }

$flag = Join-Path $env:USERPROFILE ".claude\sounds\active\.disabled"
if (Test-Path $flag) { exit 0 }

$dir = Join-Path $env:USERPROFILE ".claude\sounds\active\$Category"
$files = Get-ChildItem -Path $dir -Filter "*.mp3" -ErrorAction SilentlyContinue
if ($files.Count -eq 0) { exit 0 }

$file = ($files | Get-Random).FullName

# Spawn a detached hidden PowerShell that plays the clip and exits. The parent
# script returns immediately so Claude Code's hook dispatch is never blocked by
# audio playback.
$inner = @"
Add-Type -AssemblyName presentationCore
`$p = New-Object System.Windows.Media.MediaPlayer
`$p.Open([Uri]::new('$($file -replace "'", "''")'))
`$deadline = (Get-Date).AddSeconds(2)
while (-not `$p.NaturalDuration.HasTimeSpan -and (Get-Date) -lt `$deadline) {
    Start-Sleep -Milliseconds 20
}
`$p.Play()
if (`$p.NaturalDuration.HasTimeSpan) {
    Start-Sleep -Milliseconds ([int]`$p.NaturalDuration.TimeSpan.TotalMilliseconds + 100)
} else {
    Start-Sleep -Seconds 5
}
`$p.Stop()
`$p.Close()
"@

$bytes = [System.Text.Encoding]::Unicode.GetBytes($inner)
$encoded = [Convert]::ToBase64String($bytes)

Start-Process -WindowStyle Hidden -FilePath "powershell" -ArgumentList @(
    "-NoProfile",
    "-NonInteractive",
    "-EncodedCommand",
    $encoded
) | Out-Null
