param([Parameter(Mandatory)][string]$Category)

$flag = Join-Path $env:USERPROFILE ".claude\sounds\indian\.disabled"
if (Test-Path $flag) { exit 0 }

$dir = Join-Path $env:USERPROFILE ".claude\sounds\indian\$Category"
$files = Get-ChildItem -Path $dir -Filter "*.mp3" -ErrorAction SilentlyContinue
if ($files.Count -eq 0) { exit 0 }

$file = ($files | Get-Random).FullName
Start-Process -FilePath $file -WindowStyle Hidden
