# Core — decisiones de diseño (anti-sobreingeniería)

## Qué hay

| Pieza | Forma | Por qué no más |
|-------|--------|----------------|
| Logging | funciones + nivel global | Sin sinks/serilog |
| Config | merge hashtable PSD1 | Sin schema engine |
| Events | hashtable nombre → lista de scriptblocks | Sin EventBus con tipado |
| Manifest | validación de campos requeridos en JSON | Sin JSON Schema library |
| Loader | discover → validate → topo-sort → import → hooks | Sin plugin sandbox |
| Context | PSCustomObject de sesión (`Get-DsContext`) | Opcional; módulos no obligados a usarlo |
| Keymap | registro en core (API) | La UI/palette vive en módulo `keymap` |

## Qué no hay a propósito

- Contenedor DI / IoC
- Objeto global gigante mutable por todos
- Dependencias directas módulo→módulo (solo `dependsOn` + hooks del core)
- Acoplamiento a Oh My Posh / Starship / fzf (adapters en módulos)

Ver [docs/architecture.md](../docs/architecture.md).
