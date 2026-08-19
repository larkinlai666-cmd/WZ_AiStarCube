# Stage-by-stage dissection of agent-discovery full scan.
$ErrorActionPreference = 'Continue'
$src = Get-Content -Raw 'C:\Users\Administrator\.config\wezterm\workbench\agent-discovery.ps1'
# strip the auto-run tail (from "$cachedAgents = Read-WzInventoryCache" to EOF)
$cut = $src.IndexOf('$cachedAgents = Read-WzInventoryCache')
if ($cut -lt 0) { throw 'auto-run marker not found' }
$lib = $src.Substring(0, $cut)
Invoke-Expression $lib   # defines functions, params default ($Refresh=$false etc.)

# neutralize inventory cache so we always exercise the full scan
function Read-WzInventoryCache { return $null }
function Save-WzInventoryCache { param([object[]]$Agents) }

Write-Host "--- full scan start ---"
$Error.Clear()
$agents = @(Get-WzInstalledAgents -Root 'C:\Users\Administrator\.config\wezterm\workbench')
Write-Host ("found=" + $agents.Count)
foreach ($a in $agents) { Write-Host ("  {0}  {1}  [{2}]" -f $a.Id, $a.Exe, $a.Source) }
Write-Host "--- $Error stream (top 6) ---"
$Error[0..([Math]::Min(5, $Error.Count - 1))] | ForEach-Object { Write-Host ("ERR: " + $_.Exception.Message) }
Write-Host ("binary bytes scanned: " + $script:WzBinaryBytesScanned)
Write-Host ("path dirs: " + $script:WzSearchPathDirectories.Count)
$script:WzSearchPathDirectories | ForEach-Object { Write-Host ("  dir: " + $_) }
