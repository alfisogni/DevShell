#requires -Version 7.0
# aesthetic — temas, banner (arte + quick-ref truecolor) y tokens.

$script:DsTheme = $null
$script:DsWeatherCache = $null
$script:DsWeatherCacheAt = $null

function Get-DsThemePath {
    [CmdletBinding()]
    param([string]$Name)
    if (-not $Name) {
        $Name = Get-DsConfig -Path 'Theme'
        if (-not $Name) { $Name = 'default' }
    }
    Join-Path (Get-DsHome) "themes\$Name\theme.psd1"
}

function Get-DsThemeDirectory {
    [CmdletBinding()]
    param([string]$Name)
    Split-Path -Parent (Get-DsThemePath -Name $Name)
}

function Import-DsTheme {
    [CmdletBinding()]
    param([string]$Name)
    $path = Get-DsThemePath -Name $Name
    if (-not (Test-Path -LiteralPath $path)) {
        Write-DsLog -Level Warn -Module aesthetic -Message "Theme not found: $path"
        return $null
    }
    $theme = Import-PowerShellDataFile -LiteralPath $path
    $script:DsTheme = $theme
    try {
        $themeName = if ($theme.Name) { $theme.Name } else { $Name }
        Set-DsContext -Properties @{ Theme = $themeName }
    }
    catch { }
    Write-DsLog -Level Debug -Module aesthetic -Message "Theme loaded: $path"
    return $theme
}

function Get-DsTheme {
    [CmdletBinding()]
    param()
    if ($null -eq $script:DsTheme) { $null = Import-DsTheme }
    return $script:DsTheme
}

function Set-DsTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$NoBanner
    )
    $theme = Import-DsTheme -Name $Name
    if ($theme -and -not $NoBanner) { Show-DsBanner }
    return $theme
}

function ConvertTo-DsConsoleColor {
    [CmdletBinding()]
    param([string]$Hex, [string]$Role)
    switch ($Role) {
        'Accent'      { return 'Green' }
        'Interactive' { return 'Cyan' }
        'Knowledge'   { return 'Magenta' }
        'Muted'       { return 'DarkGray' }
        'Success'     { return 'Green' }
        'Warning'     { return 'Yellow' }
        'Error'       { return 'Red' }
        'Fg'          { return 'White' }
        'Bg'          { return 'Black' }
        default {
            if ($Hex -match '00C853|3FB950|a6e3a1|9ece6a') { return 'Green' }
            if ($Hex -match '89dceb|7dcfff') { return 'Cyan' }
            if ($Hex -match 'cba6f7|bb9af7') { return 'Magenta' }
            return 'White'
        }
    }
}

function Get-DsThemeColor {
    <#
    .SYNOPSIS
      Tokens de color del tema activo (módulo aesthetic).
    .DESCRIPTION
      Sin -Role: lista todos los roles con hex y color de consola.
      Con -Role: devuelve un solo token (para scripts / prompt / help).
    .PARAMETER Role
      Uno de: Bg, Fg, Accent, Interactive, Knowledge, Muted, Success, Warning, Error.
    .EXAMPLE
      Get-DsThemeColor
      Get-DsThemeColor -Role Accent
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('Bg', 'Fg', 'Accent', 'Interactive', 'Knowledge', 'Muted', 'Success', 'Warning', 'Error')]
        [string]$Role
    )

    $roles = @('Bg', 'Fg', 'Accent', 'Interactive', 'Knowledge', 'Muted', 'Success', 'Warning', 'Error')
    $theme = Get-DsTheme
    $themeName = if ($theme -and $theme.Name) { [string]$theme.Name } else { '(none)' }

    function New-DsThemeColorRow([string]$r) {
        $hex = $null
        if ($theme -and $theme.Colors -and $theme.Colors.ContainsKey($r)) {
            $hex = $theme.Colors[$r]
        }
        return [pscustomobject]@{
            Role         = $r
            Hex          = $hex
            ConsoleColor = ConvertTo-DsConsoleColor -Hex $hex -Role $r
        }
    }

    if (-not $Role) {
        Write-Host ''
        Write-Host 'DevShell theme colors' -ForegroundColor Cyan
        Write-Host ("  Theme: {0}" -f $themeName) -ForegroundColor DarkGray
        Write-Host '  Uso:   Get-DsThemeColor [-Role Accent|Interactive|Knowledge|Fg|Bg|Muted|Success|Warning|Error]' -ForegroundColor DarkGray
        Write-Host '  Tip:   Get-DsTheme | Show-DsBanner | Set-DsTheme <nombre>' -ForegroundColor DarkGray
        Write-Host ''
        $rows = foreach ($r in $roles) { New-DsThemeColorRow $r }
        foreach ($row in $rows) {
            $c = $row.ConsoleColor
            Write-Host ('  {0,-12} {1,-8} ' -f $row.Role, $row.Hex) -NoNewline
            Write-Host ('[{0}]' -f $row.ConsoleColor) -ForegroundColor $c
        }
        Write-Host ''
        return $rows
    }

    return (New-DsThemeColorRow $Role)
}

