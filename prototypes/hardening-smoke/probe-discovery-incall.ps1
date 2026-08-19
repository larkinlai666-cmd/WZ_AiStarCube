# Probe: mimic bootstrap's in-process discovery call and surface any error.
$ErrorActionPreference = 'Continue'
$PSSimRoot = 'C:\Users\Administrator\.config\wezterm\workbench'
$discovery = Join-Path $PSSimRoot 'agent-discovery.ps1'

$out = @()
$err = $null
try { $out = @(& $discovery -WorkbenchDir $PSSimRoot) } catch { $err = $_ }
Write-Host ("count=" + $out.Count)
if ($err) { Write-Host ("THREW: " + $err.Exception.Message) }
foreach ($o in $out) {
  Write-Host ("row: Id={0} Exe={1}" -f $o.Id, $o.Exe)
}
# also check: does the call leave stray non-row output?
$types = $out | ForEach-Object { $_.GetType().Name } | Sort-Object -Unique
Write-Host ("types: " + ($types -join ', '))
