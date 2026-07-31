# Configuration

## Capas (prioridad creciente)

1. `config/defaults.psd1` — shipped con el repo
2. `modules/<name>/config.psd1` — defaults por módulo
3. `config/modules.psd1` — enable/disable y orden
4. `config/user.psd1` — máquina local (**gitignored**; usar `user.psd1.example`)

Merge profundo: gana la capa superior.

## `modules.psd1`

Controla qué módulos cargan y en qué orden relativo (el topo-sort de `dependsOn` sigue mandando; este archivo puede forzar disable u order hints).

```powershell
@{
    Enabled = @(
        'aesthetic'
        'keymap'
        'prompt'
        'fuzzy'
        'navigation'
        'projects'
        'git'
        'ai'
        'history'
        'completions'
        'tools'
        'aliases'
        'utilities'
        'doctor'
        'knowledge'
    )
    Disabled = @()
}
```

## Knowledge Engine (`user.psd1`)

```powershell
Knowledge = @{
    Root = '~/.devshell'   # journal/graph under <Root>/knowledge/
}
```

También: env `DEVSHELL_KNOWLEDGE_ROOT` (útil en tests / agentes).

Credenciales de providers (`dev connect`): `~/.devshell/credentials/` (o `<Root>/credentials/`).

## `user.psd1`

Overrides personales: tema, paths de proyectos, path del Cursor CLI, verbosity de logs, bindings custom, `Knowledge.Root`.

## Sin side effects al importar

Hasta `Start-DevShell` (Fase 1), importar el módulo raíz no debe mutar el profile ni registrar keys.