function Get-DsThemeSymbol {
    <#
    .SYNOPSIS
      Símbolos del tema (prompt, git, separadores).
    .DESCRIPTION
      Sin -Name: lista los símbolos definidos en el tema.
    .EXAMPLE
      Get-DsThemeSymbol
      Get-DsThemeSymbol -Name Prompt
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [string]$Default = ''
    )
    $theme = Get-DsTheme
    $themeName = if ($theme -and $theme.Name) { [string]$theme.Name } else { '(none)' }

    if (-not $Name) {
        Write-Host ''
        Write-Host 'DevShell theme symbols' -ForegroundColor Cyan
        Write-Host ("  Theme: {0}" -f $themeName) -ForegroundColor DarkGray
        Write-Host '  Uso:   Get-DsThemeSymbol [-Name Prompt|Git|Sep]' -ForegroundColor DarkGray
        Write-Host ''
        $syms = @()
        if ($theme -and $theme.Symbols) {
            foreach ($k in @($theme.Symbols.Keys)) {
                $val = [string]$theme.Symbols[$k]
                Write-Host ('  {0,-8} {1}' -f $k, $(if ($val) { $val } else { '(empty)' }))
                $syms += [pscustomobject]@{ Name = $k; Value = $val }
            }
        }
        if ($syms.Count -eq 0) {
            Write-Host '  (sin símbolos en el tema)' -ForegroundColor DarkGray
        }
        Write-Host ''
        return $syms
    }

    if ($theme -and $theme.Symbols -and $theme.Symbols.ContainsKey($Name)) {
        $val = $theme.Symbols[$Name]
        if ($null -ne $val -and "$val" -ne '') { return [string]$val }
    }
    return $Default
}

function ConvertFrom-DsHex {
    param([string]$Hex)
    $h = $Hex.TrimStart('#')
    if ($h.Length -ne 6) { return @(255, 255, 255) }
    return @(
        [Convert]::ToInt32($h.Substring(0, 2), 16)
        [Convert]::ToInt32($h.Substring(2, 2), 16)
        [Convert]::ToInt32($h.Substring(4, 2), 16)
    )
}

function Get-DsTrueColorFg {
    # Accepts (r,g,b) or a single 3-item array — avoids PS splat quirks.
    param($R, $G, $B)
    if ($null -eq $G -and $null -eq $B -and $R -is [System.Array]) {
        $arr = @($R)
        $R = [int]$arr[0]; $G = [int]$arr[1]; $B = [int]$arr[2]
    }
    else {
        $R = [int]$R; $G = [int]$G; $B = [int]$B
    }
    $e = [char]27
    return "$e[38;2;${R};${G};${B}m"
}

function Get-DsAnsiReset {
    return "$([char]27)[0m"
}

function Get-DsAnsiBold {
    return "$([char]27)[1m"
}

function Get-DsBannerArtLines {
    [CmdletBinding()]
    param()
    $theme = Get-DsTheme
    if (-not $theme -or -not $theme.Banner) { return @() }

    $artFile = $theme.Banner.ArtFile
    if ($artFile) {
        $path = if ([System.IO.Path]::IsPathRooted($artFile)) { $artFile }
        else { Join-Path (Get-DsThemeDirectory) $artFile }
        if (Test-Path -LiteralPath $path) {
            return @(Get-Content -LiteralPath $path -Encoding utf8)
        }
        Write-DsLog -Level Warn -Module aesthetic -Message "Banner art not found: $path"
    }
    if ($theme.Banner.Lines) { return @($theme.Banner.Lines) }
    return @()
}

