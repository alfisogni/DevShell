# Aesthetic

**Vision 2.0:** la estética deja de ser “banner bonito” y pasa a ser el **Lennerk Design Language** — ver [vision.md](vision.md#design-language-lennerk).

## Rol

El módulo **`aesthetic`** es el dueño de la **cohesión visual** de DevShell:

1. Carga packs de tema desde `themes/<nombre>/` (datos, no lógica).
2. Dibuja el **banner / dashboard** de arranque (arte + panel derecho).
3. Expone **tokens** (`Get-DsThemeColor`, `Get-DsThemeSymbol`) para que `prompt`, `git`, help, etc. se vean iguales.

No es Knowledge, ni AI, ni productividad: es **cómo se ve y se siente** el DOE.

## Hoy vs rumbo

| Hoy | Vision 2.0 |
|-----|------------|
| Tema `default` verde `#00C853` (pre–Lennerk) | Tema **`lennerk`** (Catppuccin Mocha) — opt-in |
| Roles Bg/Fg/Accent/Muted/… | + **Interactive**, **Knowledge** |
| Banner + QUICK REF | **Dashboard** (`SidePanel = dashboard`) en `lennerk` |
| Cascadia / JetBrains sugeridos | JetBrainsMono **Nerd Font** |
| Un solo pack | Packs: `default`, `lennerk`, `tokyo-night` |

Migraciones van en `themes/` + APIs de `aesthetic`; los demás módulos **consumen tokens**, no hardcodean colores.

Identidad canónica del desktop vive **fuera** del repo (local-first): `$env:USERPROFILE\.config\lennerk\` — bridge `Export-DsTheme.ps1` genera packs aquí.

## Separación módulo vs tema

| Pieza | Dónde | Qué es |
|-------|-------|--------|
| Lógica | `modules/aesthetic/` | APIs PowerShell |
| Datos | `themes/<nombre>/` | `theme.psd1` + `banner.txt` |
| Design hub | `~/.config/lennerk/` (local) | tokens + profiles + bridge |

## Temas

```powershell
Set-DsTheme default       # verde histórico
Set-DsTheme lennerk       # Lennerk Dark + dashboard
Set-DsTheme tokyo-night   # pack polifacético
Get-DsThemeColor          # incluye Interactive / Knowledge
```

No se cambia `Theme` en `config/defaults.psd1` — usá `config/user.psd1` si querés Lennerk por defecto.

## Banner / dashboard

ASCII (gradiente del Accent del tema) + panel derecho.

| SidePanel | Contenido |
|-----------|-----------|
| `memo` | QUICK REF (compact) + KEYS **side-by-side** |
| `dashboard` | paneles Workspace / Git / System / Quick (`lennerk`) |
| `weather` | wttr.in |
| `none` | solo arte |

QUICK REF muestra un subset (~10 aliases core), no el catálogo entero. KEYS a la derecha. Completo: `Get-DsAlias` / `Show-DsKeys`.

```powershell
Show-DsBanner
Show-DsBanner -ForceLayout Stack
Get-DsDashboardWidget
```

## Cómo se usa (humano)

```powershell
Show-DsBanner
Get-DsTheme
Get-DsThemeColor -Role Accent
Set-DsTheme lennerk
```

Guía del módulo: [modules/aesthetic/README.md](../modules/aesthetic/README.md).

## Aliases

Los aliases (`dsg`, `dsp`, `dsyazi`, …) los registra el módulo `aliases`. Aesthetic solo los **muestra** en memo/dashboard. Ver `Get-DsAlias` / [keymap.md](keymap.md).

## Relación con Knowledge

Knowledge no depende de aesthetic. Sus comandos entran al QUICK REF porque están en el catálogo de aliases.
