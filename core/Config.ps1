#requires -Version 7.0
# Config.ps1 — merge profundo de hashtables PSD1.

$script:DsConfig = $null

function Read-DsPsd1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) { return @{} }
    $data = Import-PowerShellDataFile -LiteralPath $Path
    if ($null -eq $data) { return @{} }
    return $data
}

function Merge-DsHashtable {
    [CmdletBinding()]
    param(
        [hashtable]$Base = @{},
        [hashtable]$Override = @{}
    )

    $result = @{}
    foreach ($key in $Base.Keys) {
        $result[$key] = $Base[$key]
    }

    foreach ($key in $Override.Keys) {
        $baseVal = $result[$key]
        $overVal = $Override[$key]
        if ($baseVal -is [hashtable] -and $overVal -is [hashtable]) {
            $result[$key] = Merge-DsHashtable -Base $baseVal -Override $overVal
        }
        else {
            $result[$key] = $overVal
        }
    }
    return $result
}

function Initialize-DsConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HomePath
    )

    $configDir = Join-Path $HomePath 'config'
    $defaults = Read-DsPsd1 (Join-Path $configDir 'defaults.psd1')
    $modules  = Read-DsPsd1 (Join-Path $configDir 'modules.psd1')
    $user     = Read-DsPsd1 (Join-Path $configDir 'user.psd1')

    $merged = Merge-DsHashtable -Base $defaults -Override @{ Modules = $modules }
    $merged = Merge-DsHashtable -Base $merged -Override $user

    $script:DsConfig = $merged
    if ($merged.LogLevel) {
        Set-DsLogLevel -Level $merged.LogLevel
    }
    Write-DsLog -Level Debug -Module config -Message "Config loaded from $configDir"
    return $script:DsConfig
}

function Get-DsConfig {
    [CmdletBinding()]
    param(
        [string]$Path
    )
    if ($null -eq $script:DsConfig) {
        throw 'DevShell config not initialized. Call Start-DevShell first.'
    }
    if (-not $Path) { return $script:DsConfig }

    $parts = $Path -split '\.'
    $node = $script:DsConfig
    foreach ($p in $parts) {
        if ($node -is [hashtable] -and $node.ContainsKey($p)) {
            $node = $node[$p]
        }
        else {
            return $null
        }
    }
    return $node
}
