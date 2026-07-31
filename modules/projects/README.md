# projects

Gestiona ubicaciones frecuentes bajo `ProjectRoots` (default `~/source`).

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Get-DsProject` | Lista proyectos (dirs de 1er nivel) |
| `Invoke-DsProject` | Fuzzy jump + actualiza `DsContext.Project` |
| `Set-DsProject -Path` | Entra a un path de proyecto |

`*` en el selector = tiene `.git`.

## Keys

| Chord | Acción |
|-------|--------|
| `Ctrl+Shift+O` | Open project |

## Config

`config/defaults.psd1` / `user.psd1`:

```powershell
ProjectRoots = @('~/source')
```

## Par CLI ↔ IDE

| IDE | CLI |
|-----|-----|
| Recent / Open Folder | `Invoke-DsProject` |
