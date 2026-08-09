# Live workbench install

**Prefer the repo-root installer** (handles backup, empty roots, bind clone, doctor):

```powershell
# from repository root
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1
```

## Manual install (Windows)

Only if you cannot run `Install-WZ.ps1`:

1. Install [WezTerm](https://wezfurlong.org/wezterm/) and Grok Build CLI.
2. Backup `%USERPROFILE%\.config\wezterm` if it exists.
3. Copy:

```powershell
$src = "path\to\clone\live-workbench"
$dst = Join-Path $env:USERPROFILE ".config\wezterm"
New-Item -ItemType Directory -Force -Path (Join-Path $dst "workbench") | Out-Null
Copy-Item "$src\wezterm.lua" $dst -Force
Copy-Item "$src\workbench\*.lua" (Join-Path $dst "workbench") -Force
Copy-Item "$src\workbench\*.ps1" (Join-Path $dst "workbench") -Force
Copy-Item "$src\workbench\*.txt" (Join-Path $dst "workbench") -Force
Copy-Item "$src\workbench\*.cmd" (Join-Path $dst "workbench") -Force
# Create EMPTY bindings — do NOT copy example.tsv as real desk-roots
@'
# desk roots - project_name<TAB>absolute_path
'@ | Set-Content (Join-Path $dst "workbench\desk-roots.tsv") -Encoding UTF8
```

4. Restart WezTerm.
5. Init panel → `c` create a project, or run `.\open-project.ps1` from a project folder.

## Optional env

| Variable | Meaning |
|----------|---------|
| `WZ_PROJECTS_ROOT` | Default parent folder for Init `c` wizard |

## Not portable (by design)

- Author's personal `desk-roots.tsv`
- `~\.grok\sessions` transcripts
- Non-Windows shells (PowerShell modules are the runtime)
