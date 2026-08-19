# Bisect B: $script: variable + splat, NO try/catch
$ErrorActionPreference = 'Continue'
$script:WzForceDiscovery = $false
$script:AgentDiscoveryFile = 'C:\Users\Administrator\.config\wezterm\workbench\agent-discovery.ps1'
$discArgs = @('-WorkbenchDir', 'C:\Users\Administrator\.config\wezterm\workbench')
$out = @(& $script:AgentDiscoveryFile @discArgs)
Write-Host ("B script-var+splat count=" + $out.Count)
