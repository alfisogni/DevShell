# Contrato de módulo

Todo módulo vive en `modules/<name>/` y es **independiente, documentado y reemplazable**.

## Layout obligatorio

```text
modules/<name>/
├── module.json     # metadata + contrato
├── <Name>.psm1     # implementación (PascalCase del name)
├── README.md       # propósito, comandos, keys, par CLI↔IDE
├── config.psd1     # defaults del módulo
└── tests/          # opcional, recomendado
```

## `module.json`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | id único (carpeta) |
| `version` | semver | versión del módulo |
| `description` | string | una línea |
| `dependsOn` | string[] | otros `name` (no paths) |
| `provides` | string[] | comandos/funciones públicas |
| `hooks` | object | nombre de hook → función a invocar |
| `enabledByDefault` | bool | default si no está en `modules.psd1` |
| `requires.commands` | string[] | CLIs externos necesarios |
| `requires.pwsh` | string | versión mínima sugerida |

Hooks previstos: `OnLoad`, `OnKeymap`, `OnPrompt`, `OnUnload`.

## API pública

- Prefijo `Ds` / verbos PowerShell aprobados (`Get-`, `Invoke-`, `Set-`, `Register-`).
- Exportar solo lo listado en `provides` (cuando el loader lo soporte).
- No importar otros `modules/*` directamente.

## Documentación del módulo

El README debe incluir:

1. Qué problema resuelve.
2. Comandos principales.
3. Keybindings (si aplica).
4. **Par CLI ↔ IDE** (qué harías en el IDE y cómo se hace aquí).
5. Cómo reemplazarlo.

## Reemplazo

1. Deshabilitar en `config/modules.psd1`.
2. Instalar otro módulo que cumpla `provides` / el mismo rol.
3. Reiniciar sesión pwsh.

Plantilla: [`modules/_template/`](../modules/_template/).
