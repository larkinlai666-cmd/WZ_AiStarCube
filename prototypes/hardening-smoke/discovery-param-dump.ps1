#Requires -Version 5.1
<#
.SYNOPSIS
  Discover locally installed AI agent CLIs without an agent-name whitelist.

.DESCRIPTION
  Discovery is metadata-driven and never launches a candidate executable.
  Sources are live and persisted PATH, npm/Python package metadata, executable
  version/static capability metadata, *.wz-agent.json manifests, and the
  optional local TSV override. Static binary verdicts use a bounded fingerprint
  cache, so the result is safe and fast to call on every Init cold start.
#>
[CmdletBinding()]
param(
  [switch]$AsJson,
  [switch]$AsTsv,
  [string]$WorkbenchDir = $PSScriptRoot,
  [switch]$ProcessPathOnly,
  [string]$UserPathOverride,
  [switch]$Refresh
)


Write-Host ("BIND WorkbenchDir=[" + $WorkbenchDir + "]")
Write-Host ("BIND Refresh=" + $Refresh + " ProcessPathOnly=" + $ProcessPathOnly + " UserPathOverride=[" + $UserPathOverride + "] AsTsv=" + $AsTsv)
Write-Host ("BIND args=" + ($args -join ','))