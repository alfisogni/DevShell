# AI agents (generic)

AI is **a module**, not the center of DevShell. The public API is provider-agnostic:

- `Invoke-DsAi` — run the default (or named) provider
- `Register-DsAiProvider` — plug another backend
- `Invoke-DsIde` — open a GUI IDE only when you choose to

Cursor Agent CLI ships as `modules/ai/providers/cursor.ps1`. Later you can add `claude.ps1`, `copilot.ps1`, etc. without renaming the module.

The **Knowledge Engine** (`Invoke-DsAsk`) retrieves from `~/.devshell/knowledge` and then calls `Invoke-DsAi` with whatever provider is configured — see [knowledge-agents.md](knowledge-agents.md) and [knowledge.md](knowledge.md).

See [modules/ai/README.md](../modules/ai/README.md).
