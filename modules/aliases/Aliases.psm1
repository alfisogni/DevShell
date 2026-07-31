#requires -Version 7.0
# aliases — atajos opt-in, seguros, fuente de verdad del quick-ref.

$script:DsAliasCatalog = [ordered]@{
    dsh     = @{ Target = 'Get-DsHelp';          Description = 'help' }
    dsd     = @{ Target = 'Invoke-DsDoctor';      Description = 'doctor' }
    dsp     = @{ Target = 'Invoke-DsProject';     Description = 'project' }
    dsg     = @{ Target = 'Invoke-DsGitStatus';   Description = 'git status' }
    dsa     = @{ Target = 'Invoke-DsAi';          Description = 'AI agent' }
    dsreport= @{ Target = 'Invoke-DsReport';      Description = 'knowledge report' }
    dsask   = @{ Target = 'Invoke-DsAsk';         Description = 'ask knowledge + AI' }
    dssearch= @{ Target = 'Search-DsKnowledge';   Description = 'search knowledge' }
    dsknote = @{ Target = 'Add-DsKnowledgeNote';  Description = 'knowledge note' }
    dsconnect = @{ Target = 'Invoke-DsConnect';   Description = 'connect provider' }
    dsf     = @{ Target = 'Invoke-DsFuzzyCd';     Description = 'fuzzy cd' }
    dshist  = @{ Target = 'Invoke-DsHistory';     Description = 'history' }
    dsnote  = @{ Target = 'Invoke-DsNote';        Description = 'quick note' }
}

$script:DsAliasStatus = [System.Collections.Generic.List[object]]::new()

function Get-DsAliasCatalog {
    [CmdletBinding()]
    param()

    $map = [ordered]@{}
    foreach ($k in $script:DsAliasCatalog.Keys) {
        $map[$k] = $script:DsAliasCatalog[$k]
    }

    $extra = $null
    try { $extra = Get-DsConfig -Path 'Aliases.Map' } catch { }
    if ($extra -is [hashtable]) {
        foreach ($k in $extra.Keys) {
            $val = $extra[$k]
            if ($val -is [hashtable]) {
                $map[$k] = @{
                    Target      = [string]$val.Target
                    Description = if ($val.Description) { [string]$val.Description } else { [string]$val.Target }
                }
            }
            else {
                $map[$k] = @{
                    Target      = [string]$val
                    Description = [string]$val
                }
            }
        }
    }
    return $map
}

function Get-DsAlias {
    <#
    .SYNOPSIS
      Estado de aliases DevShell (nombre → target → OK/conflicto/missing).
    #>
    [CmdletBinding()]
    param()

    if ($script:DsAliasStatus.Count -gt 0) {
        return @($script:DsAliasStatus)
    }

    # Fresh probe if never enabled
    $catalog = Get-DsAliasCatalog
    foreach ($name in $catalog.Keys) {
        $target = [string]$catalog[$name].Target
        $desc = [string]$catalog[$name].Description
        $existing = Get-Command $name -ErrorAction SilentlyContinue
        $targetCmd = Get-Command $target -ErrorAction SilentlyContinue
        $status = 'missing-target'
        $detail = $target
        if ($targetCmd) {
            if (-not $existing) {
                $status = 'not-set'
            }
            elseif ($existing.CommandType -eq 'Alias' -and $existing.Definition -eq $target) {
                $status = 'ok'
            }
            elseif ($existing.CommandType -eq 'Alias') {
                $status = 'conflict'
                $detail = "alias->$($existing.Definition) (wanted $target)"
            }
            else {
                $status = 'conflict'
                $detail = "$($existing.CommandType) exists (wanted alias->$target)"
            }
        }
        [pscustomobject]@{
            Name        = $name
            Target      = $target
            Description = $desc
            Status      = $status
            Detail      = $detail
            Ok          = ($status -eq 'ok')
        }
    }
}

function Enable-DsAliases {
    [CmdletBinding()]
    param()

    $enabled = $true
    $force = $false
    try {
        $cfgEnabled = Get-DsConfig -Path 'Aliases.Enabled'
        if ($null -ne $cfgEnabled) { $enabled = [bool]$cfgEnabled }
        $cfgForce = Get-DsConfig -Path 'Aliases.Force'
        if ($null -ne $cfgForce) { $force = [bool]$cfgForce }
    }
    catch { }

    if (-not $enabled) {
        Write-DsLog -Level Debug -Module aliases -Message 'aliases disabled by config'
        return @()
    }

    $catalog = Get-DsAliasCatalog
    $script:DsAliasStatus = [System.Collections.Generic.List[object]]::new()
    $applied = [System.Collections.Generic.List[string]]::new()

    foreach ($aliasName in $catalog.Keys) {
        $entry = $catalog[$aliasName]
        $target = [string]$entry.Target
        $desc = [string]$entry.Description
        $targetCmd = Get-Command $target -ErrorAction SilentlyContinue

        if (-not $targetCmd) {
            Write-DsLog -Level Warn -Module aliases -Message "Alias '$aliasName' skipped: target '$target' not found"
            $script:DsAliasStatus.Add([pscustomobject]@{
                Name = $aliasName; Target = $target; Description = $desc
                Status = 'missing-target'; Detail = $target; Ok = $false
            }) | Out-Null
            continue
        }

        $existing = Get-Command $aliasName -ErrorAction SilentlyContinue
        if ($existing) {
            $isOurs = ($existing.CommandType -eq 'Alias' -and $existing.Definition -eq $target)
            if (-not $isOurs -and -not $force) {
                Write-DsLog -Level Warn -Module aliases -Message "Alias '$aliasName' conflict; not overwriting ($($existing.CommandType))"
                $script:DsAliasStatus.Add([pscustomobject]@{
                    Name = $aliasName; Target = $target; Description = $desc
                    Status = 'conflict'
                    Detail = "$($existing.CommandType):$($existing.Definition)"
                    Ok = $false
                }) | Out-Null
                continue
            }
        }

        Set-Alias -Name $aliasName -Value $target -Scope Global -Force -ErrorAction SilentlyContinue
        $applied.Add($aliasName) | Out-Null
        $script:DsAliasStatus.Add([pscustomobject]@{
            Name = $aliasName; Target = $target; Description = $desc
            Status = 'ok'; Detail = $target; Ok = $true
        }) | Out-Null
    }

    Write-DsLog -Level Debug -Module aliases -Message ("aliases ok: " + ($applied -join ', '))
    return @($script:DsAliasStatus)
}

function Register-DsAliasesOnLoad {
    # Aliases target other modules — only apply after all modules are loaded.
    if (Get-Command Register-DsEvent -ErrorAction SilentlyContinue) {
        Register-DsEvent -Name ModulesLoaded -Handler {
            $null = Enable-DsAliases
        }
        Write-DsLog -Level Debug -Module aliases -Message 'aliases deferred until ModulesLoaded'
        return
    }
    $null = Enable-DsAliases
}

Export-ModuleMember -Function @(
    'Get-DsAliasCatalog',
    'Get-DsAlias',
    'Enable-DsAliases',
    'Register-DsAliasesOnLoad'
)
