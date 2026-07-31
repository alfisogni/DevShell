#requires -Version 7.0
<#
.SYNOPSIS
  Enlaza DevShell al perfil de pwsh de forma idempotente.
#>
[CmdletBinding()]
param(
    [switch]$WhatIf
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$initPath = Join-Path $root 'init.ps1'
$line = ". '$($initPath.Replace("'", "''"))'"

$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path -LiteralPath $profileDir)) {
    if ($WhatIf) {
        Write-Host "Would create profile directory: $profileDir"
    }
    else {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
}

$existing = ''
if (Test-Path -LiteralPath $profilePath) {
    $existing = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $existing) { $existing = '' }
}

if ($existing -match [regex]::Escape($initPath)) {
    Write-Host "DevShell ya está en el profile:`n  $profilePath" -ForegroundColor Green
    return
}

$block = @"

# DevShell
$line
"@

if ($WhatIf) {
    Write-Host "Would append to $profilePath :"
    Write-Host $block
    return
}

Add-Content -LiteralPath $profilePath -Value $block -Encoding UTF8
Write-Host "DevShell instalado en:`n  $profilePath" -ForegroundColor Green
Write-Host "Abrí una nueva sesión pwsh para usarlo."
