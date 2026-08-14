# Environment

## Toolchain Manifest

- Required: git
- Optional: gh,rg,node,python
- Dependency manifests: none
- Package manager: auto
- Install policy: project-local-first

## Project Commands

- Setup: none
- Environment verify: none
- Verify: powershell -ExecutionPolicy Bypass -File scripts/validate_project.ps1; powershell -ExecutionPolicy Bypass -File scripts/wezterm_load_guard.ps1
- Preview: none

## Environment Rules

- Run `scripts/environment_doctor.*` before installing anything.
- Prefer project-local dependencies and lockfiles.
- System installation requires explicit `--apply --yes` or `-Apply -Yes`.
- Never use `curl | shell`, install global language packages, or start a daemon as an implicit bootstrap step.
