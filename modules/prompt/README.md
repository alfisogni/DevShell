# prompt

Warp-like **multi-line** identity prompt (no Starship).

```text
╭─ name
│
├ ~/path
├ Project
├ branch
├ Clean
├ 3m ago
│
╰▶
```

## Config

```powershell
# config/user.psd1
Prompt = @{ DisplayName = 'Ada' }
# or: $env:DEVSHELL_PROMPT_NAME = 'Ada'
```

## Commands

| Command | Role |
|---------|------|
| `Get-DsPromptText` | Structured warp payload |
| `Register-DsPromptSegment` | Extra lines (beyond core) |

## Par CLI ↔ IDE

| IDE | DevShell |
|-----|----------|
| Status bar | warp prompt segments |
| Starship/OMP | replace this module |
