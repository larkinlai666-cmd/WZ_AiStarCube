# Exact replica of bootstrap's Get-AgentDefinitions call, error visible.
$ErrorActionPreference = 'Continue'
$script:WzForceDiscovery = $false
$script:AgentDiscoveryFile = Join-Path 'C:\Users\Administrator\.config\wezterm\workbench' 'agent-discovery.ps1'
$PSSimRoot = 'C:\Users\Administrator\.config\wezterm\workbench'

$out = @()
if (Test-Path -LiteralPath $script:AgentDiscoveryFile -PathType Leaf) {
  $discArgs = @('-WorkbenchDir', $PSSimRoot)
  if ($script:WzForceDiscovery) { $discArgs += '-Refresh'; $script:WzForceDiscovery = $false }
  try { $out = @(& $script:AgentDiscoveryFile @discArgs) } catch {
    Write-Host ("THREW: " + $_.Exception.Message)
    Write-Host ("AT: " + $_.InvocationInfo.PositionMessage)
  }
}
Write-Host ("count=" + $out.Count)
$rows = @($out | Where-Object { $_.Id -and $_.Exe })
Write-Host ("filtered=" + $rows.Count)
