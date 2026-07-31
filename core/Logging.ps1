#requires -Version 7.0
# Logging.ps1 — niveles simples, sin sinks externos.

$script:DsLogLevel = 'Info'
$script:DsLogLevels = @{
    Debug = 0
    Info  = 1
    Warn  = 2
    Error = 3
}

function Set-DsLogLevel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Debug', 'Info', 'Warn', 'Error')]
        [string]$Level
    )
    $script:DsLogLevel = $Level
}

function Write-DsLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Debug', 'Info', 'Warn', 'Error')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Module = 'core'
    )

    $current = $script:DsLogLevels[$script:DsLogLevel]
    $msgLevel = $script:DsLogLevels[$Level]
    if ($msgLevel -lt $current) { return }

    $color = switch ($Level) {
        'Debug' { 'DarkGray' }
        'Info'  { 'Gray' }
        'Warn'  { 'Yellow' }
        'Error' { 'Red' }
    }

    $prefix = "[DevShell:$Module][$Level]"
    Write-Host "$prefix $Message" -ForegroundColor $color
}
