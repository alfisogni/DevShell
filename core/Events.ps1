#requires -Version 7.0
# Events.ps1 — pub/sub mínimo por nombre de hook.

$script:DsEventHandlers = @{}

function Register-DsEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )

    if (-not $script:DsEventHandlers.ContainsKey($Name)) {
        $script:DsEventHandlers[$Name] = [System.Collections.Generic.List[scriptblock]]::new()
    }
    $script:DsEventHandlers[$Name].Add($Handler) | Out-Null
}

function Clear-DsEvents {
    [CmdletBinding()]
    param()
    $script:DsEventHandlers = @{}
}

function Invoke-DsEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [object[]]$ArgumentList = @()
    )

    if (-not $script:DsEventHandlers.ContainsKey($Name)) { return }

    foreach ($handler in @($script:DsEventHandlers[$Name])) {
        try {
            if ($ArgumentList.Count -gt 0) {
                & $handler @ArgumentList
            }
            else {
                & $handler
            }
        }
        catch {
            Write-DsLog -Level Warn -Module events -Message "Handler for '$Name' failed: $($_.Exception.Message)"
        }
    }
}

function Get-DsEventNames {
    [CmdletBinding()]
    param()
    @($script:DsEventHandlers.Keys)
}
