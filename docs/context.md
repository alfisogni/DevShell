# DevShell session context (optional)

`DsContext` is a **lightweight** session snapshot, not a mandatory dependency for modules.

## Shape

```powershell
[pscustomobject]@{
    Home          = 'C:\Users\...\devshell'
    Location      = (Get-Location).Path
    Project       = $null          # set by projects module when known
    Theme         = 'default'
    LoadedModules = @('doctor')
    Tools         = @{ git = $true; fzf = $false }  # capability hints
    StartedAt     = (Get-Date)
}
```

## API

- `Get-DsContext` — read current snapshot
- `Set-DsContext` — shallow merge of properties (core / trusted modules)
- `Update-DsContextLocation` — refresh `Location` from `Get-Location`

## Rules

1. Modules **may** read context; they must not require it to load.
2. No deep nested domain model in v1.
3. Tools map is advisory (doctor / tools modules fill it), not a package manager.
