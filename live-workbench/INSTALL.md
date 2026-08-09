# Live workbench snapshot (install)

This directory is a **point-in-time snapshot** of the AI STAR CUBE WezTerm config
as developed for WZ_AiStarCube / WZ-AiWorkBench.

## Install (Windows)

1. Install [WezTerm](https://wezfurlong.org/wezterm/) and Grok Build CLI.
2. Backup any existing config, then copy:

```powershell
$src = "path\to\this\repo\live-workbench"
$dst = Join-Path $env:USERPROFILE ".config\wezterm"
New-Item -ItemType Directory -Force -Path (Join-Path $dst "workbench") | Out-Null
Copy-Item "$src\wezterm.lua" $dst -Force
Copy-Item "$src\workbench\*" (Join-Path $dst "workbench") -Recurse -Force
# optional bindings
Copy-Item "$src\workbench\desk-roots.example.tsv" (Join-Path $dst "workbench\desk-roots.tsv")
Copy-Item "$src\workbench\favorites.example.txt" (Join-Path $dst "workbench\favorites.txt")
```

3. Reload WezTerm config (Leader `Alt+;` then `'` or restart).
4. Open Init panel → select/create a **real project** (never home/Desktop as TASK).
5. Grok sessions must use `--cwd <project path>` (Init / F9+F6 / open-project.ps1).

## Not included

- Your private `desk-roots.tsv` / machine absolute paths
- Session transcripts under `~/.grok/sessions`