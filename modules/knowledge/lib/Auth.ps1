#requires -Version 7.0
# Auth helpers for knowledge providers — interactive or agent-safe skip.

function Get-DsKnowledgeCredentialPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )
    $dir = Get-DsKnowledgeCredentialsDir
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return Join-Path $dir ("{0}.json" -f $Provider.ToLowerInvariant())
}

function Get-DsKnowledgeCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )
    $path = Get-DsKnowledgeCredentialPath -Provider $Provider
    return Read-DsKnowledgeJson -Path $path -Default $null
}

function Set-DsKnowledgeCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [hashtable]$Credential
    )
    $path = Get-DsKnowledgeCredentialPath -Provider $Provider
    $payload = @{
        provider   = $Provider.ToLowerInvariant()
        updatedAt  = (Get-Date).ToString('o')
        credential = $Credential
    }
    Write-DsKnowledgeJson -Path $path -Object $payload
}

function Clear-DsKnowledgeCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )
    $path = Get-DsKnowledgeCredentialPath -Provider $Provider
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

function Request-DsKnowledgeAuth {
    <#
    .SYNOPSIS
      Ask to authenticate a provider, or skip when -NonInteractive.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [scriptblock]$Authenticate,

        [switch]$NonInteractive,

        [switch]$SkipAuth
    )

    if ($SkipAuth -or $NonInteractive) {
        Write-DsLog -Level Info -Module knowledge -Message "Skipping auth for $Provider (non-interactive)"
        return $false
    }

    $answer = Read-Host "$Provider is available but not authenticated. Sign in now? [y/N]"
    if ($answer -notmatch '^(y|yes)$') {
        return $false
    }

    try {
        & $Authenticate
        if (Test-DsKnowledgeProvider -Name $Provider -Check Auth) {
            return $true
        }
        Write-Host ("Auth for {0} did not complete. Follow the instructions above, then re-run the report." -f $Provider) -ForegroundColor Yellow
        return $false
    }
    catch {
        Write-Host "Auth failed for ${Provider}: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}
