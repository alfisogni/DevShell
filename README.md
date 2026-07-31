# DevShell

**Developer Operating Environment** on Windows — modular **PowerShell 7** shell. Not “a prettier terminal”: a coherent system for daily development (CLI-first, IDE-optional, AI-agnostic, Knowledge-first).

**Product vision (canonical):** [docs/vision.md](docs/vision.md) — **Vision 2.0**.

## Philosophy (summary)

1. **CLI First** — GUI is optional.
2. **IDE Optional** — Cursor / VS Code / Neovim consume DevShell; none owns it.
3. **AI Agnostic** — providers, not a vendor lock-in.
4. **Knowledge First** — reports are views of knowledge.
5. **Everything Modular** + **Fail Soft**.

Golden rule: *Does this make the whole environment feel more integrated?*

Full text: [docs/vision.md](docs/vision.md).

## Install

Install hooks into your PowerShell profile. AI is a generic module (`Invoke-DsAi`); Cursor Agent is one provider.

```powershell
.\install.ps1
pwsh
```

| Key / command | Use |
|---------------|-----|
| `Ctrl+Shift+P` | Palette |
| `Ctrl+Shift+O` / `dsp` | Project picker |
| `Ctrl+Shift+A` / `dsa '…'` | AI one-shot |
| `dsa -Chat` | Interactive Agent |
| `Ctrl+Shift+S` / `dsg` | Git status |
| `Ctrl+Alt+K` / `dsreport` / `dev report` | Knowledge report (today) |
| `dsknote` / `dev note` | Knowledge note |
| `dsh` / `dsd` | Help / doctor |
| `Show-DsKeys` | All bindings |

> Windows Terminal keeps `Ctrl+Shift+N` (new window) and `Ctrl+Shift+V` (paste). DevShell uses `Ctrl+Shift+J` (utilities note), `Ctrl+Shift+K` (git branch), and `Ctrl+Alt+K` (knowledge report). Prefer aliases if a chord is intercepted.

Try Knowledge Engine: [modules/knowledge/README.md](modules/knowledge/README.md#cómo-probar-rápido).

## Requirements

- PowerShell 7 (`pwsh`) — not Windows PowerShell 5.1  
  `winget install Microsoft.PowerShell`
- Windows Terminal (recommended)
- Optional: [fzf](https://github.com/junegunn/fzf), Cursor Agent CLI (`agent`) for AI

## Layout

```text
core/          kernel (loader, config, events, keymap)
modules/       independent, replaceable features
config/        defaults + enable/disable modules
themes/        visual packs (aesthetic)
docs/          architecture, contract, CLI-first workflow
```

## Docs

| Doc | Contents |
|-----|----------|
| [vision.md](docs/vision.md) | **Vision 2.0 — product north star** |
| [architecture.md](docs/architecture.md) | Layers, load cycle, core boundaries |
| [module-contract.md](docs/module-contract.md) | Writing or replacing a module |
| [workflow-cli-first.md](docs/workflow-cli-first.md) | IDE → CLI migration |
| [aesthetic.md](docs/aesthetic.md) | Themes, banner (→ Lennerk Design Language) |
| [configuration.md](docs/configuration.md) | Config layers |
| [keymap.md](docs/keymap.md) | Bindings & aliases (how to discover commands) |
| [knowledge.md](docs/knowledge.md) | Knowledge Engine overview |
| [knowledge-agents.md](docs/knowledge-agents.md) | Agent contract (any vendor) |
| [privacy.md](docs/privacy.md) | Local vs off-machine data |
| [roadmap.md](docs/roadmap.md) | Implementation phases |

## Quickstart

```powershell
git clone https://github.com/alfisogni/DevShell.git
cd DevShell
.\install.ps1
pwsh
```

Copy `config/user.psd1.example` → `config/user.psd1` for personal overrides.

## Principles

1. One module = one contract (`module.json` + entry + README).
2. No coupling between modules; only core APIs / hooks.
3. Keyboard-first and discoverable (`Get-DsHelp` / palette).
4. Fail soft: a broken module must not kill the shell.
5. Config over code.
6. CLI-first / IDE-optional.
7. Aesthetics as a first-class module (`aesthetic` + `themes/`) → Lennerk Design Language ([vision.md](docs/vision.md)).
8. Knowledge First — reports are views of knowledge.
9. Golden rule: integrated DOE > isolated features.

## License

MIT — see [LICENSE](LICENSE).
