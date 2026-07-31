# Arquitectura

**Visión de producto:** [vision.md](vision.md) (Vision 2.0). Este archivo describe **cómo está construido** el sistema hoy; la visión describe **hacia dónde**.

## Capas

```text
┌─────────────────────────────────────────┐
│  Profile / init.ps1                     │
├─────────────────────────────────────────┤
│  DevShell (bootstrap)                   │
├─────────────────────────────────────────┤
│  core/  Loader · Config · Events · Keymap · Logging · PromptHooks
├─────────────────────────────────────────┤
│  modules/*  (features aisladas)         │
│  aesthetic · cursor · git · fuzzy · …   │
├─────────────────────────────────────────┤
│  themes/  config/  (datos, no lógica)   │
└─────────────────────────────────────────┘
```

## Responsabilidades del core

- Descubrir módulos bajo `modules/` (excepto `_template`).
- Validar `module.json`.
- Ordenar por `dependsOn` (topo-sort).
- Cargar con **fail soft** (warning + skip).
- Merge de configuración.
- Pub/sub de hooks (`OnLoad`, `OnKeymap`, `OnPrompt`, …).
- Registro central de keybindings (API; UI en módulo `keymap`).

El core **no** implementa git, fuzzy, Cursor agent ni temas visuales.

## Ciclo de arranque

1. `init.ps1` → import raíz.
2. Leer `config/defaults.psd1` + `modules.psd1` + `user.psd1`.
3. Descubrir y validar manifests.
4. Resolver dependencias.
5. Importar cada módulo habilitado.
6. Disparar hooks (`OnLoad`, luego `OnKeymap`, luego prompt).
7. Shell lista.

## Módulo `ai` (visión)

Capa genérica de agentes. **Cursor es un provider**, no el nombre del módulo. Otros backends se registran con `Register-DsAiProvider` o archivos en `modules/ai/providers/`.

`Invoke-DsIde` abre el IDE gráfico bajo demanda (Cursor/VS Code), sin ser el flujo default.

## Módulo `knowledge` (visión)

Memoria persistente del desarrollador (journal + graph + providers). Agnóstica de agente: cualquier cliente de DevShell lee los mismos archivos; `Invoke-DsAsk` recupera contexto y delega en `Invoke-DsAi`. Ver [knowledge.md](knowledge.md).

## Módulo `aesthetic` (visión)

Dueño de la cohesión visual: tema activo en `themes/`, banner, tokens. `prompt` consume tokens. Puede adaptar Oh My Posh / Starship **sin acoplar el core** a ellos.

## `DsContext` (opcional)

Snapshot liviano de sesión (`Get-DsContext`): Location, Project, Theme, LoadedModules, Tools. Los módulos pueden leerlo; **no** es obligatorio para cargar. Ver [context.md](context.md).

## Productividad ≠ solo desarrollo

La shell cubre desarrollo, productividad general (navegación, búsqueda, utilidades, notas) y sistema (doctor, config). El módulo `utilities` agrupa helpers diarios no-dev.

## Límites

- Sin acoplamiento lateral entre módulos.
- Sin side effects al solo `Import-Module`: el trabajo ocurre en `Start-DevShell`.
- Target primario: PowerShell 7.
- Sin DI container ni objeto global obligatorio (`DsContext` es opcional).
