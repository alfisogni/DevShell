# Aesthetic

**Vision 2.0:** la estética deja de ser “banner bonito” y pasa a ser el **Lennerk Design Language** — ver [vision.md](vision.md#design-language-lennerk).

## Rol

El módulo **`aesthetic`** es el dueño de la **cohesión visual** de DevShell:

1. Carga packs de tema desde `themes/<nombre>/` (datos, no lógica).
2. Dibuja el **banner** de arranque (arte + panel derecho) — evoluciona a **dashboard**.
3. Expone **tokens** (`Get-DsThemeColor`, `Get-DsThemeSymbol`) para que `prompt`, `git`, help, etc. se vean iguales.

No es Knowledge, ni AI, ni productividad: es **cómo se ve y se siente** el DOE.

## Hoy vs rumbo

| Hoy | Vision 2.0 |
|-----|------------|
| Tema `default` verde `#00C853` | Lennerk Dark (Catppuccin Mocha–inspired) |
| Roles Bg/Fg/Accent/Muted/… | + Interactive, Knowledge (purple), semántica fuerte |
| Banner + QUICK REF | Dashboard de sistema |
| Cascadia / JetBrains sugeridos | JetBrainsMono **Nerd Font** única |
| Poca iconografía | Iconos Nerd Font por módulo (sin emoji) |
| Líneas compactas en sitios | Bloques con aire / paneles textuales |

Migraciones van en `themes/` + APIs de `aesthetic`; los demás módulos **consumen tokens**, no hardcodean colores.

## Separación módulo vs tema

| Pieza | Dónde | Qué es |
|-------|-------|--------|
| Lógica | `modules/aesthetic/` | APIs PowerShell |
| Datos | `themes/default/` (u otro) | `theme.psd1` + `banner.txt` |

Cambiar colores/arte = editar o agregar un tema. Cambiar layout/truecolor = código del módulo.

## Banner

ASCII (gradiente verde DevShell) + panel derecho.

**Layout adaptable:** side-by-side solo si el ancho alcanza (`art + gap + memo`, mínimo ~100 cols). Si no cabe, se apila.

```powershell
Show-DsBanner                 # Auto
Show-DsBanner -ForceLayout Stack
Show-DsBanner -ForceLayout Side
```

Se muestra al `Start-DevShell` si `Startup.ShowBanner = $true` (y no pasás `-Quiet` / `-SkipBanner`).

Identidad: `#0A0A0A` / `#00C853` / blanco — no Catppuccin / no púrpura.

```powershell
Startup = @{
    ShowBanner = $true
    SidePanel  = 'memo'   # memo | weather | none
}
```

Las filas de aliases del QUICK REF salen de `Get-DsAliasCatalog` (misma fuente que `Enable-DsAliases`). Por eso al agregar `dsreport` / `dsknote` aparecen solos en el banner.

La sección **KEYS** del memo se arma desde `Get-DsKeyBinding` (un subconjunto preferido: palette, project, AI, git, note, knowledge…). La lista completa sigue siendo `Show-DsKeys`.

## Cómo se usa (humano)

Casi siempre **automático**. Manual:

```powershell
Show-DsBanner
Get-DsTheme
Get-DsThemeColor -Role Accent
Set-DsTheme default
```

Guía del módulo: [modules/aesthetic/README.md](../modules/aesthetic/README.md).

## Aliases

Los aliases (`dsg`, `dsp`, `dsa`, `dsreport`, …) **no** los registra aesthetic: los registra el módulo `aliases` al terminar de cargar. Aesthetic solo los **muestra** en el memo. Ver `Get-DsAlias` / [keymap.md](keymap.md).

## Relación con Knowledge

Knowledge no depende de aesthetic. Sus comandos entran al QUICK REF porque están en el catálogo de aliases. El chord `Ctrl+Alt+K` aparece en la sección KEYS del memo cuando el módulo knowledge registró el binding (`Get-DsKeyBinding`); la fuente completa sigue siendo `Show-DsKeys`.
