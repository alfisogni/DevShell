#requires -Version 7.0
<#
.SYNOPSIS
  Crea un módulo DevShell desde modules/_template.
.EXAMPLE
  .\scripts\New-DevShellModule.ps1 -Name weather
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z][a-z0-9-]*$')]
    [string]$Name,

    [string]$Description = "DevShell module '$Name'",

    [string[]]$DependsOn = @(),

    [switch]$Force
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$template = Join-Path $repoRoot 'modules\_template'
$dest = Join-Path $repoRoot "modules\$Name"

if (-not (Test-Path -LiteralPath $template)) {
    throw "Template not found: $template"
}
if ((Test-Path -LiteralPath $dest) -and -not $Force) {
    throw "Module already exists: $dest (use -Force to overwrite)"
}

$pascal = (($Name -split '[-_]') | ForEach-Object {
    $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()
}) -join ''

if (Test-Path -LiteralPath $dest) {
    Remove-Item -LiteralPath $dest -Recurse -Force
}
Copy-Item -LiteralPath $template -Destination $dest -Recurse -Force

# Rename Example.psm1 → Name.psm1
$example = Join-Path $dest 'Example.psm1'
$entry = Join-Path $dest "$pascal.psm1"
if (Test-Path -LiteralPath $example) {
    Move-Item -LiteralPath $example -Destination $entry -Force
}

$depsJson = if ($DependsOn.Count) {
    ($DependsOn | ForEach-Object { "    `"$_`"" }) -join ",`n"
} else { '' }

$manifest = @"
{
  "name": "$Name",
  "version": "0.1.0",
  "description": "$Description",
  "dependsOn": [
$depsJson
  ],
  "provides": ["Invoke-Ds$pascal"],
  "hooks": {
    "OnLoad": "Register-Ds${pascal}OnLoad"
  },
  "enabledByDefault": true,
  "requires": {
    "commands": [],
    "pwsh": "7.0"
  }
}
"@
Set-Content -LiteralPath (Join-Path $dest 'module.json') -Value $manifest -Encoding UTF8

$psm1 = @"
#requires -Version 7.0

function Invoke-Ds$pascal {
    [CmdletBinding()]
    param()
    Write-Host '$Name module — implement me.'
}

function Register-Ds${pascal}OnLoad {
    Write-DsLog -Level Debug -Module $Name -Message '$Name OnLoad'
}

Export-ModuleMember -Function Invoke-Ds$pascal, Register-Ds${pascal}OnLoad
"@
Set-Content -LiteralPath $entry -Value $psm1 -Encoding UTF8

$readme = @"
# $Name

$Description

## Comandos

| Comando | Descripción |
|---------|-------------|
| ``Invoke-Ds$pascal`` | TODO |

## Par CLI ``↔`` IDE

| IDE / GUI | CLI |
|-----------|-----|
| TODO | ``Invoke-Ds$pascal`` |

## Reemplazo

Deshabilitá en ``config/modules.psd1`` y poné otro módulo con el mismo rol.
"@
Set-Content -LiteralPath (Join-Path $dest 'README.md') -Value $readme -Encoding UTF8

Set-Content -LiteralPath (Join-Path $dest 'config.psd1') -Value "@{`n    # $Name defaults`n}`n" -Encoding UTF8

Write-Host "Created modules\$Name" -ForegroundColor Green
Write-Host "Next: implement $entry and enable in config/modules.psd1 if needed."
