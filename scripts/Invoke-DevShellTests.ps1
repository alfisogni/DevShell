#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Path = (Join-Path $PSScriptRoot '..\tests')
)

$pester = Get-Module -ListAvailable Pester |
    Where-Object { $_.Version -ge [version]'5.0.0' } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pester) {
    Write-Host 'Instalando Pester 5+ (CurrentUser)...' -ForegroundColor Yellow
    Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.0.0 -AllowClobber
    $pester = Get-Module -ListAvailable Pester |
        Where-Object { $_.Version -ge [version]'5.0.0' } |
        Sort-Object Version -Descending |
        Select-Object -First 1
}

Import-Module -Name $pester.Path -Force
$config = New-PesterConfiguration
$config.Run.Path = (Resolve-Path $Path).Path
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
