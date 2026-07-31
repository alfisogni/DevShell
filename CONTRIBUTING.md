# Contributing to DevShell

Thanks for helping. Keep changes small and easy to review.

## Quick start for contributors

1. Fork / clone the repo.
2. Use **PowerShell 7** (`pwsh`).
3. From the repo root: `.\init.ps1` or `Import-Module .\DevShell.psd1; Start-DevShell -Quiet -SkipBanner`
4. Run tests: `.\scripts\Invoke-DevShellTests.ps1`

## Add a module

1. Copy `modules/_template/` → `modules/<name>/` (or run `.\scripts\New-DevShellModule.ps1 -Name <name>`).
2. Fill in `module.json` (`name`, `dependsOn`, `provides`, `hooks`).
3. Implement the `.psm1` with public `*-Ds*` commands.
4. Document in the module README: commands, keys, and CLI↔IDE pair if it replaces an IDE habit.
5. Add module defaults in that folder’s `config.psd1`; enable in `config/modules.psd1` when it should ship on.
6. Prefer Pester tests under `tests/modules/`.

## Replace a module

Disable the original in `config/modules.psd1`, drop in another folder that meets the same contract, and leave `core/` alone.

## Conventions

- Public identifiers in English; docs may be Spanish or English.
- Prefix: `Ds` / `DevShell`.
- Register keys only via `Register-DsKey` (core).
- Don’t call other feature modules directly — use core APIs / events / hooks.
- Fail soft: a broken module must not crash shell startup.

## Pull requests

- **Do not push straight to `main`.** Open a branch + pull request (the repo may reject direct pushes).
- One concern per PR (one module, one bugfix, or one docs pass).
- Don’t mix core refactors with three new features.
- Update the module README / `docs/` when behavior changes.
- Never commit `config/user.psd1`, secrets, tokens, or machine-specific paths with credentials.
- See [docs/privacy.md](docs/privacy.md) for what DevShell does (and does not) send off-machine.

## Local config (do not publish)

`config/user.psd1` is gitignored. Copy from `config/user.psd1.example`. Keep API paths, notes, and personal roots only there.
