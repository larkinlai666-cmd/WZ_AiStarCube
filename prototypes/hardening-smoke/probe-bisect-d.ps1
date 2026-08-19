# Bisect D: $script: variable, inline args (no splat)
$ErrorActionPreference = 'Continue'
$script:AgentDiscoveryFile = 'C:\Users\Administrator\.config\wezterm\workbench\agent-discovery.ps1'
$out = @(& $script:AgentDiscoveryFile -WorkbenchDir 'C:\Users\Administrator\.config\wezterm\workbench')
Write-Host ("D script-var inline count=" + $out.Count)
