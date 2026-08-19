# Bisect A: plain variable, with try/catch
$ErrorActionPreference = 'Continue'
$disc = 'C:\Users\Administrator\.config\wezterm\workbench\agent-discovery.ps1'
$root = 'C:\Users\Administrator\.config\wezterm\workbench'
$out = @()
try { $out = @(& $disc -WorkbenchDir $root) } catch { Write-Host ("THREW: " + $_.Exception.Message) }
Write-Host ("A plain-var+try count=" + $out.Count)
