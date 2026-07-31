# Privacy & data

DevShell itself has **no telemetry**. Nothing is sent to a DevShell server.

## What stays local

| Data | Where |
|------|--------|
| `config/user.psd1` | Your machine only (gitignored — never commit it) |
| Quick notes (`dsnote`) | `Documents/DevShellNotes` (or your `Utilities.NotesDir`) |
| Knowledge Engine journal / graph | `~/.devshell/knowledge/` (override with `Knowledge.Root` or `DEVSHELL_KNOWLEDGE_ROOT`) |
| Provider credentials (`dev connect`) | `~/.devshell/credentials/` (local; never commit) |
| Doctor / logs | Printed in your terminal |
| Bookmarks, location stack | In-memory / session |

## What can leave your machine

| Feature | When | Destination |
|---------|------|-------------|
| Weather widget | Only if you enable `Startup.Weather` / theme weather | [wttr.in](https://wttr.in) (IP + optional location string) |
| AI (`dsa` / `Invoke-DsAi` / `dev ask`) | When you invoke it | Your configured AI provider CLI → that vendor’s services |
| Knowledge remotes (`github` / `linear` / `azure` providers) | During `dev report` / `dev connect` when authenticated | GitHub / Linear / Azure DevOps APIs |
| IDE open (`Invoke-DsIde`) | When you invoke it | Local Cursor/VS Code process |

Defaults: weather **off**, side panel is the local quick-ref memo.

## Publishing / contributing

- Do **not** commit secrets, tokens, `.env`, or personal `user.psd1`.
- Commit metadata (author name/email) is public if the repo is public — use a mail you are fine sharing, or configure `git` accordingly before contributing.
- Prefer pull requests to `main` (direct pushes may be blocked on the GitHub repo).

## Public repo hygiene

Tracked files, commit messages, and PR titles/bodies must stay generic:

- Project examples: `Acme`, `DemoApp`, `ProjectA` only — never real client or local folder names.
- Paths: use `~/projects`, `~/source`, or `ProjectRoots` in docs/defaults — never machine-specific paths like `C:\Users\…` in the public tree.
- Private context (real folder names, client notes, local workflows) lives only in gitignored `.ai/` and `config/user.psd1`.
- Knowledge notes and client deliverables stay under `~/.devshell/` or outside this repo — never under `examples/` or other tracked paths.

If sensitive content was ever pushed, scrubbing the tip is not enough; history must be replaced (fresh repo / rewritten history) and clones re-created.
