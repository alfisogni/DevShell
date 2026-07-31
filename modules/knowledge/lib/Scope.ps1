#requires -Version 7.0
# Report scope — include/exclude projects for Knowledge collection.

function Get-DsKnowledgeReportDefaults {
    [CmdletBinding()]
    param()

    $include = @()
    $exclude = @()
    try {
        $cfg = Get-DsConfig -Path 'Knowledge.Report'
        if ($cfg -is [hashtable]) {
            if ($cfg.IncludeProjects) { $include = @($cfg.IncludeProjects | ForEach-Object { [string]$_ }) }
            if ($cfg.ExcludeProjects) { $exclude = @($cfg.ExcludeProjects | ForEach-Object { [string]$_ }) }
        }
    }
    catch { }

    return [pscustomobject]@{
        IncludeProjects = @($include | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        ExcludeProjects = @($exclude | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
}

function New-DsKnowledgeScope {
    <#
    .SYNOPSIS
      Build a report scope from -Project / -ExcludeProject and config defaults.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Project,
        [string[]]$ExcludeProject
    )

    $defaults = Get-DsKnowledgeReportDefaults
    $split = {
        param($items)
        $out = [System.Collections.Generic.List[string]]::new()
        foreach ($item in @($items)) {
            if (-not $item) { continue }
            foreach ($part in ([string]$item -split ',')) {
                $t = $part.Trim()
                if ($t) { $out.Add($t) | Out-Null }
            }
        }
        return @($out)
    }
    $include = & $split $Project
    if ($include.Count -eq 0) { $include = @($defaults.IncludeProjects) }

    $exclude = & $split $ExcludeProject
    $exclude = @($exclude + @($defaults.ExcludeProjects) | Select-Object -Unique)
    # Include wins over exclude for the same name
    if ($include.Count -gt 0) {
        $exclude = @($exclude | Where-Object {
                $ex = $_
                -not ($include | Where-Object { $_ -eq $ex -or $_ -like $ex -or $ex -like $_ })
            })
    }

    return [pscustomobject]@{
        IncludeProjects = @($include)
        ExcludeProjects = @($exclude)
        Active          = ($include.Count -gt 0 -or $exclude.Count -gt 0)
    }
}

function Test-DsKnowledgeNameInScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        $Scope
    )

    if (-not $Scope -or -not $Scope.Active) { return $true }
    if ([string]::IsNullOrWhiteSpace($Name)) {
        # unnamed activity: only keep if no include filter (exclude-only scopes allow unnamed)
        return ($Scope.IncludeProjects.Count -eq 0)
    }

    $n = $Name.Trim()
    foreach ($ex in @($Scope.ExcludeProjects)) {
        if ($n -eq $ex -or $n -like $ex -or $ex -like $n -or $n -match [regex]::Escape($ex)) {
            return $false
        }
    }

    if ($Scope.IncludeProjects.Count -eq 0) { return $true }

    foreach ($inc in @($Scope.IncludeProjects)) {
        if ($n -eq $inc -or $n -like $inc -or $inc -like $n -or $n -match [regex]::Escape($inc)) {
            return $true
        }
    }
    return $false
}

function Test-DsKnowledgeTextInScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        $Scope
    )

    if (-not $Scope -or -not $Scope.Active) { return $true }
    $t = $Text

    foreach ($ex in @($Scope.ExcludeProjects)) {
        if ($t -match [regex]::Escape($ex)) { return $false }
    }

    if ($Scope.IncludeProjects.Count -eq 0) { return $true }

    foreach ($inc in @($Scope.IncludeProjects)) {
        if ($t -match [regex]::Escape($inc)) { return $true }
    }
    # Tagged notes anywhere in the block: [DemoApp] ...
    if ($t -match '(?m)^\s*\[([^\]]+)\]') {
        return (Test-DsKnowledgeNameInScope -Name $Matches[1] -Scope $Scope)
    }
    return $false
}

function Get-DsKnowledgeScopedProjects {
    <#
    .SYNOPSIS
      Resolve project folders for git/github collection under the current scope.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Scope
    )

    $candidates = [System.Collections.Generic.List[object]]::new()

    if (Get-Command Get-DsProject -ErrorAction SilentlyContinue) {
        foreach ($p in @(Get-DsProject)) {
            $candidates.Add($p) | Out-Null
        }
    }

    # Always consider current git root as a candidate
    if (Get-Command Get-DsGitRoot -ErrorAction SilentlyContinue) {
        $current = Get-DsGitRoot
        if ($current) {
            $name = Split-Path -Leaf $current
            $exists = $false
            foreach ($c in $candidates) {
                if ($c.Path -eq $current) { $exists = $true; break }
            }
            if (-not $exists) {
                $candidates.Add([pscustomobject]@{
                        Name   = $name
                        Path   = $current
                        Root   = Split-Path -Parent $current
                        IsRepo = $true
                    }) | Out-Null
            }
        }
    }

    $resolved = [System.Collections.Generic.List[object]]::new()
    foreach ($c in $candidates) {
        if (-not (Test-DsKnowledgeNameInScope -Name $c.Name -Scope $Scope)) { continue }
        $path = $c.Path
        $isRepo = $false
        if ($c.PSObject.Properties['IsRepo']) { $isRepo = [bool]$c.IsRepo }
        if (-not $isRepo -and (Test-Path -LiteralPath (Join-Path $path '.git'))) { $isRepo = $true }
        if (-not $isRepo) { continue }
        $resolved.Add([pscustomobject]@{
                Name = $c.Name
                Path = $path
            }) | Out-Null
    }

    # If include filters are set but nothing matched ProjectRoots, try path-like / fuzzy contains
    if ($resolved.Count -eq 0 -and $Scope.IncludeProjects.Count -gt 0) {
        foreach ($inc in $Scope.IncludeProjects) {
            foreach ($c in $candidates) {
                if ($c.Name -like "*$inc*" -or $c.Path -like "*$inc*") {
                    if (-not (Test-Path -LiteralPath (Join-Path $c.Path '.git'))) { continue }
                    $resolved.Add([pscustomobject]@{ Name = $c.Name; Path = $c.Path }) | Out-Null
                }
            }
        }
    }

    return @($resolved | Sort-Object Path -Unique)
}
