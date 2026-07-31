# Knowledge Engine

## Role

The **knowledge** module is DevShell’s persistent memory: providers collect evidence, a merge step assigns confidence, journals and a knowledge graph are written as plain files, and any AI provider can answer questions using that store.

It is **agent-agnostic**. Cursor is one optional *source* provider and one optional *AI* backend — not the owner of the memory.

## Cómo probar

Guía paso a paso (humano + agent + Pester): ver el README del módulo → [modules/knowledge/README.md](../modules/knowledge/README.md#cómo-probar-rápido).

Resumen:

```powershell
Import-Module ./DevShell.psd1 -Force; Start-DevShell -Quiet
dev note 'Decisión de prueba'
dev report today
dev search 'prueba'
Show-DsKeys   # Ctrl+Alt+K = report today
dsh           # lista dev report|ask|search|note
```

## Boundaries

- Lives in `modules/knowledge/` (not core).
- Depends on `git`, `ai`, `utilities` for integration; does not import other feature modules directly.
- Credentials under `~/.devshell/credentials/` (not in the repo).
- Fail soft: missing auth or tools skip that provider and continue.
- **Keybinding:** registers `Ctrl+Alt+K` (does **not** reuse `Ctrl+Shift+K`, owned by git). Documented in [keymap.md](keymap.md).
- **Aliases:** adds `dsreport` / `dsask` / `dssearch` / `dsknote` / `dsconnect` via the `aliases` module catalog (not core).

## Pipeline

```text
Invoke-DsReport
  → detect providers
  → auth prompt (or skip if -NonInteractive)
  → CollectContext per provider
  → Merge (priority + confidence)
  → Update graph
  → Write executive.md / technical.md / knowledge.md / metadata.json
  → Update metadata-index.json
```

## Related docs

- [knowledge-agents.md](knowledge-agents.md) — contract for any agent
- [workflow-cli-first.md](workflow-cli-first.md) — CLI ↔ IDE pairs
- [keymap.md](keymap.md) — chords + aliases (incluye Knowledge)
- [ai.md](ai.md) — AI provider layer used by `Invoke-DsAsk`
- [modules/knowledge/README.md](../modules/knowledge/README.md)
