# fuzzy

Abstracción de selección fuzzy. Usa `fzf` si está en PATH; si no, menú numerado.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Invoke-DsFuzzy -Items ...` | Elige uno (o `-Multi`) |
| `Test-DsFzfAvailable` | ¿Hay fzf? |

## Ejemplo

```powershell
'alpha','bravo','charlie' | Invoke-DsFuzzy -Prompt 'pick'
```

## Par CLI ↔ IDE

| IDE | CLI |
|-----|-----|
| Quick Open / Command Palette filter | `Invoke-DsFuzzy` |

## Reemplazo

Otro backend (PSFzf-only, fzy, etc.) puede sustituir este módulo manteniendo `Invoke-DsFuzzy`.
