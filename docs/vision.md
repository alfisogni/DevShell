# DevShell Vision 2.0

> Documento canónico de producto. Toda feature nueva, PR y decisión de diseño debe alinearse con esto.
> Si una mejora no hace que el entorno completo se sienta más integrado, probablemente no pertenece a DevShell.

## Filosofía

DevShell **no** es:

- una terminal
- una configuración de PowerShell
- un intento de copiar Linux

**DevShell es un Developer Operating Environment.**

Su objetivo es que todo el entorno de trabajo se sienta como **un único sistema coherente**.

---

## Principios

### 1. CLI First

Todo debe poder hacerse desde la terminal.

La interfaz gráfica es un complemento. Nunca una dependencia.

### 2. IDE Optional

Cursor, VS Code, Neovim, Visual Studio — todos **consumen** DevShell.

Ninguno **define** DevShell.

### 3. AI Agnostic

La IA nunca es el centro. Es una capacidad.

Hoy Cursor. Mañana Claude. Después OpenAI / Copilot / Gemini.

Todos funcionan igual mediante **providers** (`Register-DsAiProvider`).

### 4. Knowledge First

El activo más importante no son los prompts.

Es el **conocimiento generado**.

Los reportes son una **vista** del conocimiento. Nunca al revés.

Ver [knowledge.md](knowledge.md) y [knowledge-agents.md](knowledge-agents.md).

### 5. Everything Modular

Todo puede agregarse. Todo puede quitarse.

Nada debe romper el sistema. Contrato: [module-contract.md](module-contract.md).

### 6. Fail Soft

Un módulo roto nunca rompe la shell.

Se deshabilita / se omite con warning. La sesión sigue.

---

## Golden Rule

Cada feature nueva debe responder:

> ¿Hace que el entorno completo se sienta más integrado?

Si la respuesta es **no**, probablemente no pertenece a DevShell.

---

## Objetivo de producto (para agentes / Cursor)

> **Transformar DevShell en un entorno de desarrollo con una identidad visual propia, donde diseño, productividad, automatización, conocimiento e IA formen un único sistema coherente. Cada mejora debe reforzar esa sensación de ecosistema, priorizando la experiencia diaria del desarrollador por encima de agregar funcionalidades aisladas.**

No “hacer la shell más linda”. Tomar decisiones alineadas con este rumbo.

---

## Design Language (Lennerk)

No queremos una terminal bonita. Queremos una **identidad visual**.

Todo debe sentirse del mismo ecosistema. Nada que parezca de proyectos distintos.

### Color System

Una sola paleta. **Lennerk Dark** (basada en Catppuccin Mocha).

Los colores representan **significado**, no decoración:

| Token | Rol semántico | Dirección |
|-------|---------------|-----------|
| Primary | Identidad / énfasis principal | Green |
| Interactive | Acciones, links, focus | Cyan |
| Knowledge | Memoria, journal, grafo | Purple |
| Warning | Riesgo, atención | Yellow |
| Error | Fallo | Red |
| Muted | Meta, hints | Gray |
| Bg / Fg | Superficie / texto | Dark / Light |

> **Estado hoy:** el tema `default` usa verde `#00C853` sobre negro `#0A0A0A` (pre–Lennerk). Migrar a Lennerk Dark es trabajo de Vision 2.0, no reescribir historia: el módulo `aesthetic` + `themes/` es el vehículo.

### Typography

Fuente única del sistema: **JetBrainsMono Nerd Font**.

### Iconografía

Solo **Nerd Fonts**. Sin emojis. Sin mezclar estilos.

Cada módulo posee un icono (Knowledge, Projects, Git, Docker, AI, Workspace, Files, Search, History, Settings, …).

### Spacing & layout

Muchísimo aire. Nada comprimido.

Toda salida importante usa **bloques / paneles textuales**, no líneas `Key: value` apretadas.

```text
Git
────────────────────────
Branch
  feature/design
Status
  Clean
```

