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
$splash = Get-FunctionText 'Get-AgentSplashScript'

Check (([regex]::Matches($build, 'Start-LoadingPlan')).Count -eq 1) 'Build-Rows creates exactly one global progress plan'
Check ($build -match '\$loadUnits\s*=.*\+\s*2') 'global total reserves merge and publication phases'
Check ($build -match 'Read-SessionSummaries\s+-Files\s+\$grokFiles') 'session adapter receives one pre-enumerated file set'
Check ($build -match 'Read-KimiSessionSummaries\s+-WdDirs\s+\$kimiDirs') 'directory adapter receives one pre-enumerated directory set'
Check ($build -match 'Read-CodexSessionSummaries\s+-Files\s+\$codexFiles') 'bounded rollout set is reused instead of rescanned'
Check ($build.IndexOf('$script:Rows = $out') -lt $build.IndexOf("Step-LoadingPlan -Label 'ready'")) '100 percent occurs only after rows are published'
Check ($splash -match 'indeterminate' -and $splash -match 'handing off to agent process') 'unknown Agent startup is explicitly indeterminate'
Check ($splash -notmatch "Write-Host\s+.*%" -and $splash -notmatch "'100%'" ) 'Agent startup splash emits no fake percentage'

Write-Host 'ALL LOADING-PROGRESS TESTS PASSED'
