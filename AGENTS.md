# AGENTS.md

Instructions for any AI agent working on this repository.

## Read first

1. If **`.ai/`** exists locally, read it first for private project context, privacy, and commit/PR rules. **Never** copy `.ai` contents into tracked files, commits, or PR text.
2. **[docs/vision.md](docs/vision.md)** — DevShell Vision 2.0 (product north star).
3. **[docs/architecture.md](docs/architecture.md)** — how the system is built today.
4. **[docs/module-contract.md](docs/module-contract.md)** — how to add/replace a module.
5. **[docs/knowledge-agents.md](docs/knowledge-agents.md)** — Knowledge Engine agent contract.

## Public vs local

- Tracked docs/help/tests/examples: fictional project names only (`Acme`, `DemoApp`, `ProjectA`).
- No client names, real local folder names, or machine paths in the public tree or in commit/PR messages.
- Public defaults use portable roots like `~/projects` — never `C:\Users\…` or machine-specific drive paths. Real roots belong in gitignored `config/user.psd1` and `.ai/`.
- Before every commit/PR: search the diff for real project/client names and absolute Windows paths; if found, remove them.

## Product stance

DevShell is a **Developer Operating Environment**, not a PowerShell config pack.

- CLI first · IDE optional · AI agnostic · Knowledge first · Modular · Fail soft
- Golden rule: *Does this make the whole environment feel more integrated?*
- Do **not** add isolated “cool features” that break visual/system coherence.
- Prefer Lennerk Design Language direction (tokens in `aesthetic` / `themes/`) over one-off colors/emojis.

## Implementation habits

- New capability → new or existing **module** under `modules/`, not core.
- Keybindings via `Register-DsKey` in module `OnKeymap`.
- Aliases via `aliases` catalog when user-facing shortcuts are needed.
- Knowledge claims must cite sources; never invent history.
- Agent-safe CLIs: support `-NonInteractive` / `-Json` where automation matters.
- Update the “hoy vs Vision 2.0” table in `docs/vision.md` / roadmap when shipping a vision row.
