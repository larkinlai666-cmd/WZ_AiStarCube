# Minimal reproduction of nested-spawn discovery failure.
$wb = 'C:\Users\Administrator\.config\wezterm\workbench'
$cache = 'C:\Users\Administrator\AppData\Local\WZ_AiStarCube\agent-inventory.json'
if (Test-Path $cache) { Remove-Item $cache -Force }

# 1) in-process discovery in THIS (bash-spawned) PS
$inProc = @(& (Join-Path $wb 'agent-discovery.ps1') -WorkbenchDir $wb)
Write-Host ("in-process discovery: " + $inProc.Count)
if (Test-Path $cache) {
  $j = Get-Content -Raw $cache | ConvertFrom-Json
  Write-Host ("cache saved by in-process run: agents=" + @($j.agents).Count)
} else { Write-Host 'cache NOT saved by in-process run' }

# 2) nested Start-Process discovery (same env as e2e child)
$outF = Join-Path $env:TEMP 'wz-nested-disc.txt'
if (Test-Path $outF) { Remove-Item $outF -Force }
$p = Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
  -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $wb 'agent-discovery.ps1'),'-WorkbenchDir',$wb,'-AsTsv') `
  -RedirectStandardOutput $outF -WindowStyle Hidden -Wait -PassThru
Write-Host ("nested discovery exit=" + $p.ExitCode)
Get-Content $outF | ForEach-Object { Write-Host ("  nested row: " + $_) }