function Get-DsIdentityPalette {
    # Theme-driven identity palette (default green or Lennerk Mocha / Tokyo Night).
    $theme = Get-DsTheme
    $accent = if ($theme.Colors.Accent) { $theme.Colors.Accent } else { '#00C853' }
    $fg     = if ($theme.Colors.Fg) { $theme.Colors.Fg } else { '#FFFFFF' }
    $muted  = if ($theme.Colors.Muted) { $theme.Colors.Muted } else { '#A0A0A0' }
    $bg     = if ($theme.Colors.Bg) { $theme.Colors.Bg } else { '#0A0A0A' }

    $a = ConvertFrom-DsHex $accent
    $f = ConvertFrom-DsHex $fg
    $m = ConvertFrom-DsHex $muted
    $b = ConvertFrom-DsHex $bg

    # Soft / dim derived from bg + muted for panel chrome
    $soft = @(
        [Math]::Min(255, [int](($a[0] + $f[0]) / 2)),
        [Math]::Min(255, [int](($a[1] + $f[1]) / 2)),
        [Math]::Min(255, [int](($a[2] + $f[2]) / 2))
    )
    $dim = @(
        [Math]::Min(255, $m[0] + 20),
        [Math]::Min(255, $m[1] + 20),
        [Math]::Min(255, $m[2] + 20)
    )
    $line = @(
        [Math]::Min(255, $b[0] + 40),
        [Math]::Min(255, $b[1] + 40),
        [Math]::Min(255, $b[2] + 48)
    )

    $deep = @(
        [Math]::Max(0, [int]($a[0] * 0.35)),
        [Math]::Max(0, [int]($a[1] * 0.45)),
        [Math]::Max(0, [int]($a[2] * 0.35))
    )
    $mint = @(
        [Math]::Min(255, $a[0] + 60),
        [Math]::Min(255, $a[1] + 40),
        [Math]::Min(255, $a[2] + 70)
    )
    $hi = @(
        [Math]::Min(255, $a[0] + 120),
        [Math]::Min(255, $a[1] + 80),
        [Math]::Min(255, $a[2] + 120)
    )

    return [pscustomobject]@{
        Accent = $a
        Fg     = $f
        Muted  = $m
        Soft   = $soft
        Dim    = $dim
        Line   = $line
        ArtStops = @($deep, $a, $mint, $hi)
    }
}

function Get-DsGradientAnsi {
    param(
        [double]$T,
        [object[]]$Stops
    )
    $segCount = $Stops.Count - 1
    if ($segCount -le 0) {
        $s = @($Stops[0])
        return Get-DsTrueColorFg $s[0] $s[1] $s[2]
    }
    $pos = $T * $segCount
    $i = [Math]::Min([int][Math]::Floor($pos), $segCount - 1)
    $frac = $pos - $i
    $a = @($Stops[$i])
    $b = @($Stops[$i + 1])
    $r = [int]([int]$a[0] + ([int]$b[0] - [int]$a[0]) * $frac)
    $g = [int]([int]$a[1] + ([int]$b[1] - [int]$a[1]) * $frac)
    $bl = [int]([int]$a[2] + ([int]$b[2] - [int]$a[2]) * $frac)
    return Get-DsTrueColorFg $r $g $bl
}

