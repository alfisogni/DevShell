function Invoke-DsExample {
    [CmdletBinding()]
    param()
    Write-Host "Example module — replace this implementation."
}

function Register-DsExampleOnLoad {
    # Called by core OnLoad hook (Fase 1+)
}

function Register-DsExampleKeys {
    # Register-DsKey ... (Fase 2+)
}

Export-ModuleMember -Function Invoke-DsExample
