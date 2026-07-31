# keymap

Descubrimiento de comandos y atajos. El **registro** de chords vive en el core (`Register-DsKey`); este módulo aporta UI/listados.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Get-DsCommandCatalog` | Lista funciones `Ds*` / `*-Ds*` |
| `Show-DsKeys` | Muestra bindings registrados |
| `Invoke-DsPalette` | Selector simple de comandos (sin fzf aún) |

## Par CLI ↔ IDE

| IDE | CLI |
|-----|-----|
| Command Palette / Keyboard Shortcuts | `Invoke-DsPalette` / `Show-DsKeys` |

## Descubrir comandos (incl. Knowledge)

Ver tabla completa en [docs/keymap.md](../../docs/keymap.md). Resumen: `dsh`, `Show-DsKeys`, `Get-DsAlias`, `Get-DsCommandCatalog`, `dev help`.

Los módulos registran chords con `Register-DsKey` en `OnKeymap` — **no** editar core para agregar un atajo.

## Notas

Los chords `Ctrl+Shift+P` se registran en el catálogo DevShell; el cableado a PSReadLine llega en una iteración siguiente.
