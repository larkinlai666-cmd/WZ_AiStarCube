# M-5 verification: does Register-ObjectEvent -Action share $global with the
# main session? sidebar.ps1 auto-refresh depends on it. Run under PS 5.1.
# Exit 0 = flag visible (mechanism works); 1 = silently dead (needs Get-Event).
$ErrorActionPreference = 'Stop'

$global:WzTestFsDirty = $false
$dir = Join-Path $env:TEMP ('wzfs_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir -Force | Out-Null

$w = New-Object System.IO.FileSystemWatcher
$w.Path = $dir
$w.IncludeSubdirectories = $false
$w.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$w.EnableRaisingEvents = $true
$sid = 'wzTestFs_' + [guid]::NewGuid().ToString('N')
foreach ($ev in @('Created', 'Changed', 'Deleted', 'Renamed')) {
  Register-ObjectEvent -InputObject $w -EventName $ev -SourceIdentifier ($sid + '_' + $ev) -Action {
    $global:WzTestFsDirty = $true
  } | Out-Null
}
$global:WzTestFsDirty = $false

New-Item -ItemType File -Path (Join-Path $dir 'x.txt') -Force | Out-Null
$deadline = (Get-Date).AddSeconds(3)
$fired = $false
while ((Get-Date) -lt $deadline) {
  if ($global:WzTestFsDirty) { $fired = $true; break }
  Start-Sleep -Milliseconds 100
}

foreach ($ev in @('Created', 'Changed', 'Deleted', 'Renamed')) {
  Unregister-Event -SourceIdentifier ($sid + '_' + $ev) -ErrorAction SilentlyContinue
}
$w.EnableRaisingEvents = $false
$w.Dispose()
Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue

if ($fired) {
  Write-Host 'M5-RESULT: GLOBAL-VISIBLE — sidebar auto-refresh mechanism works, no fix needed'
  exit 0
}
Write-Host 'M5-RESULT: GLOBAL-NOT-VISIBLE — auto-refresh silently dead, switch to Get-Event polling'
exit 1
