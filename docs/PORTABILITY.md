# Portability / Adversarial Audit

**Question:** Can another user import this repo and get the **same workflow shell** as the author?

**Answer (after 2026-08-09 fix):** **Yes for the workbench shell** (keys, Init, gates, F6–F9, path freeze). **No for the author's private project list or chat history** (by design).

## One-command path (required)

```powershell
git clone https://github.com/larkinlai666-cmd/WZ_AiStarCube.git
cd WZ_AiStarCube
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1
# optional: custom parent for new projects
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -ProjectsRoot D:\MyProjects
```

Then restart WezTerm.

## Audit matrix (adversarial)

| Attack / failure mode | Before fix | After fix |
|----------------------|------------|-----------|
| No install script; manual copy drifts | **Fail** | `Install-WZ.ps1` copies + verifies modules |
| `DefaultParent = G:\GrokProject` missing drive | **Fail** | env `WZ_PROJECTS_ROOT` → `*:\GrokProject` → `Documents\GrokProjects` |
| Example desk-roots points at non-existent `G:\…` | **Fail** (fake TASK) | Install creates **empty** roots; optional bind **this clone** |
| Overwriting user desk-roots on reinstall | Risk | Install **keeps** existing desk-roots / favorites |
| Grok only at `~\.grok\bin\grok.exe` | Fragile | PATH + common locations (bootstrap + launch.lua + open-project) |
| `open-project.ps1` fallback `G:\GrokProject\WZ_Skill` | **Fail** | PSScriptRoot only |
| Personal paths in public snapshot | Risk | `.gitignore` desk-roots/favorites; examples only |
| macOS / Linux expect same PS1 | **Out of scope** | Documented Windows-first |
| Expect author's sessions / titles | Impossible | Transcripts stay in `~\.grok\sessions` |
| Leader `Alt+;` dead on CN IME | Confusion | Leader is **`Alt+z`** (keys.lua) |
| Docs say copy example as desk-roots | **Fail** | INSTALL + installer forbid that pattern |

## What “same workflow” means

| Included | Not included |
|----------|--------------|
| WezTerm config + workbench modules | Author's desk-roots project set |
| Init panel, gates R1–R6, create wizard | Historical Grok sessions |
| F6 / F7 / F8 / F9 / Leader Alt+z | PPS product tree |
| Path slot + tab project labels | Grok API keys / account |
| open-project.ps1 spawn discipline | Non-Windows hosts |

## Prerequisites (honest)

1. **Windows** + PowerShell 5.1+
2. **WezTerm** installed
3. **Grok Build CLI** on PATH or `~\.grok\bin\grok.exe` (for AI tabs; UI installs without it)
4. Network not required after clone (offline config)

## Re-verify after install

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -DoctorOnly
```

Manual smoke:

1. WezTerm opens → Init table visible  
2. Bound repo row (if install bound clone) → Enter → Grok `--cwd` = clone path  
3. `c` wizard → project under default parent → `.wz-project` written  
4. F7 Explorer root matches path slot  

## Residual gaps (accepted)

- Codex path still via shell `codex` (not hardened like Grok)
- First-run font (Segoe UI / JetBrains Mono) may fall back if missing — cosmetic
- User must **restart** WezTerm after install (cannot hot-patch a foreign config load order for first paint 100%)
