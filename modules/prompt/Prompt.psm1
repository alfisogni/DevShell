#requires -Version 7.0
# prompt — prompt extensible por segmentos; consume aesthetic si existe.

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

function Get-DsPromptText {
    [CmdletBinding()]
    param()

    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($seg in (Get-DsPromptSegment)) {
        try {
            $text = & $seg.Builder
            if ($text) { $parts.Add([string]$text) | Out-Null }
        }
        catch {
            Write-DsLog -Level Debug -Module prompt -Message "Segment $($seg.Name) failed: $($_.Exception.Message)"
        }
    }

    $sep = '>'
    if (Get-Command Get-DsThemeSymbol -ErrorAction SilentlyContinue) {
        $sep = Get-DsThemeSymbol -Name Prompt -Default '>'
    }

    if ($parts.Count -eq 0) {
        return "PS $sep "
    }

    return @{
        Body = ($parts -join ' ')
        Sep  = $sep
    }
}

function global:prompt {
    try {
        if (Get-Command Update-DsContextLocation -ErrorAction SilentlyContinue) {
            Update-DsContextLocation
        }
        if (Get-Command Get-DsPromptText -ErrorAction SilentlyContinue) {
            $p = Get-DsPromptText
            $muted = 'DarkGray'
            $accent = 'Green'
            if (Get-Command Get-DsThemeColor -ErrorAction SilentlyContinue) {
                $muted = (Get-DsThemeColor -Role Muted).ConsoleColor
                $accent = (Get-DsThemeColor -Role Accent).ConsoleColor
            }
            if ($p -is [hashtable]) {
                Write-Host $p.Body -NoNewline -ForegroundColor $muted
                Write-Host " $($p.Sep) " -NoNewline -ForegroundColor $accent
                return ' '
            }
            return [string]$p
        }
    }
    catch { }
    return "> "
}

function Register-DsPromptDefaults {
    Register-DsPromptSegment -Name location -Order 10 -Force -Builder {
        $path = (Get-Location).Path
        $homePrefix = $HOME
        if ($path.StartsWith($homePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $rel = $path.Substring($homePrefix.Length).TrimStart('\', '/')
            if ([string]::IsNullOrEmpty($rel)) { return '~' }
            return "~\$rel"
        }
        # short leaf + parent
        $leaf = Split-Path -Leaf $path
        $parent = Split-Path -Leaf (Split-Path -Parent $path)
        if ($parent) { return "$parent\$leaf" }
        return $leaf
    }

    Register-DsPromptSegment -Name project -Order 20 -Force -Builder {
        try {
            $p = (Get-DsContext).Project
            if ($p) { return "[$p]" }
        }
        catch { }
        return $null
    }
}

function Register-DsPromptOnLoad {
    Clear-DsPromptSegments
    Register-DsPromptDefaults
    Write-DsLog -Level Debug -Module prompt -Message 'prompt ready'
}

Export-ModuleMember -Function @(
    'Register-DsPromptSegment',
    'Get-DsPromptSegment',
    'Get-DsPromptText',
    'Clear-DsPromptSegments',
    'Register-DsPromptOnLoad',
    'Register-DsPromptDefaults'
)
