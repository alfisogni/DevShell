# Knowledge Engine — agent contract

Any agent that can run PowerShell in DevShell (or read the filesystem) can use the Knowledge Engine. This is **not** Cursor-specific.

## Rules for agents

1. **Prefer knowledge before git.** Call `Search-DsKnowledge` / read `~/.devshell/knowledge/index/metadata-index.json` and recent `knowledge.md` before reconstructing history from git alone.
2. **Never invent.** Only assert facts present in journal files, metadata, or graph entities/edges. If missing, say it is unverified or unknown.
3. **Use non-interactive flags** when unattended:
   - `Invoke-DsReport -Period today -NonInteractive -Json`
   - `Search-DsKnowledge 'Planner' -Json`
   - `Invoke-DsConnect linear -NonInteractive` (succeeds only if already authenticated)
4. **Ask via DevShell, not a vendor SDK:** `Invoke-DsAsk '…'` builds retrieval context and calls `Invoke-DsAi` with the **configured** AI provider (`Get-DsAiDefaultProvider`).
5. **Discover commands:** `dev help`, `dsh` / `Get-DsHelp`, `Show-DsKeys`, `Get-DsAlias`, `Get-DsCommandCatalog`, or `Get-Command Invoke-DsReport, Search-DsKnowledge, Invoke-DsAsk, Add-DsKnowledgeNote, Invoke-DsConnect, Export-DsKnowledge, Invoke-DsDev`.
6. **Key chord:** `Ctrl+Alt+K` → report today (git keeps `Ctrl+Shift+K` for branch checkout). Full map: [keymap.md](keymap.md).

## Minimal workflow

```powershell
Import-Module ./DevShell.psd1; Start-DevShell -Quiet -SkipBanner
Add-DsKnowledgeNote 'Decided to keep Company.depot as fallback only'
Invoke-DsReport -Period today -NonInteractive -Json
Search-DsKnowledge 'Company.depot' -Json
Invoke-DsAsk 'What did we decide about Company.depot?'
```

## Store layout (readable by any tool)

```text
~/.devshell/knowledge/journal/YYYY/MM/YYYY-MM-DD/{executive,technical,knowledge}.md
~/.devshell/knowledge/journal/YYYY/MM/YYYY-MM-DD/metadata.json
~/.devshell/knowledge/graph/{entities,edges}.json
~/.devshell/knowledge/index/metadata-index.json
```

## Optional product snippets

Point product-specific instruction files at **this document**, for example:

- `.cursor/rules` → “Follow docs/knowledge-agents.md”
- `AGENTS.md` → “Follow docs/knowledge-agents.md”
- Claude / Copilot instruction files → same

Do not duplicate the contract per vendor.
