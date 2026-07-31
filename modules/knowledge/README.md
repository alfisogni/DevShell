# Knowledge Engine

Memoria persistente del desarrollador en DevShell: providers → merge con confianza → journal + grafo → consultas con cualquier agente AI.

## Cómo probar (rápido)

Desde la raíz del repo (o con el profile ya instalado):

```powershell
# 1) Arrancar DevShell
Import-Module ./DevShell.psd1 -Force
Start-DevShell -Quiet          # o: .\init.ps1

# 2) Verificar que el módulo cargó
Get-DsKnowledgeProvider        # git, notes, cursor, github, linear, azure
Invoke-DsDoctor                # checks Knowledge:* y Alias:dsreport, …
Get-DsAlias | ? Name -match 'ds(report|ask|search|knote|connect)'

# 3) Descubrir comandos / atajos
dsh                            # Get-DsHelp
Show-DsKeys                    # incluye Ctrl+Alt+K → report today
Get-DsCommandCatalog | ? Name -match 'Knowledge|Report|DsAsk|DsDev'
dev help

# 4) Flujo mínimo humano
dev note -Project DemoApp 'Hoy validamos GET /route en DemoApp'
dev report today -Project DemoApp -SkipAuth
# o excluir meta-trabajo:
dev report today -ExcludeProject DevShell -SkipAuth
code (Invoke-DsReport -Path)

# GitHub auth (NO embeber en Cursor chat — falla sin TTY):
# Abrí Windows Terminal / pwsh normal y corrí:
#   gh auth login -h github.com -p https -w

# 5) Flujo agent-safe (sin prompts)
dev report today -NonInteractive -Json
Search-DsKnowledge 'Company.depot' -Json
```

Journal generado (default):

```text
~/.devshell/knowledge/journal/YYYY/MM/YYYY-MM-DD/
  executive.md  technical.md  knowledge.md  metadata.json  context.json
```

Override de raíz: `Knowledge.Root` en `user.psd1`, o env `DEVSHELL_KNOWLEDGE_ROOT`.

### Tests automatizados

```powershell
pwsh -File ./scripts/Invoke-DevShellTests.ps1 -Path ./tests/modules/Knowledge.Tests.ps1
```

## Comandos

| Cómo llamarlo | Función | Notas |
|---------------|---------|--------|
| `dev report [today\|week\|month]` | `Invoke-DsReport` | `-Project`, `-ExcludeProject`, `dsreport` |
| `dev search <query>` | `Search-DsKnowledge` | `dssearch`; `-Json` |
| `dev ask <question>` | `Invoke-DsAsk` | `dsask` → retrieval + `Invoke-DsAi` |
| `dev note [-Project X] <text> \| -Paste` | `Add-DsKnowledgeNote` | tag `[X]`; pegá texto largo sin salir |
| `dev connect linear\|github\|azure` | `Invoke-DsConnect` | `dsconnect` |
| `dev export … -OutPath <dir>` | `Export-DsKnowledge` | week/month + `-Compress` |
| `dev help` | `Invoke-DsDev help` | |

### Scope del reporte

```powershell
dev report today -Project DemoApp
dev report today -Project DemoApp,Acme
dev report today -ExcludeProject DevShell
Invoke-DsReport -Period today -Project DemoApp -SkipAuth
```

Defaults opcionales en `user.psd1`:

```powershell
Knowledge = @{
    Report = @{
        ExcludeProjects = @('DevShell', 'devshell')
        # IncludeProjects = @('DemoApp')
    }
}
```

`-Project` resuelve carpetas bajo `ProjectRoots` (módulo projects) + repo git actual.  
Notas: usá `dev note -Project DemoApp '...'` o `-Paste` / here-string para que el filtro las incluya.

**Linear / Notion / etc.:** si no tenés cuenta, el provider aparece como `– not configured` (no es error). Solo se activa si configurás API key (`dev connect linear`).

### Ejemplo: nota en texto (sin salir de la shell) + reporte acotado

**Importante:** no subas contenido de clientes al repo público de DevShell. Las notas viven en `~/.devshell/knowledge/notes/` (local). Usá nombres ficticios en docs públicos; el contexto real de tus carpetas va en `.ai/` (gitignored).

