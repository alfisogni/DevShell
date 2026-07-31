# prompt

Prompt de sesión compuesto por segmentos ordenados. Consume símbolos/colores de `aesthetic` sin acoplarse a Oh My Posh/Starship.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Register-DsPromptSegment` | Agrega un segmento |
| `Get-DsPromptText` | Texto actual del prompt |
| `Get-DsPromptSegment` | Lista segmentos |

## Segmentos default

- `location` — path corto (`~/...`)
- `project` — `[nombre]` si `DsContext.Project` está seteado
- `git` — lo registra el módulo git (branch + dirty)

## Par CLI ↔ IDE

| IDE | CLI |
|-----|-----|
| Status bar | prompt segmentos |

## Reemplazo

Deshabilitá `prompt` y usá un bridge OMP/Starship como módulo alternativo.
