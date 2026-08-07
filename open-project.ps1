# Open Grok Build with this product repo as session workspace (top-bar cwd).
# Usage: powershell -ExecutionPolicy Bypass -File G:\GrokProject\WZ_Skill\open-project.ps1
# Optional: -Prompt "continue WZ skill"  |  -InProcess (block in current terminal)

[CmdletBinding()]
param(
    [string]$Prompt = "",
    [switch]$InProcess
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = "G:\GrokProject\WZ_Skill"
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

$grok = $null
foreach ($c in @(
    (Join-Path $env:USERPROFILE ".grok\bin\grok.exe"),
    "grok"
)) {
    if ($c -eq "grok") {
        $cmd = Get-Command grok -ErrorAction SilentlyContinue
        if ($cmd) { $grok = $cmd.Source; break }
    } elseif (Test-Path -LiteralPath $c) {
        $grok = $c
        break
    }
}

if (-not $grok) {
    throw "grok.exe not found. Install Grok Build or add it to PATH."
}

Write-Host "Project : $ProjectRoot"
Write-Host "Grok    : $grok"
Write-Host "Note    : Session top-bar cwd is fixed at launch; shell cd inside an old session will not change it."

$argList = @("--cwd", $ProjectRoot)
if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
    $argList += $Prompt
}

if ($InProcess) {
    Set-Location -LiteralPath $ProjectRoot
    & $grok @argList
    exit $LASTEXITCODE
}

Start-Process -FilePath $grok -ArgumentList $argList -WorkingDirectory $ProjectRoot | Out-Null
Write-Host "Launched a new Grok session with --cwd $ProjectRoot"
Write-Host "You can close the old session that still shows the previous workspace."
