# gum

Wrappers around [Charm gum](https://github.com/charmbracelet/gum) for DevShell interactions.

## Commands

| Command | Role |
|---------|------|
| `Invoke-DsConfirm` | Yes/no |
| `Invoke-DsGumChoose` | Menu |
| `Invoke-DsInput` | Text input |
| `Invoke-DsSpin` | Progress spinner |
| `Test-DsGumAvailable` | Is gum on PATH? |

Fail-soft: without gum, confirm/input fall back to `Read-Host`.

## Par CLI ↔ IDE

| IDE | DevShell |
|-----|----------|
| Modal dialog | `Invoke-DsConfirm` |
| Quick pick | `Invoke-DsGumChoose` / `Invoke-DsFuzzy` |