function Get-DsWeatherWidget {
    [CmdletBinding()]
    param()

    $enabled = $false
    $location = ''
    $timeoutSec = 2
    $cacheSec = 600

    try {
        $cfg = Get-DsConfig -Path 'Startup.Weather'
        if ($cfg -is [hashtable]) {
            if ($null -ne $cfg.Enabled) { $enabled = [bool]$cfg.Enabled }
            if ($cfg.Location) { $location = [string]$cfg.Location }
            if ($cfg.TimeoutSec) { $timeoutSec = [int]$cfg.TimeoutSec }
            if ($cfg.CacheSec) { $cacheSec = [int]$cfg.CacheSec }
        }
    }
    catch { }

    $theme = Get-DsTheme
    if ($theme -and $theme.Banner -and $theme.Banner.Weather -is [hashtable]) {
        $w = $theme.Banner.Weather
        if ($null -ne $w.Enabled) { $enabled = [bool]$w.Enabled }
        if ($w.Location) { $location = [string]$w.Location }
    }
    if (-not $enabled) { return @() }

    if ($script:DsWeatherCache -and $script:DsWeatherCacheAt) {
        if (((Get-Date) - $script:DsWeatherCacheAt).TotalSeconds -lt $cacheSec) {
            return @($script:DsWeatherCache)
        }
    }

    try {
        $locPath = if ([string]::IsNullOrWhiteSpace($location)) { '' } else { [uri]::EscapeDataString($location) }
        $uri = "https://wttr.in/${locPath}?format=%l%0A%c+%t%0A%w&m"
        $raw = Invoke-RestMethod -Uri $uri -TimeoutSec $timeoutSec -ErrorAction Stop
        $clean = [string]$raw
        $clean = $clean -replace '\x1b\[[0-9;]*[A-Za-z]', ''
        $clean = $clean -replace '[\u0000-\u0008\u000B\u000C\u000E-\u001F]', ''
        $lines = @($clean -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($lines.Count -eq 0) { return @() }
        $widget = @('weather', '') + $lines
        $script:DsWeatherCache = $widget
        $script:DsWeatherCacheAt = Get-Date
        return $widget
    }
    catch {
        Write-DsLog -Level Debug -Module aesthetic -Message "Weather widget skipped: $($_.Exception.Message)"
        return @()
    }
}

function Get-DsDashboardWidget {
    <#
    .SYNOPSIS
      Startup dashboard panels (Vision 2.0) — airy blocks, no emoji.
    #>
    [CmdletBinding()]
    param()

    $enabled = $true
    try {
        $cfg = Get-DsConfig -Path 'Startup.Dashboard'
        if ($cfg -is [hashtable] -and $null -ne $cfg.Enabled) { $enabled = [bool]$cfg.Enabled }
    }
    catch { }
    $theme = Get-DsTheme
    if ($theme -and $theme.Banner -and $theme.Banner.Dashboard -is [hashtable] -and $null -ne $theme.Banner.Dashboard.Enabled) {
        $enabled = [bool]$theme.Banner.Dashboard.Enabled
    }
    if (-not $enabled) { return @() }

    $rule = '────────────────────────'
    $out = [System.Collections.Generic.List[string]]::new()

    $themeName = if ($theme -and $theme.Name) { [string]$theme.Name } else { 'default' }
    $out.Add('DEVSHELL') | Out-Null
    $out.Add($rule) | Out-Null
    $out.Add(('  theme     {0}' -f $themeName)) | Out-Null
    $out.Add(('  time      {0}' -f (Get-Date -Format 'HH:mm'))) | Out-Null
    $out.Add('') | Out-Null

    $out.Add('WORKSPACE') | Out-Null
    $out.Add($rule) | Out-Null
    $loc = (Get-Location).Path
    $homePrefix = $HOME
    if ($loc.StartsWith($homePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $loc.Substring($homePrefix.Length).TrimStart('\', '/')
        $loc = if ([string]::IsNullOrEmpty($rel)) { '~' } else { "~\$rel" }
    }
    $out.Add(('  path      {0}' -f $loc)) | Out-Null
    $project = $null
    try { $project = (Get-DsContext).Project } catch { }
    $out.Add(('  project   {0}' -f $(if ($project) { $project } else { '—' }))) | Out-Null
    $out.Add('') | Out-Null

    $out.Add('GIT') | Out-Null
    $out.Add($rule) | Out-Null
    $branch = $null
    $gitRoot = $null
    if (Get-Command Get-DsGitBranch -ErrorAction SilentlyContinue) {
        try { $branch = Get-DsGitBranch } catch { }
    }
    if (Get-Command Get-DsGitRoot -ErrorAction SilentlyContinue) {
        try { $gitRoot = Get-DsGitRoot } catch { }
    }
    $out.Add(('  branch    {0}' -f $(if ($branch) { $branch } else { '—' }))) | Out-Null
    $out.Add(('  root      {0}' -f $(if ($gitRoot) { Split-Path -Leaf $gitRoot } else { '—' }))) | Out-Null
    $out.Add('') | Out-Null

    $out.Add('SYSTEM') | Out-Null
    $out.Add($rule) | Out-Null
    $ai = '—'
    try {
        $ctx = Get-DsContext
        if ($ctx.Ai -and $ctx.Ai.Provider) { $ai = [string]$ctx.Ai.Provider }
        elseif ($ctx.AIProvider) { $ai = [string]$ctx.AIProvider }
    }
    catch { }
    try {
        $cfgAi = Get-DsConfig -Path 'AI.Provider'
        if ($cfgAi) { $ai = [string]$cfgAi }
    }
    catch { }
    $out.Add(('  ai        {0}' -f $ai)) | Out-Null
    $ke = '—'
    if (Get-Command Get-DsKnowledgeStatus -ErrorAction SilentlyContinue) {
        try {
            $ks = Get-DsKnowledgeStatus
            if ($ks) { $ke = 'ready' }
        }
        catch { $ke = '—' }
    }
    elseif (Get-Command Search-DsKnowledge -ErrorAction SilentlyContinue) {
        $ke = 'ready'
    }
    $out.Add(('  knowledge {0}' -f $ke)) | Out-Null
    $out.Add('') | Out-Null

    $out.Add('QUICK') | Out-Null
    $out.Add($rule) | Out-Null
    $quick = @('dsp', 'dsg', 'dsa', 'dsf', 'dsh')
    if (Get-Command Get-DsAliasCatalog -ErrorAction SilentlyContinue) {
        $catalog = Get-DsAliasCatalog
        foreach ($name in $quick) {
            if (-not $catalog.Contains($name)) { continue }
            $desc = [string]$catalog[$name].Description
            if (-not $desc) { $desc = [string]$catalog[$name].Target }
            $out.Add(('  {0,-9} {1}' -f $name, $desc)) | Out-Null
        }
    }
    else {
        $out.Add('  dsp       project') | Out-Null
        $out.Add('  dsg       git status') | Out-Null
        $out.Add('  dsa       AI agent') | Out-Null
    }
    $out.Add('') | Out-Null
    $out.Add('Show-DsKeys · Get-DsHelp') | Out-Null
    return @($out)
}

function Get-DsMemoAliasRows {
    [CmdletBinding()]
    param()

    $nameW = 10
    $descW = 18
    $rows = [System.Collections.Generic.List[string]]::new()
    if (Get-Command Get-DsAliasCatalog -ErrorAction SilentlyContinue) {
        $catalog = Get-DsAliasCatalog
        foreach ($name in $catalog.Keys) {
            $desc = [string]$catalog[$name].Description
            if (-not $desc) { $desc = [string]$catalog[$name].Target }
            if ($desc.Length -gt $descW) { $desc = $desc.Substring(0, $descW - 1).TrimEnd() + '…' }
            $n = ([string]$name).PadRight($nameW)
            $d = $desc.PadRight($descW)
            $rows.Add("$n | $d") | Out-Null
        }
    }
    if ($rows.Count -eq 0) {
        foreach ($pair in @(
                @{ N = 'dsp'; D = 'project' }
                @{ N = 'dsg'; D = 'git status' }
                @{ N = 'dsa'; D = 'AI agent' }
                @{ N = 'dsf'; D = 'fuzzy cd' }
                @{ N = 'dsh'; D = 'help' }
                @{ N = 'dsd'; D = 'doctor' }
            )) {
            $rows.Add(("$($pair.N.PadRight($nameW)) | $($pair.D.PadRight($descW))")) | Out-Null
        }
    }
    return @($rows)
}

function Get-DsMemoKeyRows {
    [CmdletBinding()]
    param()

    $chordW = 10
    $descW = 16
    $keyRows = [System.Collections.Generic.List[string]]::new()
    if (Get-Command Get-DsKeyBinding -ErrorAction SilentlyContinue) {
        $prefer = @(
            'Ctrl+Shift+P', 'Ctrl+Shift+O', 'Ctrl+Shift+G', 'Ctrl+Shift+A',
            'Ctrl+Shift+S', 'Ctrl+Shift+K', 'Ctrl+Shift+J', 'Ctrl+Alt+K',
            'Ctrl+Alt+B', 'Ctrl+R'
        )
        $byChord = @{}
        foreach ($b in @(Get-DsKeyBinding)) {
            if ($b -and $b.Chord) { $byChord[[string]$b.Chord] = $b }
        }
        foreach ($chord in $prefer) {
            if (-not $byChord.ContainsKey($chord)) { continue }
            $b = $byChord[$chord]
            $short = $chord -replace 'Ctrl\+', '^' -replace 'Shift\+', 'S+' -replace 'Alt\+', 'A+'
            $desc = if ($b.Description) {
                ($b.Description -replace '\s*\(.*\)\s*$', '' -replace '^Invoke\s+', '' -replace '^Git\s+', 'git ' -replace '^Knowledge\s+', '')
            }
            else { $b.Module }
            $desc = $desc.ToLowerInvariant()
            if ($desc.Length -gt $descW) { $desc = $desc.Substring(0, $descW - 1).TrimEnd() + '…' }
            $keyRows.Add(("$($short.PadRight($chordW)) | $($desc.PadRight($descW))")) | Out-Null
        }
    }
    if ($keyRows.Count -eq 0) {
        foreach ($pair in @(
                @{ N = '^S+P'; D = 'palette' }
                @{ N = '^S+O'; D = 'project' }
                @{ N = '^S+G'; D = 'fuzzy cd' }
                @{ N = '^S+A'; D = 'AI' }
                @{ N = '^S+S'; D = 'git status' }
                @{ N = '^R'; D = 'history' }
            )) {
            $keyRows.Add(("$($pair.N.PadRight($chordW)) | $($pair.D.PadRight($descW))")) | Out-Null
        }
    }
    return @($keyRows)
}

function Join-DsMemoColumns {
    [CmdletBinding()]
    param(
        [string[]]$Left,
        [string[]]$Right,
        [int]$Gap = 4
    )

    $leftW = 0
    foreach ($l in $Left) {
        $w = Get-DsVisibleLength $l
        if ($w -gt $leftW) { $leftW = $w }
    }
    # Keep a stable gutter so KEYS always starts on the same column
    if ($leftW -lt 32) { $leftW = 32 }

    $rows = [Math]::Max($Left.Count, $Right.Count)
    $out = [System.Collections.Generic.List[string]]::new()
    $pad = ' ' * $Gap
    for ($i = 0; $i -lt $rows; $i++) {
        $l = if ($i -lt $Left.Count) { [string]$Left[$i] } else { '' }
        $r = if ($i -lt $Right.Count) { [string]$Right[$i] } else { '' }
        $need = $leftW - (Get-DsVisibleLength $l)
        if ($need -lt 0) { $need = 0 }
        $lPad = $l + (' ' * $need)
        if ($r) {
            $out.Add($lPad + $pad + $r) | Out-Null
        }
        else {
            $out.Add($lPad.TrimEnd()) | Out-Null
        }
    }
    return @($out)
}

function Get-DsMemoWidget {
    <#
    .SYNOPSIS
      QUICK REF (full catalog, left) + KEYS (right), fixed column alignment.
    #>
    [CmdletBinding()]
    param()

    $enabled = $true
    try {
        $cfg = Get-DsConfig -Path 'Startup.Memo'
        if ($cfg -is [hashtable] -and $null -ne $cfg.Enabled) { $enabled = [bool]$cfg.Enabled }
    }
    catch { }
    $theme = Get-DsTheme
    if ($theme -and $theme.Banner -and $theme.Banner.Memo -is [hashtable] -and $null -ne $theme.Banner.Memo.Enabled) {
        $enabled = [bool]$theme.Banner.Memo.Enabled
    }
    if (-not $enabled) { return @() }

    $aliasBody = @(Get-DsMemoAliasRows)
    $keyBody = @(Get-DsMemoKeyRows)

    # Measure body width first so header/rule match the column exactly
    $leftBodyW = 0
    foreach ($l in $aliasBody) {
        $w = Get-DsVisibleLength $l
        if ($w -gt $leftBodyW) { $leftBodyW = $w }
    }
    if ($leftBodyW -lt 32) { $leftBodyW = 32 }
    $rule = '─' * $leftBodyW

    $left = [System.Collections.Generic.List[string]]::new()
    $left.Add('QUICK REF') | Out-Null
    $left.Add($rule) | Out-Null
    foreach ($l in $aliasBody) { $left.Add($l) | Out-Null }

    $rightBodyW = 0
    foreach ($l in $keyBody) {
        $w = Get-DsVisibleLength $l
        if ($w -gt $rightBodyW) { $rightBodyW = $w }
    }
    if ($rightBodyW -lt 28) { $rightBodyW = 28 }
    $rightRule = '─' * $rightBodyW

    $right = [System.Collections.Generic.List[string]]::new()
    $right.Add('KEYS') | Out-Null
    $right.Add($rightRule) | Out-Null
    foreach ($l in $keyBody) { $right.Add($l) | Out-Null }

    $merged = @(Join-DsMemoColumns -Left @($left) -Right @($right) -Gap 4)
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($m in $merged) { $out.Add($m) | Out-Null }
    $out.Add('') | Out-Null
    $out.Add('Show-DsKeys → all bindings') | Out-Null
    return @($out)
}

function Get-DsVisibleLength {
    [CmdletBinding()]
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $plain = [regex]::Replace($Text, '\x1b\[[0-9;]*m', '')
    return $plain.Length
}

function Resolve-DsBannerLayout {
    [CmdletBinding()]
    param(
        [int]$ArtWidth,
        [int]$MemoWidth,
        [int]$Gap = 4,
        [int]$WindowWidth,
        [ValidateSet('Auto', 'Side', 'Stack')]
        [string]$ForceLayout = 'Auto'
    )

    if ($ForceLayout -eq 'Side') { return 'Side' }
    if ($ForceLayout -eq 'Stack') { return 'Stack' }
    if ($MemoWidth -le 0) { return 'Side' }

    $needed = $ArtWidth + $Gap + $MemoWidth
    $minSide = 100
    if ($WindowWidth -ge [Math]::Max($needed, $minSide)) {
        return 'Side'
    }
    return 'Stack'
}

function Get-DsMemoWidgetAnsi {
    <#
    .SYNOPSIS
      Side panel card con truecolor (memo o dashboard).
    #>
    [CmdletBinding()]
    param(
        [string[]]$Plain
    )

    if (-not $Plain) { $Plain = @(Get-DsMemoWidget) }
    if ($Plain.Count -eq 0) { return @() }

    $p = Get-DsIdentityPalette
    $reset = Get-DsAnsiReset
    $bold = Get-DsAnsiBold
    $accent = Get-DsTrueColorFg $p.Accent
    $fg = Get-DsTrueColorFg $p.Fg
    $muted = Get-DsTrueColorFg $p.Muted
    $dim = Get-DsTrueColorFg $p.Dim
    $line = Get-DsTrueColorFg $p.Line

    $sectionHeads = @('QUICK REF', 'KEYS', 'DEVSHELL', 'WORKSPACE', 'GIT', 'SYSTEM', 'QUICK')

    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($row in $Plain) {
        if ($sectionHeads -contains $row) {
            $out.Add("$bold$accent$row$reset") | Out-Null
        }
        elseif ($row -match 'QUICK REF' -and $row -match 'KEYS') {
            # Two-column headers on one line
            $colored = [regex]::Replace($row, '(QUICK REF|KEYS)', { param($m) "$bold$accent$($m.Value)$reset" })
            $out.Add($colored) | Out-Null
        }
        elseif ($row -match '^─+' -or ($row -match '─{4,}' -and $row -notmatch '\|')) {
            $colored = [regex]::Replace($row, '─+', { param($m) "$line$($m.Value)$reset" })
            $out.Add($colored) | Out-Null
        }
        elseif ($row -match '^Show-DsKeys' -or $row -match '^Get-DsAlias') {
            $out.Add("$dim$row$reset") | Out-Null
        }
        elseif ($row -match '\|') {
            # Color each "cmd | desc" pair (supports two columns)
            $colored = [regex]::Replace(
                $row,
                '(\S+)\s+\|\s+(\S+(?:\s+\S+)*?)(?=\s{2,}|\s+\S+\s+\||$)',
                {
                    param($m)
                    $cmd = $m.Groups[1].Value
                    $desc = $m.Groups[2].Value.TrimEnd()
                    "$accent$cmd$reset $dim|$reset $fg$desc$reset"
                }
            )
            $out.Add($colored) | Out-Null
        }
        elseif ($row -match '^\s{2}(\S+)\s{2,}(.+)$') {
            $label = $Matches[1].PadRight(9)
            $val = $Matches[2]
            $out.Add("  $dim$label$reset $fg$val$reset") | Out-Null
        }
        elseif ($row -eq '') {
            $out.Add('') | Out-Null
        }
        else {
            $out.Add("$fg$row$reset") | Out-Null
        }
    }
    return @($out)
}

function Get-DsBannerSidePanel {
    [CmdletBinding()]
    param()

    $panel = 'memo'
    try {
        $configured = Get-DsConfig -Path 'Startup.SidePanel'
        if ($configured) { $panel = [string]$configured }
    }
    catch { }
    $theme = Get-DsTheme
    if ($theme -and $theme.Banner -and $theme.Banner.SidePanel) {
        $panel = [string]$theme.Banner.SidePanel
    }

    switch ($panel.ToLowerInvariant()) {
        'weather' {
            return @{ Kind = 'plain'; Lines = @(Get-DsWeatherWidget) }
        }
        'dashboard' {
            return @{ Kind = 'ansi'; Lines = @(Get-DsMemoWidgetAnsi -Plain @(Get-DsDashboardWidget)) }
        }
        'none' {
            return @{ Kind = 'plain'; Lines = @() }
        }
        default {
            return @{ Kind = 'ansi'; Lines = @(Get-DsMemoWidgetAnsi) }
        }
    }
}

function Show-DsBannerArt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Art,

        [int]$ArtWidth
    )

    if ($ArtWidth -le 0) {
        $ArtWidth = ($Art | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        if (-not $ArtWidth) { $ArtWidth = 0 }
    }

    $palette = Get-DsIdentityPalette
    $reset = Get-DsAnsiReset
    foreach ($i in 0..($Art.Count - 1)) {
        $left = $Art[$i]
        if ([string]::IsNullOrEmpty($left)) {
            Write-Host ''
            continue
        }
        $t = if ($Art.Count -le 1) { 0.0 } else { $i / ($Art.Count - 1) }
        $grad = Get-DsGradientAnsi -T $t -Stops $palette.ArtStops
        Write-Host ($grad + $left + $reset)
    }
}

function Show-DsBannerMemo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [switch]$Ansi
    )

    if ($null -eq $Lines -or $Lines.Count -eq 0) { return }
    if ($Ansi) {
        foreach ($sLine in $Lines) { Write-Host $sLine }
        return
    }

    $muted = (Get-DsThemeColor -Role Muted).ConsoleColor
    $accent = (Get-DsThemeColor -Role Accent).ConsoleColor
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $color = if ($i -eq 0) { $accent } else { $muted }
        Write-Host $Lines[$i] -ForegroundColor $color
    }
}

