# Dump how discovery receives splatted vs inline args.
$src = Get-Content -Raw 'C:\Users\Administrator\.config\wezterm\workbench\agent-discovery.ps1'
$cut = $src.IndexOf('$ErrorActionPreference')
if ($cut -lt 0) { throw 'marker not found' }
$header = $src.Substring(0, $cut)   # comments + param() block only
$dump = @'

Write-Host ("BIND WorkbenchDir=[" + $WorkbenchDir + "]")
Write-Host ("BIND Refresh=" + $Refresh + " ProcessPathOnly=" + $ProcessPathOnly + " UserPathOverride=[" + $UserPathOverride + "] AsTsv=" + $AsTsv)
Write-Host ("BIND args=" + ($args -join ','))
'@
$dbg = 'G:\GrokProject\WZ_Skill\prototypes\hardening-smoke\discovery-param-dump.ps1'
[System.IO.File]::WriteAllText($dbg, $header + $dump, (New-Object System.Text.UTF8Encoding $false))

$discArgs = @('-WorkbenchDir', 'C:\Users\Administrator\.config\wezterm\workbench')
Write-Host '--- splat ---'
& $dbg @discArgs
Write-Host '--- inline ---'
& $dbg -WorkbenchDir 'C:\Users\Administrator\.config\wezterm\workbench'
