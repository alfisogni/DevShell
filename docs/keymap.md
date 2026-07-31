# Keymap

Bindings registrados por módulos vía `Register-DsKey` (core) y cableados a **PSReadLine** cuando está disponible.

## Cómo descubrir comandos

| Herramienta | Qué muestra |
|-------------|-------------|
| `dsh` / `Get-DsHelp` | Atajos de arranque (incluye Knowledge) |
| `Show-DsKeys` | Todos los chords registrados por módulo |
| `Invoke-DsPalette` / `Ctrl+Shift+P` | Palette de comandos |
| `Get-DsCommandCatalog` | Funciones `*-Ds*` / `Ds*` |
| `Get-DsAlias` | Aliases `ds*` y estado OK/conflicto |
| `Invoke-DsDoctor` | Checks de módulos, AI, **Knowledge:***, Alias:* |
| `dev help` | Subcomandos del Knowledge Engine |

No hace falta tocar **core** para un keybinding nuevo: el módulo llama `Register-DsKey` en su hook `OnKeymap`. Si el chord ya existe, el loader/keymap **omite** el segundo (fail soft) — elegí otro chord y documentalo aquí + en el README del módulo.

## Aliases (verificados)

Fuente: `Get-DsAlias` / `Get-DsAliasCatalog`. Doctor reporta `Alias:dsg`, etc. El banner QUICK REF usa el mismo mapa.

| Alias | Target |
|-------|--------|
| `dsh` | `Get-DsHelp` |
| `dsd` | `Invoke-DsDoctor` |
| `dsp` | `Invoke-DsProject` |
| `dsg` | `Invoke-DsGitStatus` |
| `dsa` | `Invoke-DsAi` |
| `dsf` | `Invoke-DsFuzzyCd` |
| `dshist` | `Invoke-DsHistory` |
| `dsnote` | `Invoke-DsNote` (utilities — notas rápidas) |
| `dsreport` | `Invoke-DsReport` (knowledge) |
| `dsask` | `Invoke-DsAsk` (knowledge) |
| `dssearch` | `Search-DsKnowledge` (knowledge) |
| `dsknote` | `Add-DsKnowledgeNote` (knowledge) |
| `dsconnect` | `Invoke-DsConnect` (knowledge) |

También: alias de módulo `dev` → `Invoke-DsDev` (`dev report`, `dev ask`, …).

AI: `dsa '…'` = one-shot; `dsa -Chat` = Agent TTY; `Invoke-DsIde` = GUI.

## Defaults actuales (chords)

| Chord | Acción | Módulo |
|-------|--------|--------|
| `Ctrl+Shift+P` | Command palette | keymap |
| `Ctrl+Shift+?` | Show keybindings | keymap |
| `Ctrl+Shift+G` | Fuzzy cd | navigation |
| `Ctrl+Shift+B` | Goto bookmark | navigation |
| `Ctrl+Shift+A` | Invoke AI | ai |
| `Ctrl+Shift+I` | Open IDE | ai |
| `Ctrl+Shift+O` | Project picker | projects |
| `Ctrl+Shift+S` | Git status | git |
| `Ctrl+Shift+K` | Checkout branch | git |
| `Ctrl+Shift+J` | Quick note (utilities) | utilities |
| `Ctrl+Alt+K` | Knowledge report today | knowledge |
| `Ctrl+R` | History | history |

> El banner (módulo **aesthetic**) muestra un QUICK REF de **aliases** vivos. La sección KEYS del memo es un resumen fijo; la fuente completa de chords es siempre `Show-DsKeys`.

## Notas

- Si PSReadLine no puede bindear un chord (conflicto del host), el binding sigue en el catálogo (`Invoke-DsKey -Chord ...`).
- **Windows Terminal** se queda con `Ctrl+Shift+N` (nueva ventana) y `Ctrl+Shift+V` (pegar) — DevShell no los usa.
- **Komorebi** suele usar `Alt+*` — preferimos `Ctrl+Shift+*` / aliases; Knowledge usa `Ctrl+Alt+K` para no pelear con git.
- Si un chord no llega, usá aliases (`dsa`, `dsp`, `dsreport`, `dsknote`, …).
- La palette usa `Invoke-DsFuzzy` cuando el módulo fuzzy está cargado.
