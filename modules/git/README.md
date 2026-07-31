# git

Comandos git frecuentes y segmento de prompt. CLI-first; el IDE queda para reviews densas.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Invoke-DsGitStatus` | Resumen + `git status -sb` |
| `Invoke-DsGitBranch` | Fuzzy checkout de branch |
| `Get-DsGitBranch` | Branch actual |
| `Get-DsGitStatusSummary` | Objeto resumen |

## Keys

| Chord | Acción |
|-------|--------|
| `Ctrl+Shift+S` | Git status |
| `Ctrl+Shift+K` | Checkout branch (evita WT `Ctrl+Shift+V`) |

> Knowledge Engine usa `Ctrl+Alt+K` para report (no reutiliza este chord). Ver [docs/keymap.md](../../docs/keymap.md).

## Par CLI ↔ IDE

| IDE | CLI |
|-----|-----|
| Source Control | `Invoke-DsGitStatus` |
| Branch picker | `Invoke-DsGitBranch` |
