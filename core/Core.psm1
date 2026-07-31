#requires -Version 7.0
# Core.psm1 — agrega el kernel. Dot-source de piezas internas.

$coreRoot = $PSScriptRoot

. (Join-Path $coreRoot 'Logging.ps1')
. (Join-Path $coreRoot 'Config.ps1')
. (Join-Path $coreRoot 'Events.ps1')
. (Join-Path $coreRoot 'Context.ps1')
. (Join-Path $coreRoot 'Manifest.ps1')
. (Join-Path $coreRoot 'Keymap.ps1')
. (Join-Path $coreRoot 'Loader.ps1')

Export-ModuleMember -Function @(
    'Set-DsLogLevel',
    'Write-DsLog',
    'Initialize-DsConfig',
    'Get-DsConfig',
    'Merge-DsHashtable',
    'Read-DsPsd1',
    'Register-DsEvent',
    'Clear-DsEvents',
    'Invoke-DsEvent',
    'Get-DsEventNames',
    'Initialize-DsContext',
    'Get-DsContext',
    'Set-DsContext',
    'Update-DsContextLocation',
    'Add-DsLoadedModule',
    'Read-DsModuleManifest',
    'Test-DsModuleManifest',
    'Register-DsKey',
    'Get-DsKeyBinding',
    'Invoke-DsKey',
    'Clear-DsKeyBindings',
    'Sync-DsPsReadLineKeys',
    'ConvertTo-DsPsReadLineChord',
    'Set-DsPsReadLineHandler',
    'Start-DsModuleLoader',
    'Find-DsModuleDirectories',
    'Get-DsModuleLoadOrder',
    'Get-DsEnabledModuleNames',
    'ConvertTo-DsPascalName'
)
