#requires -Version 7.0
# git — comandos frecuentes y segmento de prompt (CLI-first).

function Get-DsGitRoot {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location).Path
    )
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    Push-Location -LiteralPath $Path
    try {
        $root = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) { return $null }
        return $root.Trim()
    }
    finally {
        Pop-Location
    }
}

function Get-DsGitBranch {
    [CmdletBinding()]
    param()
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    if (-not (Get-DsGitRoot)) { return $null }
    $branch = git branch --show-current 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = git rev-parse --short HEAD 2>$null
    }
    return $(if ($branch) { $branch.Trim() } else { $null })
}

function Test-DsGitDirty {
    [CmdletBinding()]
    param()
    if (-not (Get-DsGitRoot)) { return $false }
    $status = git status --porcelain 2>$null
    return -not [string]::IsNullOrWhiteSpace($status)
}

function Get-DsGitStatusSummary {
    [CmdletBinding()]
    param()
    $root = Get-DsGitRoot
    if (-not $root) { return $null }

    $branch = Get-DsGitBranch
    $porcelain = @(git status --porcelain 2>$null)
    $modified = @($porcelain | Where-Object { $_ -match '^.M|^M' }).Count
    $untracked = @($porcelain | Where-Object { $_.StartsWith('??') }).Count
    $staged = @($porcelain | Where-Object { $_ -match '^[MARC]' }).Count

    return [pscustomobject]@{
        Root      = $root
        Branch    = $branch
        Dirty     = ($porcelain.Count -gt 0)
        Staged    = $staged
        Modified  = $modified
        Untracked = $untracked
        Changes   = $porcelain.Count
    }
}

function Invoke-DsGitStatus {
    [CmdletBinding()]
    param()
    $summary = Get-DsGitStatusSummary
    if (-not $summary) {
        Write-Host 'Not a git repository.' -ForegroundColor Yellow
        return
    }

    $dirtyMark = if ($summary.Dirty) { '*' } else { '' }
    Write-Host ''
    Write-Host "  $($summary.Branch)$dirtyMark" -ForegroundColor Cyan
    Write-Host "  $($summary.Root)" -ForegroundColor DarkGray
    Write-Host ("  staged={0} modified={1} untracked={2}" -f $summary.Staged, $summary.Modified, $summary.Untracked)
    Write-Host ''
    git status -sb
}

function Invoke-DsGitBranch {
    [CmdletBinding()]
    param()
    if (-not (Get-DsGitRoot)) {
        Write-Host 'Not a git repository.' -ForegroundColor Yellow
        return
    }

    $branches = @(git branch --format='%(refname:short)' 2>$null)
    if ($branches.Count -eq 0) { return }

    $pick = $null
    if (Get-Command Invoke-DsFuzzy -ErrorAction SilentlyContinue) {
        $pick = Invoke-DsFuzzy -Items $branches -Prompt 'branch'
    }
    else {
        $pick = $branches | Select-Object -First 1
    }
    if (-not $pick) { return }
    git checkout $pick
}

function Register-DsGitPromptSegment {
    if (-not (Get-Command Register-DsPromptSegment -ErrorAction SilentlyContinue)) { return }

    Register-DsPromptSegment -Name git -Order 30 -Force -Builder {
        $branch = Get-DsGitBranch
        if (-not $branch) { return $null }
        $dirty = Test-DsGitDirty
        $sym = ''
        if (Get-Command Get-DsThemeSymbol -ErrorAction SilentlyContinue) {
            $sym = Get-DsThemeSymbol -Name Git -Default ''
        }
        $mark = if ($dirty) { '*' } else { '' }
        if ($sym) { return "$sym $branch$mark" }
        return "git:$branch$mark"
    }
}

function Register-DsGitOnLoad {
    Register-DsGitPromptSegment
    Write-DsLog -Level Debug -Module git -Message 'git ready'
}

function Register-DsGitKeys {
    $null = Register-DsKey -Chord 'Ctrl+Shift+S' -Module git -Description 'Git status (Invoke-DsGitStatus)' -Action {
        Invoke-DsGitStatus
    }
    # Avoid Ctrl+Shift+V (Windows Terminal: paste). Avoid Alt+* (Komorebi).
    $null = Register-DsKey -Chord 'Ctrl+Shift+K' -Module git -Description 'Git checkout branch (Invoke-DsGitBranch)' -Action {
        Invoke-DsGitBranch
    }
}

Export-ModuleMember -Function @(
    'Get-DsGitRoot',
    'Get-DsGitBranch',
    'Test-DsGitDirty',
    'Get-DsGitStatusSummary',
    'Invoke-DsGitStatus',
    'Invoke-DsGitBranch',
    'Register-DsGitPromptSegment',
    'Register-DsGitOnLoad',
    'Register-DsGitKeys'
)
