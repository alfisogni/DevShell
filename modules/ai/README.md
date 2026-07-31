# ai

Capa **genérica** de agentes. Cursor es un *provider*, no el centro del diseño.

```text
Invoke-DsAi  →  provider default (config)
                 ├── cursor   (Agent CLI)
                 ├── …        (claude / copilot / custom más adelante)
```

## One-shot vs Chat

| Flujo | Comando | Qué hace |
|-------|---------|----------|
| One-shot | `dsa 'explica este repo'` | Pasa el prompt al CLI (`agent -p "..."`) y imprime la respuesta |
| Chat | `dsa -Chat` | Lanza `agent` **sin** `-p` (TTY interactivo del Agent) |
| IDE | `Invoke-DsIde` | Abre Cursor/VS Code GUI |

Sin argumentos, `dsa` / `Invoke-DsAi` muestra un hint y pide `AI prompt` (sigue siendo one-shot, no un chat de PowerShell).

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Invoke-DsAi 'prompt'` / `dsa '…'` | One-shot al provider default |
| `Invoke-DsAi -Chat` / `dsa -Chat` | Sesión Agent interactiva |
| `Invoke-DsAi -Provider cursor ...` | Fuerza un backend |
| `Get-DsAiProvider` | Lista providers registrados |
| `Test-DsAiProvider` | ¿El default está disponible? |
| `Invoke-DsIde [path]` | Abre IDE gráfico bajo demanda |
| `Register-DsAiProvider` | Enchufa otro backend |

## Keys

| Chord | Acción |
|-------|--------|
| `Ctrl+Shift+A` | `Invoke-DsAi` (one-shot con prompt) |
| `Ctrl+Shift+I` | `Invoke-DsIde` |

Windows Terminal puede interceptar `Ctrl+Shift+*` — si el chord no llega, usá `dsa` / `Show-DsKeys`.

## Config (`user.psd1`)

```powershell
Ai = @{
    DefaultProvider = 'cursor'
    IdeCommand = 'cursor'   # o 'code'
    Providers = @{
        cursor = @{
            CliPath = 'C:\path\to\agent.exe'
            # Args = @('-p')  # override de invocación one-shot
        }
    }
}
```

## Agregar otro provider

Creá `modules/ai/providers/mi-ia.ps1` que llame `Register-DsAiProvider`, o un módulo hermano que registre el provider en `OnLoad`.

## Par CLI ↔ IDE

| IDE | CLI |
|-----|-----|
| Chat / Agent panel | `dsa -Chat` / `Invoke-DsAi -Chat` |
| One-shot print | `dsa '…'` / `Invoke-DsAi '…'` |
| Abrir ventana Cursor/VS Code | `Invoke-DsIde` |
