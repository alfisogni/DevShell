# board

Taskbook-inspired **pinboard**: boards + tasks + notes in one surface.

## Commands

| Command | Alias | Role |
|---------|-------|------|
| `Show-DsBoard` / `Invoke-DsBoard` | `dsboard` | Pinboard view |
| `Invoke-DsTasks "…"` | `dstasks` / `dstask` | Add task or interactive |
| `Add-DsBoardNote` | `dsbnote` | Scratch note |
| `Complete-DsBoardTask -Id` | | Toggle □ / ■ |

Data: `~/.config/devshell/board/pinboard.json` (override `Board.DataPath`).

## Keys

`Ctrl+Alt+B` — interactive pinboard (gum/fzf menu).

## Par CLI ↔ IDE

| IDE | DevShell |
|-----|----------|
| Todo panel | `dsboard` |
| Quick capture | `dstask "Review PR"` |
