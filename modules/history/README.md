# history

Búsqueda de historial sobre PSReadLine + selector fuzzy.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Get-DsHistory` | Lista historial (filtrable) |
| `Invoke-DsHistory` | Fuzzy → re-ejecuta |
| `Invoke-DsHistory -InsertOnly` | Fuzzy → inserta en la línea |

## Keys

| Chord | Acción |
|-------|--------|
| `Ctrl+R` | Fuzzy history (inserta en la línea) |
| `Ctrl+Shift+H` | Fuzzy history (ejecuta) |
| `↑` / `↓` | HistorySearchBackward/Forward |

## Par CLI ↔ IDE

| IDE | CLI |
|-----|-----|
| Command history UI | `Invoke-DsHistory` / `Ctrl+R` |
