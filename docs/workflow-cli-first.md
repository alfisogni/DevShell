# Workflow CLI-first

## Objetivo

Desarrollar de forma continua en la **terminal** (DevShell + Cursor Agent/CLI), y usar el **IDE gráfico** solo cuando aporte claridad real (revisión visual, navegación densa de un archivo, etc.).

La migración es **gradual**: no hace falta abandonar el IDE de un día para el otro. Cada módulo debería documentar el par “en el IDE / en la CLI”.

## Mapa de pares (visión)

| En el IDE Cursor | En DevShell (CLI) | Módulo |
|------------------|-------------------|--------|
| Chat / Agent panel | `Invoke-DsAi` (provider: cursor u otro) | `ai` |
| Abrir carpeta en GUI | `Invoke-DsIde` | `ai` |
| Abrir carpeta / recent | fuzzy jump a proyectos | `projects` |
| Source Control | status/diff/branch en terminal | `git` |
| Quick Open (Ctrl+P) | fuzzy files | `fuzzy` |
| Terminal integrada | la shell *es* el entorno | core |
| Peek / multi-pane review | `Invoke-DsIde` puntual | `ai` |
| Extensions UI | tools + doctor | `tools`, `doctor` |
| Linear MCP / plugin | `dev connect linear` + report providers | `knowledge` |
| Chat “¿qué decidimos sobre X?” | `dev ask '…'` / `Invoke-DsAsk` | `knowledge` |
| Revisar reporte del día | `dev report today` → journal path | `knowledge` |
| Nota ad hoc | `dev note …` / `Add-DsKnowledgeNote` | `knowledge` |

## Reglas de migración

1. **Default CLI.** Si hay comando DevShell, usalo primero.
2. **IDE bajo demanda.** `Invoke-DsIde` (nombre tentativo) abre Cursor GUI en el path/diff actual — no al revés.
3. **Documentar el hueco.** Si algo solo existe en el IDE, anotalo en el README del módulo y en este doc hasta tener par CLI.
4. **Sin culpa.** Revisar un PR grande en el IDE está bien; el objetivo es que *puedas* vivir en la terminal, no que estés obligado.

## Sesión típica (objetivo)

```text
pwsh  →  DevShell banner (aesthetic)
      →  Invoke-DsProject / fuzzy jump
      →  Invoke-DsAi  (provider default, p.ej. cursor)
      →  git status / diff en CLI
      →  solo si hace falta: Invoke-DsIde para review
```

## Estado

Los comandos de la tabla se implementan en fases posteriores. Este documento fija la **intención** del producto.
