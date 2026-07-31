# aesthetic

Dueño de la **identidad visual** de DevShell: temas, colores, símbolos y el banner de arranque.

No es un “skin cosmético suelto”: otros módulos (**prompt**, **git**, **help**) le piden tokens (`Get-DsThemeColor`, `Get-DsThemeSymbol`). Los **datos** del tema viven en `themes/<nombre>/`; este módulo es la **lógica**.

## Para qué sirve

| Necesidad | Qué hace aesthetic |
|-----------|-------------------|
| Primera impresión al abrir la shell | `Show-DsBanner` (arte + QUICK REF / weather) |
| Misma pal verdenegrita en help/prompt | `Get-DsThemeColor -Role Accent` |
| Símbolo del prompt / git | `Get-DsThemeSymbol` |
| Cambiar look sin tocar core | Carpeta nueva en `themes/` + `Set-DsTheme` / `Theme` en config |

## Qué contiene (repo)

```text
modules/aesthetic/
  Aesthetic.psm1     # APIs: theme load, banner, widgets, truecolor
  module.json
  config.psd1
  README.md

themes/default/      # pack de datos (NO es un módulo)
  theme.psd1         # Colors, Symbols, Banner, Terminal hints
  banner.txt         # ASCII art
  README.md          # identidad (#0A0A0A / #00C853)
```

## Cómo se usa (día a día)

Casi no lo invocás a mano: al hacer `Start-DevShell` (sin `-Quiet`/`-SkipBanner`) corre el banner solo.

```powershell
Import-Module ./DevShell.psd1
Start-DevShell                 # → Show-DsBanner

Show-DsBanner                  # re-dibujar
Show-DsBanner -ForceLayout Stack
Show-DsBanner -ForceLayout Side

Get-DsTheme                    # tema cargado
Get-DsThemeColor -Role Accent  # Hex + ConsoleColor
Set-DsTheme default            # recargar + banner
```

### Panel derecho del banner

```powershell
# config/user.psd1 o defaults
Startup = @{
    ShowBanner = $true
    SidePanel  = 'memo'    # memo | weather | none
    Memo       = @{ Enabled = $true }
    Weather    = @{ Enabled = $false; Location = '' }
}
```

- **memo** (default): QUICK REF de aliases (`Get-DsAliasCatalog`) + keys fijas. Offline.
- **weather**: wttr.in (opcional; sale de tu máquina — ver privacy).
- **none**: solo el arte.

Ventana angosta → layout **Stack** (arte arriba, panel abajo). Ancha → **Side**.

## Relación con otros módulos

```text
Start-DevShell
    └── Show-DsBanner          (aesthetic)
            ├── themes/*/banner.txt
            └── Get-DsMemoWidget ← Get-DsAliasCatalog (aliases)

prompt / git / Get-DsHelp
    └── Get-DsThemeColor / Get-DsThemeSymbol   (aesthetic)
```

| Módulo | Consume aesthetic? |
|--------|--------------------|
| `prompt` | Sí — colores y símbolo `>` |
| `git` | Sí — símbolo opcional en segmento |
| `aliases` | Alimenta el QUICK REF del banner (aesthetic lee el catálogo) |
| `knowledge` | No directo; sus aliases aparecen en el memo vía `aliases` |

**No hace falta tocar core** para un tema nuevo: agregás `themes/mi-tema/` y `Theme = 'mi-tema'` en `user.psd1`.

## Comandos públicos

| Comando | Descripción |
|---------|-------------|
| `Show-DsBanner` | Arte + panel (`-ForceLayout Auto\|Side\|Stack`) |
| `Get-DsTheme` / `Set-DsTheme` / `Import-DsTheme` | Cargar tema activo |
| `Get-DsThemeColor` | Sin args: lista paleta. Con `-Role Accent` (etc.): un token |
| `Get-DsThemeSymbol` | Sin args: lista símbolos. Con `-Name Prompt`: uno |
| `Get-DsMemoWidget` | Líneas plain del quick-ref |
| `Get-DsWeatherWidget` | Líneas de clima (si está enabled) |

```powershell
Get-DsThemeColor              # feedback: tema + todos los roles
Get-DsThemeColor Accent       # equivalente a -Role Accent
Get-DsThemeSymbol             # Prompt / Git / Sep
```

## Identidad

`#0A0A0A` / `#00C853` / blanco — minimalista (GitHub / Vercel / Linear).  
Sin neón / cyberpunk / Catppuccin púrpura. Ver [docs/aesthetic.md](../../docs/aesthetic.md).

## Replace

Deshabilitar `aesthetic` en `config/modules.psd1`: la shell sigue; banner cae al fallback de texto `DevShell` en `Show-DsStartupBanner`. Prompt/help usan colores de consola por defecto si no hay tema.
