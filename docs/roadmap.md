# Roadmap

## Fase 0 — Scaffold y docs

- [x] Repo + estructura
- [x] Contrato de módulo + template
- [x] Docs visión (CLI-first, aesthetic, config)
- [x] Stubs de módulos

## Fase 1 — Core mínimo

- [x] Logging, Config, Events, Manifest, Loader, Context
- [x] `Start-DevShell` / `init.ps1` / `install.ps1`
- [x] `doctor` + tests Pester

## Fase 2 — Keyboard foundation

- [x] `Register-DsKey` + PSReadLine
- [x] `keymap` (catálogo, palette)

## Fase 3 — Navegación

- [x] `fuzzy` / `navigation` / `projects`

## Fase 4 — Estética + git + productividad

- [x] `aesthetic` / `prompt` / `git`
- [x] `history` / `utilities`
- [x] Docs Windows Terminal

## Fase 5 — Integraciones

- [x] `ai` genérico + provider Cursor (reemplaza módulo `cursor`)
- [x] `tools`, `completions`, `aliases`
- [x] `doctor` ampliado (tools + AI)
- [x] `New-DevShellModule.ps1`
- [ ] CI Pester (opcional)

## Fase 6 — Knowledge Engine

- [x] Módulo `knowledge` + registry `Register-DsKnowledgeProvider`
- [x] Providers: git, notes, cursor (señales), github, linear, azure
- [x] Journal `~/.devshell/knowledge/journal/...` + metadata-index
- [x] Knowledge Graph (entities/edges)
- [x] `dev report|search|ask|note|connect|export` (agent-safe flags)
- [x] Docs agent-agnostic ([knowledge-agents.md](knowledge-agents.md))

## Fase 7 — Vision 2.0 (DOE)

Rumbo canónico: [vision.md](vision.md). Incremental; no un big-bang.

- [x] Documento Vision 2.0 + enlace desde README / architecture
- [ ] Lennerk Dark design tokens en `themes/` + semantic roles (Primary / Interactive / Knowledge / …)
- [ ] Nerd Font iconografía por módulo (sin emojis)
- [ ] Salidas en bloques/paneles (spacing) — git/status/doctor/knowledge
- [ ] Startup dashboard (más que banner + QUICK REF)
- [ ] Prompt denso/minimalista alineado al Design Language
- [ ] Workspaces (`dev workspace …`) — layout + contexto KE + AI
- [ ] Windows Terminal multi-pane layouts declarativos
- [ ] Neovim como editor de referencia CLI; IDE sigue optional
- [ ] Suite TUI unificada estéticamente (lazygit, yazi, btop, …)

## Principios

1. Calidad > cantidad.
2. Fail soft.
3. Estética e IA son módulos reemplazables; IA ≠ centro.
4. Productividad general ≠ solo desarrollo.
5. Vision 2.0 ([vision.md](vision.md)): DOE coherente > features aisladas.
