# Entrypoint: carga DevShell e inicia la sesión.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "DevShell requiere PowerShell 7 (pwsh). Estás en $($PSVersionTable.PSVersion)." -ForegroundColor Yellow
    Write-Host "Instalá: winget install Microsoft.PowerShell"
    Write-Host "Luego: pwsh -NoExit -File `"$root\init.ps1`""
    return
}

Import-Module (Join-Path $root 'DevShell.psd1') -Force
$null = Start-DevShell
