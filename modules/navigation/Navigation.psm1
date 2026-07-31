#requires -Version 7.0
# navigation — cd rápido, stack y bookmarks.

$script:DsLocationStack = [System.Collections.Generic.Stack[string]]::new()
$script:DsBookmarks = @{}

function Initialize-DsNavigationConfig {
    [CmdletBinding()]
    param()
    $script:DsBookmarks = @{}
    $cfgPath = Join-Path (Get-DsHome) 'modules\navigation\config.psd1'
    if (Test-Path -LiteralPath $cfgPath) {
        $cfg = Import-PowerShellDataFile -LiteralPath $cfgPath
        if ($cfg.Bookmarks -is [hashtable]) {
            $script:DsBookmarks = $cfg.Bookmarks.Clone()
        }
    }
    # user overrides
    try {
        $userBookmarks = Get-DsConfig -Path 'Navigation.Bookmarks'
        if ($userBookmarks -is [hashtable]) {
            foreach ($k in $userBookmarks.Keys) {
                $script:DsBookmarks[$k] = $userBookmarks[$k]
            }
        }
    }
    catch { }
}

function Expand-DsPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if ($Path.StartsWith('~/') -or $Path -eq '~' -or $Path.StartsWith('~\')) {
        $Path = Join-Path $HOME ($Path.Substring(1).TrimStart('\', '/'))
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Set-DsLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $target = Expand-DsPath -Path $Path
    if (-not (Test-Path -LiteralPath $target)) {
        Write-DsLog -Level Warn -Module navigation -Message "Path not found: $target"
        return
    }

    $current = (Get-Location).Path
    if ($current -ne $target) {
        $script:DsLocationStack.Push($current)
    }
    Set-Location -LiteralPath $target
    try {
        Update-DsContextLocation
    }
    catch { }
}

function Push-DsLocation {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path
    )
    if ($Path) {
        Set-DsLocation -Path $Path
    }
    else {
        $script:DsLocationStack.Push((Get-Location).Path)
    }
}

function Pop-DsLocation {
    [CmdletBinding()]
    param()
    if ($script:DsLocationStack.Count -eq 0) {
        Write-DsLog -Level Warn -Module navigation -Message 'Location stack empty'
        return
    }
    $prev = $script:DsLocationStack.Pop()
    Set-Location -LiteralPath $prev
    try { Update-DsContextLocation } catch { }
    Write-Host $prev -ForegroundColor DarkGray
}

function Get-DsLocationStack {
    [CmdletBinding()]
    param()
    @($script:DsLocationStack)
}

function Get-DsBookmark {
    [CmdletBinding()]
    param([string]$Name)
    if ($Name) {
        return $script:DsBookmarks[$Name]
    }
    return $script:DsBookmarks.GetEnumerator() | ForEach-Object {
        [pscustomobject]@{ Name = $_.Key; Path = $_.Value }
    }
}

function Set-DsBookmark {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Path = (Get-Location).Path
    )
    $script:DsBookmarks[$Name] = (Expand-DsPath -Path $Path)
}

function Remove-DsBookmark {
    <#
    .SYNOPSIS
      Elimina uno o más bookmarks de la sesión.
    .EXAMPLE
      Remove-DsBookmark foo
      Remove-DsBookmark foo, bar
      Remove-DsBookmark -All
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Name')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Name', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string[]]$Bookmark,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All
    )

    begin {
        Initialize-DsNavigationConfig
    }

    process {
        if ($All) {
            $names = @($script:DsBookmarks.Keys)
            if ($names.Count -eq 0) {
                Write-Host 'No bookmarks to remove.' -ForegroundColor DarkGray
                return
            }
            if ($PSCmdlet.ShouldProcess(('all ({0})' -f ($names -join ', ')), 'Remove bookmarks')) {
                $script:DsBookmarks.Clear()
                Write-Host ("Removed {0} bookmark(s)." -f $names.Count) -ForegroundColor DarkGray
            }
            return
        }

        foreach ($name in @($Bookmark)) {
            if (-not $script:DsBookmarks.ContainsKey($name)) {
                Write-Host ("Bookmark '{0}' not found." -f $name) -ForegroundColor Yellow
                continue
            }
            if ($PSCmdlet.ShouldProcess($name, 'Remove bookmark')) {
                $script:DsBookmarks.Remove($name) | Out-Null
                Write-Host ("Removed bookmark '{0}'." -f $name) -ForegroundColor DarkGray
            }
        }
    }
}

function Invoke-DsGoto {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name
    )
    if ($Name -and $script:DsBookmarks.ContainsKey($Name)) {
        Set-DsLocation -Path $script:DsBookmarks[$Name]
        return
    }

    $entries = @(
        $script:DsBookmarks.GetEnumerator() | ForEach-Object { "$($_.Key)`t$($_.Value)" }
    )
    if ($entries.Count -eq 0) {
        Write-Host 'No bookmarks. Set-DsBookmark -Name home' -ForegroundColor Yellow
        return
    }
    $pick = Invoke-DsFuzzy -Items $entries -Prompt 'bookmark'
    if (-not $pick) { return }
    $path = ($pick -split "`t", 2)[1]
    if ($path) { Set-DsLocation -Path $path }
}

function Invoke-DsFuzzyCd {
    [CmdletBinding()]
    param(
        [string]$Path = '.',
        [int]$Depth = 2
    )

    $root = Expand-DsPath -Path $Path
    if (-not (Test-Path -LiteralPath $root)) {
        Write-DsLog -Level Warn -Module navigation -Message "Path not found: $root"
        return
    }

    $dirs = Get-ChildItem -LiteralPath $root -Directory -Recurse -Depth $Depth -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName

    $dirs = @($root) + @($dirs)
    $pick = Invoke-DsFuzzy -Items $dirs -Prompt 'cd'
    if ($pick) { Set-DsLocation -Path $pick }
}

function Register-DsNavigationOnLoad {
    Initialize-DsNavigationConfig
    Write-DsLog -Level Debug -Module navigation -Message 'navigation ready'
}

function Register-DsNavigationKeys {
    $null = Register-DsKey -Chord 'Ctrl+Shift+G' -Module navigation -Description 'Fuzzy cd (Invoke-DsFuzzyCd)' -Action {
        Invoke-DsFuzzyCd
    }
    $null = Register-DsKey -Chord 'Ctrl+Shift+B' -Module navigation -Description 'Goto bookmark (Invoke-DsGoto)' -Action {
        Invoke-DsGoto
    }
}

Export-ModuleMember -Function @(
    'Set-DsLocation',
    'Push-DsLocation',
    'Pop-DsLocation',
    'Get-DsLocationStack',
    'Get-DsBookmark',
    'Set-DsBookmark',
    'Remove-DsBookmark',
    'Invoke-DsGoto',
    'Invoke-DsFuzzyCd',
    'Expand-DsPath',
    'Register-DsNavigationOnLoad',
    'Register-DsNavigationKeys'
)
