#requires -Version 7.0
# prompt — Warp-like multi-line identity prompt (no Starship).

$script:DsPromptSegments = [System.Collections.Generic.List[object]]::new()

function Clear-DsPromptSegments {
    [CmdletBinding()]
    param()
    $script:DsPromptSegments = [System.Collections.Generic.List[object]]::new()
}

function Register-DsPromptSegment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Builder,

        [int]$Order = 100,

        [switch]$Force
    )

    $existing = @($script:DsPromptSegments | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
    if ($existing -and -not $Force) {
        Write-DsLog -Level Debug -Module prompt -Message "Segment '$Name' already registered"
        return
    }
    if ($existing -and $Force) {
        [void]$script:DsPromptSegments.Remove($existing)
    }

    $script:DsPromptSegments.Add([pscustomobject]@{
        Name    = $Name
        Builder = $Builder
        Order   = $Order
    }) | Out-Null
}

function Get-DsPromptSegment {
    [CmdletBinding()]
    param()
    @($script:DsPromptSegments | Sort-Object Order, Name)
}

function Get-DsPromptDisplayName {
    [CmdletBinding()]
    param()
    try {
        $cfg = Get-DsConfig -Path 'Prompt.DisplayName'
        if ($cfg) { return [string]$cfg }
    }
    catch { }
    if ($env:DEVSHELL_PROMPT_NAME) { return $env:DEVSHELL_PROMPT_NAME }
    return $env:USERNAME
}

function Get-DsGitRelativeTime {
    [CmdletBinding()]
    param()
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    if (-not (Get-Command Get-DsGitRoot -ErrorAction SilentlyContinue)) { return $null }
    if (-not (Get-DsGitRoot)) { return $null }
    $raw = git log -1 --format=%ct 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) { return $null }
    try {
        $epoch = [long]$raw.Trim()
        $when = [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
        $span = (Get-Date) - $when
        if ($span.TotalMinutes -lt 1) { return 'just now' }
        if ($span.TotalMinutes -lt 60) { return ('{0}m ago' -f [int]$span.TotalMinutes) }
        if ($span.TotalHours -lt 48) { return ('{0}h ago' -f [int]$span.TotalHours) }
        return ('{0}d ago' -f [int]$span.TotalDays)
    }
    catch { return $null }
}

