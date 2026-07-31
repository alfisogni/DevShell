#requires -Version 7.0
# Manifest.ps1 — validación mínima de module.json

function Read-DsModuleManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $json = $raw | ConvertFrom-Json
    return $json
}

function Test-DsModuleManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [string]$DirectoryName
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    foreach ($field in @('name', 'version', 'description')) {
        if (-not $Manifest.$field) {
            $errors.Add("Missing required field '$field'") | Out-Null
        }
    }

    if ($DirectoryName -and $Manifest.name -and $Manifest.name -ne $DirectoryName) {
        $errors.Add("Manifest name '$($Manifest.name)' does not match folder '$DirectoryName'") | Out-Null
    }

    if ($null -eq $Manifest.dependsOn) {
        $Manifest | Add-Member -NotePropertyName dependsOn -NotePropertyValue @() -Force
    }
    elseif ($Manifest.dependsOn -isnot [System.Array]) {
        $Manifest.dependsOn = @($Manifest.dependsOn)
    }

    if ($null -eq $Manifest.hooks) {
        $Manifest | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    if ($null -eq $Manifest.enabledByDefault) {
        $Manifest | Add-Member -NotePropertyName enabledByDefault -NotePropertyValue $true -Force
    }

    return [pscustomobject]@{
        Ok     = ($errors.Count -eq 0)
        Errors = @($errors)
        Manifest = $Manifest
    }
}
