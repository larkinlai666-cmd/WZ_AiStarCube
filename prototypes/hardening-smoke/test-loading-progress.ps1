#Requires -Version 5.1
param([string]$BootstrapPath = (Join-Path $PSScriptRoot '..\..\live-workbench\workbench\bootstrap.ps1'))

$ErrorActionPreference = 'Stop'
$path = (Resolve-Path -LiteralPath $BootstrapPath).Path
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw ('FAIL: bootstrap parse errors: ' + ($errors.Message -join '; ')) }

function Get-FunctionText([string]$Name) {
  $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true) | Select-Object -First 1
  if (-not $fn) { throw "FAIL: function not found: $Name" }
  return $fn.Extent.Text
}

function Check([bool]$Condition, [string]$Name) {
  if (-not $Condition) { throw "FAIL: $Name" }
  Write-Host "PASS: $Name"
}

$build = Get-FunctionText 'Build-Rows'
$launch = Get-FunctionText 'Get-AgentLaunchArgv'
$native = Get-FunctionText 'Test-WzNativeAgentExe'
$shim = Get-FunctionText 'Get-AgentShimSpawn'

Check (([regex]::Matches($build, 'Start-LoadingPlan')).Count -eq 1) 'Build-Rows creates exactly one global progress plan'
Check ($build -match '\$loadUnits\s*=.*\+\s*2') 'global total reserves merge and publication phases'
Check ($build -match 'Read-SessionSummaries\s+-Files\s+\$grokFiles') 'session adapter receives one pre-enumerated file set'
Check ($build -match 'Read-KimiSessionSummaries\s+-WdDirs\s+\$kimiDirs') 'directory adapter receives one pre-enumerated directory set'
Check ($build -match 'Read-CodexSessionSummaries\s+-Files\s+\$codexFiles') 'bounded rollout set is reused instead of rescanned'
Check ($build.IndexOf('$script:Rows = $out') -lt $build.IndexOf("Step-LoadingPlan -Label 'ready'")) '100 percent occurs only after rows are published'
Check ($native -match 'exe\|com') 'native detector only accepts .exe/.com'
Check ($launch -match 'Test-WzNativeAgentExe' -and $launch -match 'Get-AgentShimSpawn') 'native EXE is detected; shims keep a host wrap'
Check ($launch -notmatch 'Get-AgentSplashSpawn' -and $launch -notmatch 'Get-AgentSplashScript') 'Agent launch no longer paints a cover splash'
Check ($shim -notmatch 'Start-Sleep' -and $shim -notmatch '/\\_/\\') 'shim host never sleeps and never draws a cat'

Write-Host 'ALL LOADING-PROGRESS TESTS PASSED'
