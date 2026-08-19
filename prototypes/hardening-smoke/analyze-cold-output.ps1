$l = Get-Content -LiteralPath 'C:\Users\Administrator\AppData\Local\Temp\wz-init-e2e-cold.txt'
Write-Host ('lines=' + $l.Count + '  WZ_INIT=' + @($l -match 'WZ INIT').Count + '  Agy=' + @($l -match 'Agy').Count + '  empty=' + @($l -match 'no self-described').Count)
$err = Get-Content -LiteralPath 'C:\Users\Administrator\AppData\Local\Temp\wz-init-e2e-cold.txt.err' -ErrorAction SilentlyContinue
Write-Host ('stderr lines=' + @($err).Count)
$err | Select-Object -First 6
Write-Host '--- stdout tail ---'
$l | Select-Object -Last 5