Aunque sea texto, debe sentirse **organizado como paneles**.

### Motion

Sin exagerar: loading, spinners, progress, fade textual. Nada invasivo.

---

## Experiencias objetivo

### Startup → Dashboard

El arranque no es solo un banner. Evoluciona a **dashboard**:

```text
DevShell
Git · Current Project · Knowledge · AI Provider
Workspace · Recent Notes · Quick Commands · Keybindings
```

Todo alineado. Sensación de “arrancar un sistema operativo”, no de “abrir PowerShell”.

Flujo deseado:

```text
Banner / Dashboard → Health → Workspace → Git → Knowledge → Tips → Prompt
```

### Prompt

Minimalista en ruido, denso en señal: proyecto, git, stack, AI provider, knowledge ready, prompt corto.

### Workspaces

Entorno completo nombrado (`dev workspace work`): layout (Komorebi), proyectos, terminales, módulos, editor, variables, AI, Knowledge context.

### Terminal layouts

Integración profunda con Windows Terminal: 2 / 3 / 4 paneles con propósito (Git | Neovim | Logs, AI | Shell, …).

### Editor de referencia

**Neovim** = editor natural dentro de DevShell (CLI-first).

Cursor IDE / VS Code siguen siendo excelentes y **opcionales** — consumen DevShell, no lo definen.

### Ecosistema TUI

Priorizar herramientas que compartan estética: Neovim, Yazi, Lazygit, Btop, fzf, ripgrep, bat, zoxide, delta, dust, bottom, spotify-player, …

---

## Lennerk Ecosystem (largo plazo)

```text
Lennerk Ecosystem
│
├── DevShell              Developer Operating Environment
├── Knowledge Engine      Persistent Memory Layer
├── NeordStation          Visual Knowledge Interface
├── Lennerk Design System Design Language
└── AI Providers          Cursor · Claude · OpenAI · Copilot · Gemini
```

DevShell es el **DOE** de ese ecosistema, no un script aislado.

---

## Mapa: hoy vs Vision 2.0

| Área | Hoy (shipped) | Vision 2.0 (rumbo) |
|------|---------------|--------------------|
| Producto | Shell modular PS7 | Developer Operating Environment |
| Estética | Banner + tokens verdes `default` | Lennerk Dark (`themes/lennerk`) + packs + dashboard |
| Startup | Banner + QUICK REF | Dashboard de sistema (`SidePanel = dashboard`) |
| Knowledge | Módulo KE + journal/grafo | Capa de memoria central del DOE |
| AI | Providers (`cursor`, …) | Misma abstracción, más backends |
| Workspaces | Projects + navigation stack | Workspace completo (layout/editor/AI/KE) |
| WT layouts | Manual | Lanzamiento declarativo de paneles |
| Editor | IDE on demand (`Invoke-DsIde`) | Neovim como default CLI; IDE optional |
| TUI | fzf + git CLI | Suite TUI (yazi/lazygit/btop/…) vía `tools` + aliases |

Implementar Vision 2.0 es **incremental**. No mezclar “todo el dashboard” en un solo PR. Cada PR debe citar qué principio / fila de esta tabla avanza.

---

## Cómo usarlo (humanos y agentes)

1. Leer este archivo antes de diseñar o codear features grandes.
2. Preferir cambios que unifiquen sensación de ecosistema.
3. Respetar fail soft + modularidad + CLI-first.
4. Knowledge First: no inventar; reportes ⊂ conocimiento.
5. Aesthetic changes van a `aesthetic` + `themes/` (Design Language), no a hardcodes sueltos en cada módulo.
6. Actualizar esta tabla “hoy vs Vision 2.0” cuando una fila pase a shipped.

Docs relacionados: [architecture.md](architecture.md) · [aesthetic.md](aesthetic.md) · [workflow-cli-first.md](workflow-cli-first.md) · [knowledge.md](knowledge.md) · [roadmap.md](roadmap.md)
