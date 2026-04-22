# Play a random MP3 from the given category. Non-blocking.
param(
    [Parameter(Mandatory)][string]$Category
)

$dir = Join-Path $env:USERPROFILE ".claude\sounds\indian\$Category"
$files = Get-ChildItem -Path $dir -Filter "*.mp3" -ErrorAction SilentlyContinue
if ($files.Count -eq 0) { exit 0 }

$file = ($files | Get-Random).FullName
Start-Process -FilePath $file -WindowStyle Hidden
