#requires -Version 7.0
# projects — índice de carpetas bajo ProjectRoots y jump fuzzy.

function Get-DsProjectRoot {
    [CmdletBinding()]
    param()
    $roots = @(Get-DsConfig -Path 'ProjectRoots')
    if (-not $roots -or $roots.Count -eq 0) {
        $roots = @('~/source')
    }
    foreach ($r in $roots) {
        if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
            Expand-DsPath -Path $r
        }
        else {
            if ($r.StartsWith('~/') -or $r -eq '~') {
                Join-Path $HOME ($r.Substring(1).TrimStart('\', '/'))
            }
            else { $r }
        }
    }
}

function Get-DsProject {
    <#
    .SYNOPSIS
      Lista proyectos (directorios de primer nivel bajo ProjectRoots).
      Si un dir tiene .git, se marca IsRepo.
    #>
    [CmdletBinding()]
    param(
        [switch]$ReposOnly
    )

    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($root in Get-DsProjectRoot) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $isRepo = Test-Path -LiteralPath (Join-Path $_.FullName '.git')
            if ($ReposOnly -and -not $isRepo) { return }
            $list.Add([pscustomobject]@{
                Name   = $_.Name
                Path   = $_.FullName
                Root   = $root
                IsRepo = $isRepo
            }) | Out-Null
        }
    }
    return @($list | Sort-Object Name)
}

function Set-DsProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Get-Command Set-DsLocation -ErrorAction SilentlyContinue) {
        Set-DsLocation -Path $Path
    }
    else {
        Set-Location -LiteralPath $Path
    }

    try {
        Set-DsContext -Properties @{
            Project  = Split-Path -Leaf $Path
            Location = $Path
        }
    }
    catch { }
}

function Invoke-DsProject {
    [CmdletBinding()]
    param(
        [string]$Filter,
        [switch]$ReposOnly
    )

    $projects = @(Get-DsProject -ReposOnly:$ReposOnly)
    if ($Filter) {
        $projects = @($projects | Where-Object { $_.Name -like "*$Filter*" })
    }

    if ($projects.Count -eq 0) {
        $roots = @(Get-DsProjectRoot) -join ', '
        Write-Host "No projects under: $roots" -ForegroundColor Yellow
        return
    }

    if ($projects.Count -eq 1 -and $Filter) {
        Set-DsProject -Path $projects[0].Path
        Write-Host "→ $($projects[0].Path)" -ForegroundColor Green
        return
    }

    $items = $projects | ForEach-Object {
        $mark = if ($_.IsRepo) { '*' } else { ' ' }
        "$mark $($_.Name)`t$($_.Path)"
    }

    $pick = Invoke-DsFuzzy -Items @($items) -Prompt 'project'
    if (-not $pick) { return }
    $path = ($pick -split "`t", 2)[1]
    if ($path) {
        Set-DsProject -Path $path.Trim()
        Write-Host "→ $path" -ForegroundColor Green
    }
}

function Register-DsProjectsOnLoad {
    Write-DsLog -Level Debug -Module projects -Message 'projects ready'
}

function Register-DsProjectsKeys {
    $null = Register-DsKey -Chord 'Ctrl+Shift+O' -Module projects -Description 'Open project (Invoke-DsProject)' -Action {
        Invoke-DsProject
    }
}

Export-ModuleMember -Function @(
    'Get-DsProject',
    'Get-DsProjectRoot',
    'Set-DsProject',
    'Invoke-DsProject',
    'Register-DsProjectsOnLoad',
    'Register-DsProjectsKeys'
)
