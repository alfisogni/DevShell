# aliases

Atajos cortos **opt-in** (no reemplazan `git`/`ls` del sistema).

Fuente de verdad: `Get-DsAliasCatalog` / `Get-DsAlias`. El QUICK REF del banner usa el mismo mapa.

| Alias | Comando |
|-------|---------|
| `dsh` | `Get-DsHelp` |
| `dsd` | `Invoke-DsDoctor` |
| `dsp` | `Invoke-DsProject` |
| `dsg` | `Invoke-DsGitStatus` |
| `dsa` | `Invoke-DsAi` |
| `dsf` | `Invoke-DsFuzzyCd` |
| `dshist` | `Invoke-DsHistory` |
| `dsnote` | `Invoke-DsNote` (utilities) |
| `dsreport` | `Invoke-DsReport` (knowledge) |
| `dsask` | `Invoke-DsAsk` (knowledge) |
| `dssearch` | `Search-DsKnowledge` (knowledge) |
| `dsknote` | `Add-DsKnowledgeNote` (knowledge) |
| `dsconnect` | `Invoke-DsConnect` (knowledge) |

Knowledge también exporta el alias `dev` (`dev report`, `dev ask`, …) desde el módulo `knowledge`, no desde este catálogo.

```powershell
Get-DsAlias          # nombre → target → OK/conflicto
Invoke-DsDoctor      # checks Alias:dsg, Alias:dsreport, …
```

Desactivar o forzar overwrite en `user.psd1`:

```powershell
Aliases = @{
    Enabled = $true
    Force   = $false   # $true = pisar comandos existentes
}
```
