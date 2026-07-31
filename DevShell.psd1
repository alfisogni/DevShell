@{
    ModuleVersion = '0.1.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'DevShell'
    Description = 'Modular keyboard-first developer shell for Windows (PowerShell 7)'
    PowerShellVersion = '7.0'
    RootModule = 'DevShell.psm1'
    FunctionsToExport = @(
        'Get-DsHome'
        'Get-DsHelp'
        'Show-DsStatus'
        'Start-DevShell'
        'Show-DsStartupBanner'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
