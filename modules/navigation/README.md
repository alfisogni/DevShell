# navigation

Navegación rápida por teclado: stack de directorios, bookmarks y fuzzy cd.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Set-DsLocation path` | cd con push al stack |
| `Pop-DsLocation` | vuelve al anterior |
| `Invoke-DsFuzzyCd` | elige subcarpeta (depth 2) |
| `Set-DsBookmark -Name x` | guarda ubicación |
| `Get-DsBookmark` | lista bookmarks de la sesión |
| `Remove-DsBookmark name` | borra uno (o varios) |
| `Remove-DsBookmark -All` | borra todos los de la sesión |
| `Invoke-DsGoto` | fuzzy a bookmark |

Los bookmarks de `Set-DsBookmark` viven **en memoria de la sesión**. Si los pusiste en `user.psd1` → `Navigation.Bookmarks`, sacalos de ahí o van a volver al reiniciar.

## Keys

| Chord | Acción |
|-------|--------|
| `Ctrl+Shift+G` | Fuzzy cd |
| `Ctrl+Shift+B` | Goto bookmark |

## Par CLI ↔ IDE

| IDE | CLI |
|-----|-----|
| Explorer / Open Folder | `Invoke-DsFuzzyCd` / `Invoke-DsGoto` |
