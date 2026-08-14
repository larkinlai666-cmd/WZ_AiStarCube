# Strict pane-id regex sanity for Set-SpawnedTabTitle (D-011)
$cases = @(
  @{ Name = 'single-line "7\r\n"'; Out = "7`r`n"; Expect = $true; Want = '7' },
  @{ Name = 'padded "  12  "';     Out = '  12  ';  Expect = $true; Want = '12' },
  @{ Name = 'multi-line "7\r\n8"'; Out = "7`r`n8`r`n"; Expect = $false },
  @{ Name = 'warn+id';             Out = "WARN code 3`r`n7`r`n"; Expect = $false },
  @{ Name = 'empty';               Out = ''; Expect = $false }
)
$fail = 0
foreach ($c in $cases) {
  $paneId = $null
  if ($c.Out) {
    $m = [regex]::Match($c.Out.Trim(), '^(\d+)$')
    if ($m.Success) { $paneId = $m.Groups[1].Value }
  }
  $got = [bool]$paneId
  $ok = ($got -eq $c.Expect) -and (-not $got -or $paneId -eq $c.Want)
  if (-not $ok) { $fail++ }
  Write-Host ("{0,-24} expect={1} got={2} pane={3} => {4}" -f $c.Name, $c.Expect, $got, $(if ($paneId) { $paneId } else { '-' }), $(if ($ok) { 'PASS' } else { 'FAIL' }))
}
if ($fail -gt 0) { exit 1 }
Write-Host 'ALL PASS'
