#requires -Version 7.0
# DevShell root — bootstrap + Start-DevShell

$script:DsHome = Split-Path -Parent $PSCommandPath
$script:DsStarted = $false

function Get-DsHome {
    [CmdletBinding()]
    param()
    $script:DsHome
}

function Get-DsHelp {
    [CmdletBinding()]
    param()

    $accent = 'Green'
    if (Get-Command Get-DsThemeColor -ErrorAction SilentlyContinue) {
        $accent = (Get-DsThemeColor -Role Accent).ConsoleColor
    }

    Write-Host ''
    Write-Host 'DevShell' -ForegroundColor $accent
    Write-Host ''
    Write-Host '  Get-DsHelp / dsh           ayuda' -ForegroundColor White
    Write-Host '  Invoke-DsProject / dsp     proyectos (ProjectRoots)' -ForegroundColor White
    Write-Host "  dsa 'explica este repo'    AI one-shot (agent -p)" -ForegroundColor White
    Write-Host '  dsa -Chat                  AI sesión Agent interactiva' -ForegroundColor White
    Write-Host '  Invoke-DsIde               abre Cursor/VS Code GUI' -ForegroundColor White
    Write-Host '  Invoke-DsGitStatus / dsg   git' -ForegroundColor White
    Write-Host '  Show-DsKeys                atajos' -ForegroundColor White
    Write-Host '  Invoke-DsDoctor / dsd      diagnóstico' -ForegroundColor White
    Write-Host '  Get-DsAlias                estado de aliases' -ForegroundColor White
    Write-Host ''
    Write-Host '  Knowledge Engine' -ForegroundColor $accent
    Write-Host '  dev help                   subcomandos KE' -ForegroundColor White
    Write-Host '  dev report today / dsreport journal del día' -ForegroundColor White
    Write-Host '  dev note / dsknote         nota de conocimiento' -ForegroundColor White
    Write-Host '  Ctrl+Alt+K                 report today (chord)' -ForegroundColor White
    Write-Host '  Get-DsKnowledgeProvider    providers detectados' -ForegroundColor White
    Write-Host ''
}

function Show-DsStatus {
    [CmdletBinding()]
    param()

    if (-not $script:DsStarted) {
        Write-Host 'DevShell no iniciado. Corré Start-DevShell o .\init.ps1' -ForegroundColor Yellow
        return
    }

    $ctx = Get-DsContext
    $accent = 'Green'
    $muted = 'DarkGray'
    if (Get-Command Get-DsThemeColor -ErrorAction SilentlyContinue) {
        $accent = (Get-DsThemeColor -Role Accent).ConsoleColor
        $muted = (Get-DsThemeColor -Role Muted).ConsoleColor
    }

    Write-Host ''
    Write-Host 'DevShell' -ForegroundColor $accent -NoNewline
    Write-Host "  $($ctx.Location)" -ForegroundColor $muted
    if ($ctx.Project) {
        Write-Host "         $($ctx.Project)" -ForegroundColor $muted
    }
    Write-Host ''
}

function Start-DevShell {
    [CmdletBinding()]
    param(
        [switch]$Quiet,
        [switch]$SkipBanner
    )

    $homePath = Get-DsHome

    $coreManifest = Join-Path $homePath 'core\Core.psd1'
    Import-Module $coreManifest -Force -Global

    Clear-DsEvents
    Clear-DsKeyBindings

    $null = Initialize-DsConfig -HomePath $homePath
    $theme = Get-DsConfig -Path 'Theme'
    if (-not $theme) { $theme = 'default' }

    Initialize-DsContext -HomePath $homePath -Theme $theme

    $result = Start-DsModuleLoader -HomePath $homePath
    $script:DsStarted = $true

    $showBanner = $true
    $showStatus = $false
    try {
        $sb = Get-DsConfig -Path 'Startup.ShowBanner'
        if ($null -ne $sb) { $showBanner = [bool]$sb }
        $ss = Get-DsConfig -Path 'Startup.ShowStatus'
        if ($null -ne $ss) { $showStatus = [bool]$ss }
    }
    catch { }

    if ($Quiet) {
        $showBanner = $false
        $showStatus = $false
    }
    if ($SkipBanner) { $showBanner = $false }

    if ($showBanner) { Show-DsStartupBanner }
    if ($showStatus) { Show-DsStatus }

    Write-DsLog -Level Debug -Module core -Message "Ready ($($result.Loaded.Count) modules)"
    return $result
}

function Show-DsStartupBanner {
    [CmdletBinding()]
    param()

    if (Get-Command Show-DsBanner -ErrorAction SilentlyContinue) {
        Show-DsBanner
        return
    }

    Write-Host ''
    Write-Host 'DevShell' -ForegroundColor Green
    Write-Host ''
}

Export-ModuleMember -Function @(
    'Get-DsHome',
    'Get-DsHelp',
    'Show-DsStatus',
    'Start-DevShell',
    'Show-DsStartupBanner'
)