function Get-DsPromptText {
    <#
    .SYNOPSIS
      Structured prompt payload for Warp-like rendering.
    #>
    [CmdletBinding()]
    param()

    $name = Get-DsPromptDisplayName
    $path = (Get-Location).Path
    $homePrefix = $HOME
    if ($path.StartsWith($homePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $path.Substring($homePrefix.Length).TrimStart('\', '/')
        $path = if ([string]::IsNullOrEmpty($rel)) { '~' } else { "~\$rel" }
    }

    $project = $null
    try { $project = (Get-DsContext).Project } catch { }

    $branch = $null
    $clean = $null
    if (Get-Command Get-DsGitBranch -ErrorAction SilentlyContinue) {
        try { $branch = Get-DsGitBranch } catch { }
    }
    if (Get-Command Test-DsGitDirty -ErrorAction SilentlyContinue) {
        try {
            if ($branch) {
                $clean = -not (Test-DsGitDirty)
            }
        }
        catch { }
    }
    $ago = Get-DsGitRelativeTime

    # Legacy segment builders still run for extensibility (optional extra lines)
    $extra = [System.Collections.Generic.List[string]]::new()
    foreach ($seg in (Get-DsPromptSegment)) {
        if ($seg.Name -in @('location', 'project', 'git', 'time')) { continue }
        try {
            $text = & $seg.Builder
            if ($text) { $extra.Add([string]$text) | Out-Null }
        }
        catch {
            Write-DsLog -Level Debug -Module prompt -Message "Segment $($seg.Name) failed: $($_.Exception.Message)"
        }
    }

    return [pscustomobject]@{
        Style   = 'warp'
        Name    = $name
        Path    = $path
        Project = $project
        Branch  = $branch
        Clean   = $clean
        Ago     = $ago
        Extra   = @($extra)
        Sep     = '>'
    }
}

function global:prompt {
    try {
        if (Get-Command Update-DsContextLocation -ErrorAction SilentlyContinue) {
            Update-DsContextLocation
        }
        if (-not (Get-Command Get-DsPromptText -ErrorAction SilentlyContinue)) {
            return '> '
        }

        $p = Get-DsPromptText
        $muted = 'DarkGray'
        $accent = 'Green'
        $fg = 'White'
        if (Get-Command Get-DsThemeColor -ErrorAction SilentlyContinue) {
            $muted = (Get-DsThemeColor -Role Muted).ConsoleColor
            $accent = (Get-DsThemeColor -Role Accent).ConsoleColor
            $fg = (Get-DsThemeColor -Role Fg).ConsoleColor
        }

        Write-Host ''
        Write-Host '╭─ ' -NoNewline -ForegroundColor $muted
        Write-Host $p.Name -ForegroundColor $accent
        Write-Host '│' -ForegroundColor $muted
        Write-Host '├ ' -NoNewline -ForegroundColor $muted
        Write-Host $p.Path -ForegroundColor $fg

        if ($p.Project) {
            Write-Host '├ ' -NoNewline -ForegroundColor $muted
            Write-Host $p.Project -ForegroundColor $fg
        }

        if ($p.Branch) {
            Write-Host '├ ' -NoNewline -ForegroundColor $muted
            Write-Host $p.Branch -ForegroundColor $fg
            $statusLabel = if ($p.Clean -eq $true) { 'Clean' } elseif ($p.Clean -eq $false) { 'Dirty' } else { $null }
            if ($statusLabel) {
                $statusColor = if ($p.Clean) { $accent } else { 'Yellow' }
                Write-Host '├ ' -NoNewline -ForegroundColor $muted
                Write-Host $statusLabel -ForegroundColor $statusColor
            }
            if ($p.Ago) {
                Write-Host '├ ' -NoNewline -ForegroundColor $muted
                Write-Host $p.Ago -ForegroundColor $muted
            }
        }

        foreach ($x in @($p.Extra)) {
            Write-Host '├ ' -NoNewline -ForegroundColor $muted
            Write-Host $x -ForegroundColor $muted
        }

        Write-Host '│' -ForegroundColor $muted
        Write-Host '╰▶ ' -NoNewline -ForegroundColor $accent
        return ' '
    }
    catch {
        return '> '
    }
}

function Register-DsPromptDefaults {
    # Segments kept for modules that Register-DsPromptSegment (git still registers; warp prompt reads git APIs directly).
    Register-DsPromptSegment -Name location -Order 10 -Force -Builder {
        $path = (Get-Location).Path
        $homePrefix = $HOME
        if ($path.StartsWith($homePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $rel = $path.Substring($homePrefix.Length).TrimStart('\', '/')
            if ([string]::IsNullOrEmpty($rel)) { return '~' }
            return "~\$rel"
        }
        $leaf = Split-Path -Leaf $path
        $parent = Split-Path -Leaf (Split-Path -Parent $path)
        if ($parent) { return "$parent\$leaf" }
        return $leaf
    }

    Register-DsPromptSegment -Name project -Order 20 -Force -Builder {
        try {
            $proj = (Get-DsContext).Project
            if ($proj) { return "[$proj]" }
        }
        catch { }
        return $null
    }
}

function Register-DsPromptOnLoad {
    Clear-DsPromptSegments
    Register-DsPromptDefaults
    Write-DsLog -Level Debug -Module prompt -Message 'prompt ready (warp)'
}

Export-ModuleMember -Function @(
    'Register-DsPromptSegment',
    'Get-DsPromptSegment',
    'Get-DsPromptText',
    'Get-DsPromptDisplayName',
    'Clear-DsPromptSegments',
    'Register-DsPromptOnLoad',
    'Register-DsPromptDefaults'
)