function Show-DsBanner {
    [CmdletBinding()]
    param(
        [ValidateSet('Auto', 'Side', 'Stack')]
        [string]$ForceLayout = 'Auto'
    )
    $theme = Get-DsTheme
    if (-not $theme -or -not $theme.Banner -or -not $theme.Banner.Enabled) { return }

    $art = @(Get-DsBannerArtLines)
    if ($art.Count -eq 0) { return }

    $sideInfo = Get-DsBannerSidePanel
    $side = @($sideInfo.Lines)
    $sideIsAnsi = ($sideInfo.Kind -eq 'ansi')
    $gap = '    '
    $artWidth = ($art | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    if (-not $artWidth) { $artWidth = 0 }

    $memoWidth = 0
    if ($side.Count -gt 0) {
        $memoWidth = ($side | ForEach-Object { Get-DsVisibleLength $_ } | Measure-Object -Maximum).Maximum
        if (-not $memoWidth) { $memoWidth = 0 }
    }

    $windowWidth = 120
    try {
        $windowWidth = [int]$Host.UI.RawUI.WindowSize.Width
    }
    catch { }

    $layout = Resolve-DsBannerLayout -ArtWidth $artWidth -MemoWidth $memoWidth -Gap $gap.Length -WindowWidth $windowWidth -ForceLayout $ForceLayout

    try {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        $OutputEncoding = [System.Text.UTF8Encoding]::new()
    }
    catch { }

    Write-Host ''

    if ($layout -eq 'Stack' -or $side.Count -eq 0) {
        Show-DsBannerArt -Art $art -ArtWidth $artWidth
        if ($side.Count -gt 0) {
            Write-Host ''
            Show-DsBannerMemo -Lines $side -Ansi:$sideIsAnsi
        }
        Write-Host ''
        return
    }

    $palette = Get-DsIdentityPalette
    $reset = Get-DsAnsiReset
    $sideOffset = 0
    if ($side.Count -gt 0 -and $art.Count -gt $side.Count) {
        $sideOffset = [math]::Floor(($art.Count - $side.Count) / 2)
    }
    $rows = [Math]::Max($art.Count, $sideOffset + $side.Count)

    for ($i = 0; $i -lt $rows; $i++) {
        $left = if ($i -lt $art.Count) { $art[$i] } else { '' }
        $pad = [Math]::Max(0, $artWidth - $left.Length)
        $leftPadded = $left + (' ' * $pad)

        if ($i -lt $art.Count -and $left.Length -gt 0) {
            $t = if ($art.Count -le 1) { 0.0 } else { $i / ($art.Count - 1) }
            $grad = Get-DsGradientAnsi -T $t -Stops $palette.ArtStops
            Write-Host ($grad + $leftPadded + $reset) -NoNewline
        }
        else {
            Write-Host $leftPadded -NoNewline
        }

        $sIndex = $i - $sideOffset
        if ($side.Count -gt 0 -and $sIndex -ge 0 -and $sIndex -lt $side.Count) {
            Write-Host $gap -NoNewline
            $sLine = $side[$sIndex]
            if ($sideIsAnsi) {
                Write-Host $sLine
            }
            else {
                $muted = (Get-DsThemeColor -Role Muted).ConsoleColor
                $accent = (Get-DsThemeColor -Role Accent).ConsoleColor
                $color = if ($sIndex -eq 0) { $accent } else { $muted }
                Write-Host $sLine -ForegroundColor $color
            }
        }
        else {
            Write-Host ''
        }
    }
    Write-Host ''
}

function Register-DsAestheticOnLoad {
    $null = Import-DsTheme
}

Export-ModuleMember -Function @(
    'Get-DsTheme',
    'Set-DsTheme',
    'Import-DsTheme',
    'Get-DsThemePath',
    'Get-DsThemeColor',
    'Get-DsThemeSymbol',
    'Get-DsBannerArtLines',
    'Get-DsMemoWidget',
    'Get-DsMemoWidgetAnsi',
    'Get-DsDashboardWidget',
    'Get-DsWeatherWidget',
    'Get-DsBannerSidePanel',
    'Get-DsVisibleLength',
    'Resolve-DsBannerLayout',
    'Show-DsBannerArt',
    'Show-DsBannerMemo',
    'Show-DsBanner',
    'ConvertTo-DsConsoleColor',
    'Register-DsAestheticOnLoad'
)
