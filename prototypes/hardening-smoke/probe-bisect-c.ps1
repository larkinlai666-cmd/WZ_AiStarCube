# Bisect C: plain variable + splat array
$ErrorActionPreference = 'Continue'
$disc = 'C:\Users\Administrator\.config\wezterm\workbench\agent-discovery.ps1'
$discArgs = @('-WorkbenchDir', 'C:\Users\Administrator\.config\wezterm\workbench')
$out = @(& $disc @discArgs)
Write-Host ("C plain-var+splat count=" + $out.Count)
