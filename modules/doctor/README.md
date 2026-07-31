# doctor

Diagnóstico del entorno: versión de PowerShell, home, tema, módulos cargados y herramientas opcionales.

## Comandos

| Comando | Descripción |
|---------|-------------|
| `Invoke-DsDoctor` | Corre checks y muestra resumen |

## Par CLI ↔ IDE

| IDE / GUI | CLI |
|-----------|-----|
| Settings / Extensions health | `Invoke-DsDoctor` |

## Reemplazo

Deshabilitá `doctor` en `config/modules.psd1` y poné otro módulo con el mismo rol.
