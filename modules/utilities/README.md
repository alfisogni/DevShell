# utilities

Helpers de productividad general (no solo desarrollo). Offline-first: sin APIs externas por defecto.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Get-DsWhich name` | Dónde está un comando |
| `Get-DsEnv [-Filter x]` | Variables de entorno |
| `Invoke-DsOpen [path]` | Abre en el SO (Explorer/app) |
| `Invoke-DsNote texto...` | Nota rápida en `Documents\DevShellNotes\YYYY-MM-DD.md` |

> **Knowledge Engine:** `dev note` / `dsknote` escribe en `~/.devshell/knowledge/notes` (memoria del KE).  
> `dsnote` / `Ctrl+Shift+J` sigue siendo la nota rápida de utilities. El provider `notes` del KE **también lee** este directorio al generar reportes.

## Keys

| Chord | Acción |
|-------|--------|
| `Ctrl+Shift+J` | Nota rápida (evita WT `Ctrl+Shift+N`) |

## Config

`user.psd1`:

```powershell
Utilities = @{ NotesDir = '~/Documents/DevShellNotes' }
```

## Par CLI ↔ IDE / GUI

| GUI | CLI |
|-----|-----|
| Buscar app / where | `Get-DsWhich` |
| Explorer | `Invoke-DsOpen` |
| App de notas | `Invoke-DsNote` |