```powershell
Get-DsProject | Format-Table Name, Path

# 1) Texto largo SIN crear archivos ni salir de la shell (recomendado)
dev note -Project Acme -Paste
# Pegá el resumen… y terminá con una línea solo con .

# Alternativa power-user: here-string (también queda en la shell)
dev note -Project Acme @'
Resumen funcional del día
- Módulo A: ...
- Riesgos: ...
'@

# 2) Contexto corto del día
dev note -Project DemoApp 'Jornada: trabajo DemoApp + Acme'

# 3) Reporte solo de esos proyectos
dev report today -Project DemoApp,Acme
explorer (Invoke-DsReport -Path)
```

`-File` es **opcional** y solo para un `.md` que ya tengas **fuera** del repo (Documents, OneDrive, etc.). No hace falta — y no conviene — para el flujo diario.

### GitHub auth

`gh auth login` **no funciona embebidamente** (Cursor chat / agent / pipes). En una terminal real:

```powershell
gh auth login -h github.com -p https -w
gh auth status
```

Flags agent-safe en report: `-NonInteractive`, `-SkipAuth`, `-Json`, `-Path`.

## Keys (impacto en keymap)

| Chord | Acción | Por qué no `Ctrl+Shift+K` |
|-------|--------|---------------------------|
| `Ctrl+Alt+K` | `Invoke-DsReport today` | `Ctrl+Shift+K` ya lo usa **git** (checkout branch) |

Registro: `Register-DsKnowledgeKeys` → `Register-DsKey` (core). Ver con `Show-DsKeys`. Catálogo documentado en [docs/keymap.md](../../docs/keymap.md).

## Aliases (impacto en módulo `aliases`)

Añadidos al catálogo de [`Aliases.psm1`](../aliases/Aliases.psm1) (banner QUICK REF + doctor):

`dsreport`, `dsask`, `dssearch`, `dsknote`, `dsconnect`

`dsnote` sigue siendo la nota rápida de **utilities** (`Documents\DevShellNotes`).  
`dsknote` / `dev note` escribe en **`~/.devshell/knowledge/notes`** (fuente del provider `notes`). El provider también *lee* las notas legacy de utilities al generar reportes.

## Providers

| Provider | Priority | Fuente |
|----------|----------|--------|
| git | 100 | Commits, files, tags locales |
| cursor | 90 | Señales opcionales Cursor (no inventa chats) |
| azure | 80 | Azure DevOps (`az` / PAT) |
| github | 70 | `gh` CLI |
| linear | 55 | GraphQL API (`dev connect linear`) |
| notes | 10 | Notas manuales KE + legacy utilities |

## Storage

```text
~/.devshell/knowledge/
  journal/YYYY/MM/YYYY-MM-DD/
  graph/entities.json  graph/edges.json
  index/metadata-index.json
  notes/YYYY-MM-DD.md
~/.devshell/credentials/     # linear/azure tokens (local)
```

## CLI ↔ IDE

| En un IDE (ej. Cursor) | En DevShell (cualquier agente / humano) |
|------------------------|-----------------------------------------|
| Linear Marketplace MCP | `dev connect linear` |
| Chat “¿qué decidimos?” | `dev ask '…'` / `dsask` |
| Abrir reporte del día | `dev report today` → path del journal |
| Nota ad hoc | `dev note …` / `dsknote` |

Contrato para agentes: [docs/knowledge-agents.md](../../docs/knowledge-agents.md).

## Relación con otros módulos

| Módulo | Relación |
|--------|----------|
| `git` | Provider + chord `Ctrl+Shift+K` intacto |
| `ai` | `Invoke-DsAsk` delega en `Invoke-DsAi` |
| `utilities` | `dsnote` legacy; KE lo consume en collect |
| `aliases` | Nuevos atajos `ds*` |
| `keymap` / core | Nuevo chord vía `Register-DsKey` |
| `doctor` | Checks `Knowledge:*` + aliases |

## Replace

Deshabilitar `knowledge` en `config/modules.psd1`. Los archivos del store quedan en disco.
