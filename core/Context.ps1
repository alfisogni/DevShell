#requires -Version 7.0
# Context.ps1 — snapshot liviano de sesión (opcional para módulos).

$script:DsContext = $null

function Initialize-DsContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HomePath,

        [string]$Theme = 'default'
    )

    $script:DsContext = [pscustomobject]@{
        Home          = $HomePath
        Location      = (Get-Location).Path
        Project       = $null
        Theme         = $Theme
        LoadedModules = [System.Collections.Generic.List[string]]::new()
        Tools         = @{}
        StartedAt     = Get-Date
    }
}

function Get-DsContext {
    [CmdletBinding()]
    param()
    if ($null -eq $script:DsContext) {
        throw 'DevShell context not initialized. Call Start-DevShell first.'
    }
    return $script:DsContext
}

function Set-DsContext {
    [CmdletBinding()]
    param(
        [hashtable]$Properties
    )
    $ctx = Get-DsContext
    foreach ($key in $Properties.Keys) {
        if ($ctx.PSObject.Properties.Name -contains $key) {
            $ctx.$key = $Properties[$key]
        }
        else {
            $ctx | Add-Member -NotePropertyName $key -NotePropertyValue $Properties[$key] -Force
        }
    }
}

function Update-DsContextLocation {
    [CmdletBinding()]
    param()
    $ctx = Get-DsContext
    $ctx.Location = (Get-Location).Path
}

function Add-DsLoadedModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    $ctx = Get-DsContext
    if (-not $ctx.LoadedModules.Contains($Name)) {
        $ctx.LoadedModules.Add($Name) | Out-Null
    }
}
